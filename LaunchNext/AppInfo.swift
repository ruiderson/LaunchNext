import Foundation
import AppKit
import CoreServices

struct AppInfo: Identifiable, Equatable, Hashable {
    let name: String
    let icon: NSImage
    let url: URL

    // 使用应用路径作为稳定唯一标识
    var id: String { url.path }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url.path)
    }

    // MARK: - 创建 AppInfo
    static func from(url: URL, preferredName: String? = nil) -> AppInfo {
        let name = localizedAppName(for: url, preferredName: preferredName)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return AppInfo(name: name, icon: icon, url: url)
    }

    // MARK: - 获取本地化应用名
    private static func localizedAppName(for url: URL, preferredName: String?) -> String {
        let fallbackName = normalizeCandidate(url.deletingPathExtension().lastPathComponent)
        var resolvedName: String? = nil

        func consider(_ rawValue: String?, source: String) {
            guard let rawValue = rawValue else {
                return
            }
            let normalized = normalizeCandidate(rawValue)
            if normalized.isEmpty {
                return
            }
            guard resolvedName == nil else { return }
            if normalized != fallbackName {
                resolvedName = normalized
            }
        }

        consider(preferredName, source: "preferredName")

        if let metadataItem = NSMetadataItem(url: url) {
            if let displayName = metadataItem.value(forAttribute: kMDItemDisplayName as String) as? String {
                consider(displayName, source: "MDItemDisplayName")
            }

            let alternateNamesKey = "kMDItemAlternateNames"
            if let alternatesValue = metadataItem.value(forAttribute: alternateNamesKey) {
                if let names = alternatesValue as? [String] {
                    for name in names { consider(name, source: "MDItemAlternateNames") }
                } else if let names = alternatesValue as? NSArray {
                    for case let name as String in names { consider(name, source: "MDItemAlternateNames") }
                }
            }
        }

        if let bundle = Bundle(url: url) {
            consider(localizedInfoValue(for: "CFBundleDisplayName", in: bundle), source: "InfoPlist.strings CFBundleDisplayName")
            consider(localizedInfoValue(for: "CFBundleName", in: bundle), source: "InfoPlist.strings CFBundleName")
            consider(bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, source: "Info.plist CFBundleDisplayName")
            consider(bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, source: "Info.plist CFBundleName")
        }

        let resourceValues = try? url.resourceValues(forKeys: [.localizedNameKey])
        consider(resourceValues?.localizedName, source: "resourceValues.localizedName")

        if let components = FileManager.default.componentsToDisplay(forPath: url.path) {
            consider(components.last, source: "FileManager.componentsToDisplay.last")
        }

        var unmanagedName: Unmanaged<CFString>?
        let lsStatus = LSCopyDisplayNameForURL(url as CFURL, &unmanagedName)
        if lsStatus == noErr, let cfName = unmanagedName?.takeRetainedValue() as String? {
            consider(cfName, source: "LSCopyDisplayNameForURL")
        }

        consider(FileManager.default.displayName(atPath: url.path), source: "FileManager.displayName")
        
        switch fallbackName {
        case "Safari":
            return fallbackName
        case "Outlook":
            return fallbackName
        default:
            break
        }

        return resolvedName ?? fallbackName
    }

    private static func normalizeCandidate(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasSuffix(".app") {
            trimmed = String(trimmed.dropLast(4))
        }
        return trimmed
    }

    private static func localizedInfoValue(for key: String, in bundle: Bundle) -> String? {
        let preferred = Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: Locale.preferredLanguages)
        let development = bundle.developmentLocalization.map { [$0] } ?? []
        let candidates = preferred + development + bundle.localizations

        for locale in candidates {
            if let path = bundle.path(forResource: "InfoPlist", ofType: "strings", inDirectory: nil, forLocalization: locale),
               let dict = NSDictionary(contentsOfFile: path),
               let value = dict[key] as? String,
               !value.isEmpty {
                return value
            }
        }

        if let localizedInfo = bundle.localizedInfoDictionary,
           let value = localizedInfo[key] as? String,
           !value.isEmpty {
            return value
        }
        return nil
    }
}
