import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SwiftData
import MachO
import Darwin

struct SettingsView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject private var controllerManager = ControllerInputManager.shared
    @State private var showResetConfirm = false
    @State private var selectedSection: SettingsSection = .general
    @State private var titleSearch: String = ""
    @State private var hiddenSearch: String = ""
    @State private var editingDrafts: [String: String] = [:]
    @State private var editingEntries: Set<String> = []
    @State private var iconImportError: String? = nil
    @State private var showAppSourcesResetDialog = false
    @State private var isCapturingShortcut = false
    @State private var shortcutCaptureMonitor: Any?
    @State private var pendingShortcut: AppStore.HotKeyConfiguration?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationSplitView {
                List(selection: $selectedSection) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appStore.localized(.appTitle))
                            .font(.headline.weight(.semibold))
                        Text("\(appStore.localized(.versionPrefix))\(getVersion())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 10))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    ForEach(SettingsSection.allCases) { section in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(section.iconGradient)
                                .overlay(
                                    Image(systemName: section.iconName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                )
                                .frame(width: 24, height: 24)
                                .liquidGlass()

                            Text(appStore.localized(section.localizationKey))
                                .font(.callout.weight(.medium))
                        }
                        .padding(.vertical, 2)
                        .tag(section)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(.ultraThinMaterial)
                .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 250)
            } detail: {
                detailView(for: selectedSection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)

            Button {
                appStore.isSetting = false
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .liquidGlass()
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .frame(minWidth: 820, minHeight: 640)
        .alert(appStore.localized(.customIconTitle), isPresented: Binding(get: { iconImportError != nil }, set: { if !$0 { iconImportError = nil } })) {
            Button(appStore.localized(.okButton), role: .cancel) { iconImportError = nil }
        } message: {
            Text(iconImportError ?? "")
        }
        .onDisappear {
            stopShortcutCapture(cancel: false)
        }
    }

private func getVersion() -> String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case performance
    case titles
    case appSources
    case hiddenApps
    case development
    case sound
    case gameController
    case updates
    case about

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .appSources: return "externaldrive"
        case .gameController: return "gamecontroller"
        case .sound: return "speaker.wave.2"
        case .appearance: return "paintbrush"
        case .performance: return "speedometer"
        case .titles: return "text.badge.plus"
        case .hiddenApps: return "eye.slash"
        case .development: return "hammer"
        case .updates: return "arrow.down.circle"
        case .about: return "info.circle"
        }
    }

    var iconGradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .general:
            colors = [Color(red: 0.12, green: 0.52, blue: 0.96), Color(red: 0.22, green: 0.72, blue: 0.94)]
        case .appSources:
            colors = [Color(nsColor: .systemGray), Color(nsColor: .lightGray)]
        case .sound:
            colors = [Color(red: 0.96, green: 0.48, blue: 0.24), Color(red: 0.98, green: 0.68, blue: 0.30)]
        case .gameController:
            colors = [Color(red: 0.46, green: 0.34, blue: 0.97), Color(red: 0.31, green: 0.54, blue: 0.99)]
        case .appearance:
            colors = [Color(red: 0.73, green: 0.25, blue: 0.96), Color(red: 0.98, green: 0.43, blue: 0.80)]
        case .performance:
            colors = [Color(red: 0.02, green: 0.70, blue: 0.46), Color(red: 0.31, green: 0.93, blue: 0.69)]
        case .titles:
            colors = [Color(red: 0.95, green: 0.37, blue: 0.32), Color(red: 0.98, green: 0.55, blue: 0.44)]
        case .hiddenApps:
            colors = [Color(red: 0.29, green: 0.39, blue: 0.96), Color(red: 0.11, green: 0.67, blue: 0.91)]
        case .development:
            colors = [Color(red: 0.98, green: 0.58, blue: 0.16), Color(red: 0.96, green: 0.20, blue: 0.24)]
        case .updates:
            colors = [Color(red: 0.22, green: 0.78, blue: 0.55), Color(red: 0.10, green: 0.62, blue: 0.91)]
        case .about:
            colors = [Color(red: 0.54, green: 0.55, blue: 0.70), Color(red: 0.42, green: 0.44, blue: 0.60)]
        }
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var localizationKey: LocalizationKey {
        switch self {
        case .general: return .settingsSectionGeneral
        case .appSources: return .settingsSectionAppSources
        case .sound: return .settingsSectionSound
        case .gameController: return .settingsSectionGameController
        case .appearance: return .settingsSectionAppearance
        case .performance: return .settingsSectionPerformance
        case .titles: return .settingsSectionTitles
        case .hiddenApps: return .settingsSectionHiddenApps
        case .development: return .settingsSectionDevelopment
        case .updates: return .settingsSectionUpdates
        case .about: return .settingsSectionAbout
        }
    }
}

    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 160)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(1), Color.white.opacity(0)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 16) {
                    Text(appStore.localized(section.localizationKey))
                        .font(.title3.bold())

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            content(for: section)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollBounceBehavior(.basedOnSize)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func content(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            generalSection
        case .appearance:
            appearanceSection
        case .performance:
            performanceSection
        case .titles:
            titlesSection
        case .appSources:
            appSourcesSection
        case .hiddenApps:
            hiddenAppsSection
        case .development:
            developmentSection
        case .sound:
            soundSection
        case .gameController:
            gameControllerSection
        case .updates:
            updatesSection
        case .about:
            aboutSection
        }
    }

    private var gameControllerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(appStore.localized(.gameControllerPlaceholderTitle))
                    .font(.headline.weight(.semibold))

                Toggle(isOn: $appStore.gameControllerEnabled) {
                    Text(appStore.localized(.gameControllerToggleTitle))
                        .font(.subheadline.weight(.semibold))
                }
                .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 6) {
                    Text(gameControllerStatusText)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(appStore.localized(.gameControllerPlaceholderSubtitle))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .quaternarySystemFill))
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(appStore.localized(.gameControllerQuickGuideTitle))
                    .font(.footnote.weight(.semibold))

                VStack(alignment: .leading, spacing: 6) {
                    guideRow(icon: "dpad", text: appStore.localized(.gameControllerQuickGuideDirection))
                    guideRow(icon: "a.circle.fill", text: appStore.localized(.gameControllerQuickGuideSelect))
                    guideRow(icon: "b.circle.fill", text: appStore.localized(.gameControllerQuickGuideCancel))
                }
            }
        }
    }

    private func guideRow(icon: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var gameControllerStatusText: String {
        if !appStore.gameControllerEnabled {
            return appStore.localized(.gameControllerStatusDisabled)
        }

        let names = controllerManager.connectedControllerNames
        guard !names.isEmpty else {
            return appStore.localized(.gameControllerStatusNoController)
        }

        let joined = names.joined(separator: ", ")
        return String(format: appStore.localized(.gameControllerStatusConnectedFormat), joined)
    }

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle(isOn: $appStore.soundEffectsEnabled) {
                Text(appStore.localized(.soundToggleTitle))
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(.switch)

            Text(appStore.localized(.soundToggleDescription))
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                soundPickerRow(title: .soundEventLaunchpadOpen, binding: $appStore.soundLaunchpadOpenSound)
                soundPickerRow(title: .soundEventLaunchpadClose, binding: $appStore.soundLaunchpadCloseSound)
                soundPickerRow(title: .soundEventNavigation, binding: $appStore.soundNavigationSound)
            }

            Divider()

            Toggle(isOn: $appStore.voiceFeedbackEnabled) {
                Text(appStore.localized(.voiceToggleTitle))
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(.switch)

            Text(appStore.localized(.voiceToggleDescription))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(appStore.localized(.voiceNoteMutualExclusive))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
    }

    private func soundPickerRow(title: LocalizationKey, binding: Binding<String>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(appStore.localized(title))
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 12)

            Picker("", selection: binding) {
                Text(appStore.localized(.soundOptionNone)).tag("")
                ForEach(SoundManager.systemSoundOptions) { option in
                    Text(option.displayName).tag(option.id)
                }
            }
            .labelsHidden()
            .frame(minWidth: 140)

            Button(appStore.localized(.soundPreviewButton)) {
                SoundManager.shared.preview(systemSoundNamed: binding.wrappedValue)
            }
            .disabled(binding.wrappedValue.isEmpty)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private var developmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appStore.localized(.developmentPlaceholderTitle))
                .font(.headline)
            Text(appStore.localized(.developmentPlaceholderSubtitle))
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                Text(currentMemoryUsageString())
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            Toggle(appStore.localized(.showFPSOverlay), isOn: $appStore.showFPSOverlay)
                .toggleStyle(.switch)
            Text(appStore.localized(.showFPSOverlayDisclaimer))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appStore.localized(.performancePlaceholderTitle))
                .font(.headline)
            Text(appStore.localized(.performancePlaceholderSubtitle))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var titlesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    presentCustomTitlePicker()
                } label: {
                    Label(appStore.localized(.customTitleAddButton), systemImage: "plus")
                }
                Spacer()
            }

            let allEntries = customTitleEntries
            let filtered = filteredCustomTitleEntries

            if allEntries.isEmpty {
                customTitleEmptyState
            } else {
                Text(appStore.localized(.customTitleHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("", text: $titleSearch, prompt: Text(appStore.localized(.renameSearchPlaceholder)))
                    .textFieldStyle(.roundedBorder)

                if filtered.isEmpty {
                    Text(appStore.localized(.customTitleNoResults))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    VStack(spacing: 12) {
                        ForEach(filtered) { entry in
                            customTitleRow(for: entry)
                        }
                    }
                }
            }
        }
    }

    private var hiddenAppsSection: some View {
        let entries = hiddenAppEntries
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    presentHiddenAppPicker()
                } label: {
                    Label(appStore.localized(.hiddenAppsAddButton), systemImage: "eye.slash")
                }
                Spacer()
            }

            if entries.isEmpty {
                hiddenAppsEmptyState
            } else {
                Text(appStore.localized(.hiddenAppsHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("", text: $hiddenSearch, prompt: Text(appStore.localized(.hiddenAppsSearchPlaceholder)))
                    .textFieldStyle(.roundedBorder)

                let filtered = filteredHiddenAppEntries
                if filtered.isEmpty {
                    Text(appStore.localized(.customTitleNoResults))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    VStack(spacing: 12) {
                        ForEach(filtered) { entry in
                            hiddenAppRow(for: entry)
                        }
                    }
                }
            }
        }
    }

    private var hiddenAppEntries: [HiddenAppEntry] {
        appStore.hiddenAppPaths
            .map { path in
                let info = appStore.appInfoForCustomTitle(path: path)
                let defaultName = appStore.defaultDisplayName(for: path)
                return HiddenAppEntry(id: path, appInfo: info, defaultName: defaultName)
            }
            .sorted { lhs, rhs in
                lhs.appInfo.name.localizedCaseInsensitiveCompare(rhs.appInfo.name) == .orderedAscending
            }
    }

    private var filteredHiddenAppEntries: [HiddenAppEntry] {
        let base = hiddenAppEntries
        let trimmed = hiddenSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        let query = trimmed.lowercased()
        return base.filter { entry in
            if entry.appInfo.name.lowercased().contains(query) { return true }
            if entry.defaultName.lowercased().contains(query) { return true }
            if entry.id.lowercased().contains(query) { return true }
            return false
        }
    }

    private var hiddenAppsEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appStore.localized(.hiddenAppsEmptyTitle))
                .font(.headline)
            Text(appStore.localized(.hiddenAppsEmptySubtitle))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                presentHiddenAppPicker()
            } label: {
                Label(appStore.localized(.hiddenAppsAddButton), systemImage: "eye.slash")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func hiddenAppRow(for entry: HiddenAppEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: entry.appInfo.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.appInfo.name)
                    .font(.callout.weight(.semibold))
                Text(entry.defaultName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.id)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                appStore.unhideApp(path: entry.id)
            } label: {
                Text(appStore.localized(.hiddenAppsRemoveButton))
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct HiddenAppEntry: Identifiable {
        let id: String
        let appInfo: AppInfo
        let defaultName: String
    }

    private var customTitleEntries: [CustomTitleEntry] {
        appStore.customTitles
            .map { (path, _) in
                let info = appStore.appInfoForCustomTitle(path: path)
                let defaultName = appStore.defaultDisplayName(for: path)
                return CustomTitleEntry(id: path, appInfo: info, defaultName: defaultName)
            }
            .sorted { lhs, rhs in
                lhs.appInfo.name.localizedCaseInsensitiveCompare(rhs.appInfo.name) == .orderedAscending
            }
    }

    private var filteredCustomTitleEntries: [CustomTitleEntry] {
        let base = customTitleEntries
        let trimmed = titleSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        let query = trimmed.lowercased()
        return base.filter { entry in
            let custom = entry.appInfo.name.lowercased()
            if custom.contains(query) { return true }
            if entry.defaultName.lowercased().contains(query) { return true }
            if entry.id.lowercased().contains(query) { return true }
            return false
        }
    }

    private var customTitleEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appStore.localized(.customTitleEmptyTitle))
                .font(.headline)
            Text(appStore.localized(.customTitleEmptySubtitle))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                presentCustomTitlePicker()
            } label: {
                Label(appStore.localized(.customTitleAddButton), systemImage: "plus")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func customTitleRow(for entry: CustomTitleEntry) -> some View {
        let isEditing = editingEntries.contains(entry.id)
        let currentDraft = editingDrafts[entry.id] ?? appStore.customTitles[entry.id] ?? entry.appInfo.name
        let trimmedDraft = currentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalValue = appStore.customTitles[entry.id] ?? entry.defaultName
        let draftBinding = Binding(
            get: { editingDrafts[entry.id] ?? appStore.customTitles[entry.id] ?? entry.appInfo.name },
            set: { editingDrafts[entry.id] = $0 }
        )

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: entry.appInfo.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.appInfo.name)
                        .font(.callout.weight(.semibold))
                    Text(String(format: appStore.localized(.customTitleDefaultFormat), entry.defaultName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    if isEditing {
                        Button(appStore.localized(.customTitleSave)) {
                            saveCustomTitle(entry)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(trimmedDraft.isEmpty || trimmedDraft == originalValue)

                        Button(appStore.localized(.customTitleCancel)) {
                            cancelEditing(entry)
                        }
                        .buttonStyle(.bordered)

                        if !(appStore.customTitles[entry.id]?.isEmpty ?? true) {
                            Button(role: .destructive) {
                                removeCustomTitle(entry)
                            } label: {
                                Text(appStore.localized(.customTitleDelete))
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button(appStore.localized(.customTitleEdit)) {
                            beginEditing(entry)
                        }
                        .buttonStyle(.bordered)

                        if !(appStore.customTitles[entry.id]?.isEmpty ?? true) {
                            Button(role: .destructive) {
                                removeCustomTitle(entry)
                            } label: {
                                Text(appStore.localized(.customTitleDelete))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if isEditing {
                TextField("", text: draftBinding, prompt: Text(appStore.localized(.customTitlePlaceholder)))
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(14)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func presentHiddenAppPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.prompt = appStore.localized(.hiddenAppsAddButton)
        panel.title = appStore.localized(.hiddenAppsAddButton)

        if panel.runModal() == .OK, let url = panel.url {
            if !appStore.hideApp(at: url) {
                NSSound.beep()
            }
        }
    }

    private func presentCustomTitlePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.title = appStore.localized(.customTitleAddButton)
        panel.message = appStore.localized(.customTitlePickerMessage)
        panel.prompt = appStore.localized(.chooseButton)

        if panel.runModal() == .OK, let url = panel.url, let info = appStore.ensureCustomTitleEntry(for: url) {
            let path = info.url.path
            editingEntries.insert(path)
            editingDrafts[path] = appStore.customTitles[path] ?? info.name
        }
    }

    private func presentAppIconPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.icns, .png, .jpeg, .tiff]
        panel.prompt = appStore.localized(.customIconChoose)
        panel.title = appStore.localized(.customIconTitle)

        if panel.runModal() == .OK, let url = panel.url {
            if !appStore.setCustomAppIcon(from: url) {
                iconImportError = appStore.localized(.customIconError)
            }
        }
    }

    private func presentAppSourcePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = appStore.localized(.chooseButton)

        if panel.runModal() == .OK {
            var addedAny = false
            for url in panel.urls {
                if appStore.addCustomAppSource(path: url.path) {
                    addedAny = true
                }
            }
            if !addedAny && !panel.urls.isEmpty {
                NSSound.beep()
            }
        }
    }

    private func pathExists(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    private func displayName(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        return name.isEmpty ? path : name
    }

    @ViewBuilder
    private func appSourceRow(icon: String, path: String, isAvailable: Bool, @ViewBuilder accessory: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(displayName(for: path))
                        .font(.body)
                    if !isAvailable {
                        Text(appStore.localized(.scanSourcesMissingBadge))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.18)))
                    }
                }
                Text(path)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)
            accessory()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private struct CustomTitleEntry: Identifiable {
        let id: String
        let appInfo: AppInfo
        let defaultName: String
    }

    private func beginEditing(_ entry: CustomTitleEntry) {
        editingEntries.insert(entry.id)
        editingDrafts[entry.id] = appStore.customTitles[entry.id] ?? entry.appInfo.name
    }

    private func cancelEditing(_ entry: CustomTitleEntry) {
        editingEntries.remove(entry.id)
        editingDrafts.removeValue(forKey: entry.id)
    }

    private func saveCustomTitle(_ entry: CustomTitleEntry) {
        let draft = (editingDrafts[entry.id] ?? appStore.customTitles[entry.id] ?? entry.appInfo.name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else { return }
        let original = appStore.customTitles[entry.id] ?? entry.defaultName
        if draft == original {
            editingEntries.remove(entry.id)
            editingDrafts.removeValue(forKey: entry.id)
            return
        }
        appStore.setCustomTitle(draft, for: entry.appInfo)
        editingEntries.remove(entry.id)
        editingDrafts.removeValue(forKey: entry.id)
    }

    private func removeCustomTitle(_ entry: CustomTitleEntry) {
        appStore.clearCustomTitle(for: entry.appInfo)
        editingEntries.remove(entry.id)
        editingDrafts.removeValue(forKey: entry.id)
    }

    private static let modifierOnlyKeyCodes: Set<UInt16> = [55, 54, 58, 61, 56, 60, 59, 62, 57]

    private func startShortcutCapture() {
        stopShortcutCapture(cancel: false)
        pendingShortcut = nil
        isCapturingShortcut = true
        shortcutCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleShortcutCapture(event: event)
        }
    }

    private func stopShortcutCapture(cancel: Bool) {
        if let monitor = shortcutCaptureMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutCaptureMonitor = nil
        }
        if cancel {
            pendingShortcut = nil
            if isCapturingShortcut { NSSound.beep() }
        }
        isCapturingShortcut = false
    }

    private func handleShortcutCapture(event: NSEvent) -> NSEvent? {
        let normalizedFlags = event.modifierFlags.normalizedShortcutFlags

        if event.keyCode == 53 && normalizedFlags.isEmpty {
            stopShortcutCapture(cancel: true)
            return nil
        }

        guard !normalizedFlags.isEmpty, !Self.modifierOnlyKeyCodes.contains(event.keyCode) else {
            NSSound.beep()
            return nil
        }

        pendingShortcut = AppStore.HotKeyConfiguration(keyCode: event.keyCode, modifierFlags: normalizedFlags)
        return nil
    }

    private func savePendingShortcut() {
        guard let shortcut = pendingShortcut else { return }
        appStore.setGlobalHotKey(keyCode: shortcut.keyCode, modifierFlags: shortcut.modifierFlags)
        pendingShortcut = nil
        stopShortcutCapture(cancel: false)
    }

    private var shortcutStatusText: String {
        if isCapturingShortcut {
            if let shortcut = pendingShortcut {
                let base = shortcut.displayString
                if shortcut.modifierFlags.isEmpty {
                    return base + " • " + appStore.localized(.shortcutNoModifierWarning)
                }
                return base
            }
            return appStore.localized(.shortcutCapturePrompt)
        }
        if let saved = appStore.globalHotKey {
            let base = saved.displayString
            if saved.modifierFlags.isEmpty {
                return base + " • " + appStore.localized(.shortcutNoModifierWarning)
            }
            return base
        }
        return appStore.localized(.shortcutNotSet)
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appStore.localized(.appTitle))
                        .font(.title2.weight(.semibold))
                    Text("\(appStore.localized(.versionPrefix))\(getVersion())")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(appStore.localized(.modifiedFrom))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(appStore.localized(.backgroundHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TicTacToeBoard()
                    .frame(width: 130)
            }

            Link(destination: URL(string: "https://github.com/RoversX/LaunchNext")!) {
                Label(appStore.localized(.viewOnGitHub), systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.link)
        }
    }

    // MARK: - Inline Games
    private struct TicTacToeBoard: View {
        private enum Mark: String {
            case x = "X", o = "O", empty = ""
        }

        @State private var cells: [Mark] = Array(repeating: .empty, count: 9)
        @State private var isPlayerTurn: Bool = true
        @State private var statusText: String = "Your turn"
        @State private var gameOver: Bool = false

        var body: some View {
            VStack(spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(0..<9) { index in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                            Text(cells[index].rawValue)
                                .font(.system(size: 28, weight: .bold))
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            guard !gameOver, isPlayerTurn, cells[index] == .empty else { return }
                            makeMove(at: index, mark: .x)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                aiTurn()
                            }
                        }
                    }
                }
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(action: resetGame) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }

        private func makeMove(at index: Int, mark: Mark) {
            cells[index] = mark
            if let winner = evaluateWinner() {
                statusText = winner == .x ? "You win!" : "AI wins!"
                gameOver = true
            } else if !cells.contains(.empty) {
                statusText = "Draw"
                gameOver = true
            } else {
                isPlayerTurn.toggle()
                statusText = isPlayerTurn ? "Your turn" : "AI thinking..."
            }
        }

        private func aiTurn() {
            guard !gameOver else { return }
            guard !isPlayerTurn else { return }

            let emptyCells = cells.enumerated().filter { $0.element == .empty }.map { $0.offset }
            guard let choice = emptyCells.randomElement() else { return }
            makeMove(at: choice, mark: .o)
        }

        private func evaluateWinner() -> Mark? {
            let lines = [
                [0,1,2],[3,4,5],[6,7,8],
                [0,3,6],[1,4,7],[2,5,8],
                [0,4,8],[2,4,6]
            ]
            for line in lines {
                let marks = line.map { cells[$0] }
                if marks.allSatisfy({ $0 == .x }) { return .x }
                if marks.allSatisfy({ $0 == .o }) { return .o }
            }
            return nil
        }

        private func resetGame() {
            cells = Array(repeating: .empty, count: 9)
            isPlayerTurn = true
            statusText = "Your turn"
            gameOver = false
        }
    }

    private func currentMemoryUsageString() -> String {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
        let kern = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        guard kern == KERN_SUCCESS else { return "Memory: --" }

        let usedBytes = info.phys_footprint
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        let formatted = formatter.string(fromByteCount: Int64(usedBytes))
        return "Memory: \(formatted)"
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(appStore.localized(.languagePickerTitle))
                        .font(.headline)
                    Picker(appStore.localized(.languagePickerTitle), selection: $appStore.preferredLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(appStore.localizedLanguageName(for: language)).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(appStore.localized(.appearanceModeTitle))
                        .font(.headline)
                    Picker(appStore.localized(.appearanceModeTitle), selection: $appStore.appearancePreference) {
                        ForEach(AppearancePreference.allCases) { preference in
                            Text(appStore.localized(preference.localizationKey)).tag(preference)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                Spacer(minLength: 0)
            }

            Toggle(appStore.localized(.launchAtLoginTitle), isOn: $appStore.isStartOnLogin)
            .toggleStyle(.switch)
            .disabled(!appStore.canConfigureStartOnLogin)

            VStack(alignment: .leading, spacing: 12) {
                Text(appStore.localized(.customIconTitle))
                    .font(.headline)
                HStack(spacing: 16) {
                    Image(nsImage: appStore.currentAppIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.1)))
                        .shadow(radius: 6, y: 3)

                    VStack(alignment: .leading, spacing: 8) {
                        Button(appStore.localized(.customIconChoose)) {
                            presentAppIconPicker()
                        }
                        .buttonStyle(.bordered)

                        Button(appStore.localized(.customIconReset)) {
                            appStore.resetCustomAppIcon()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(!appStore.hasCustomAppIcon)
                    }
                }

                Text(appStore.localized(.customIconHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(appStore.localized(.importSystem))
                    .font(.headline)
                HStack(spacing: 12) {
                    Button { importFromLaunchpad() } label: {
                        Label(appStore.localized(.importSystem), systemImage: "square.and.arrow.down.on.square")
                    }
                    .help(appStore.localized(.importTip))

                    Button { importLegacyArchive() } label: {
                        Label(appStore.localized(.importLegacy), systemImage: "clock.arrow.circlepath")
                    }
                }
                Text(appStore.localized(.importTip))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button { exportDataFolder() } label: {
                        Label(appStore.localized(.exportData), systemImage: "square.and.arrow.up")
                    }

                    Button { importDataFolder() } label: {
                        Label(appStore.localized(.importData), systemImage: "square.and.arrow.down")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 32) {
                    Toggle(appStore.localized(.lockLayoutTitle), isOn: $appStore.isLayoutLocked)
                        .toggleStyle(.switch)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle(appStore.localized(.showQuickRefreshButton), isOn: $appStore.showQuickRefreshButton)
                        .toggleStyle(.switch)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(appStore.localized(.lockLayoutDescription))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button { appStore.refresh() } label: {
                    Label(appStore.localized(.refresh), systemImage: "arrow.clockwise")
                }
                Spacer()
                Button {
                    showResetConfirm = true
                } label: {
                    Label(appStore.localized(.resetLayout), systemImage: "arrow.counterclockwise")
                        .foregroundStyle(Color.red)
                }
                .alert(appStore.localized(.resetAlertTitle), isPresented: $showResetConfirm) {
                    Button(appStore.localized(.resetConfirm), role: .destructive) { appStore.resetLayout() }
                    Button(appStore.localized(.cancel), role: .cancel) {}
                } message: {
                    Text(appStore.localized(.resetAlertMessage))
                }
                Button {
                    AppDelegate.shared?.quitWithFade()
                } label: {
                    Label(appStore.localized(.quit), systemImage: "xmark.circle")
                        .foregroundStyle(Color.red)
                }
            }
        }
    }

    private var appSourcesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(appStore.localized(.scanSourcesIntroTitle))
                    .font(.headline)
                Text(appStore.localized(.scanSourcesIntroDescription))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(appStore.localized(.scanSourcesDefaultListTitle))
                    .font(.subheadline.weight(.semibold))
                ForEach(appStore.builtinAppSourcePaths, id: \.self) { path in
                    appSourceRow(icon: "internaldrive", path: path, isAvailable: true, accessory: { EmptyView() })
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(appStore.localized(.scanSourcesCustomListTitle))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button {
                        presentAppSourcePicker()
                    } label: {
                        Label(appStore.localized(.scanSourcesAddButton), systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)

                    Button {
                        showAppSourcesResetDialog = true
                    } label: {
                        Label(appStore.localized(.scanSourcesResetButton), systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(appStore.customAppSourcePaths.isEmpty)
                }

                if appStore.customAppSourcePaths.isEmpty {
                    Text(appStore.localized(.scanSourcesEmptyHint))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                } else {
                    ForEach(appStore.customAppSourcePaths, id: \.self) { path in
                        appSourceRow(icon: "folder", path: path, isAvailable: pathExists(path)) {
                            Button {
                                appStore.removeCustomAppSource(path: path)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Color.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .confirmationDialog(appStore.localized(.scanSourcesResetButton), isPresented: $showAppSourcesResetDialog, titleVisibility: .visible) {
            Button(appStore.localized(.scanSourcesResetButton), role: .destructive) {
                appStore.resetCustomAppSources()
            }
            Button(appStore.localized(.cancel), role: .cancel) {}
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(appStore.localized(.classicMode))
                    Spacer()
                    Toggle("", isOn: $appStore.isFullscreenMode)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.showLabels))
                    Spacer()
                    Toggle("", isOn: $appStore.showLabels)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.useLocalizedThirdPartyTitles))
                    Spacer()
                    Toggle("", isOn: $appStore.useLocalizedThirdPartyTitles)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.predictDrop))
                    Spacer()
                    Toggle("", isOn: $appStore.enableDropPrediction)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.enableAnimations))
                    Spacer()
                    Toggle("", isOn: $appStore.enableAnimations)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.hideDockOption))
                    Spacer()
                    Toggle("", isOn: $appStore.hideDock)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.hoverMagnification))
                    Spacer()
                    Toggle("", isOn: $appStore.enableHoverMagnification)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.activePressEffect))
                    Spacer()
                    Toggle("", isOn: $appStore.enableActivePressEffect)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.backgroundStyleTitle))
                        .font(.headline)
                    Picker("", selection: $appStore.launchpadBackgroundStyle) {
                        ForEach(AppStore.BackgroundStyle.allCases) { style in
                            Text(appStore.localized(style.localizationKey)).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.animationDurationLabel))
                        .font(.headline)
                    Slider(value: $appStore.animationDuration, in: 0.1...1.0, step: 0.05)
                        .disabled(!appStore.enableAnimations)
                    HStack {
                        Text("0.1s").font(.footnote)
                        Spacer()
                        Text(String(format: "%.2fs", appStore.animationDuration))
                            .font(.footnote)
                        Spacer()
                        Text("1.0s").font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.iconLabelFontWeight))
                        .font(.headline)
                    Picker("", selection: $appStore.iconLabelFontWeight) {
                        ForEach(AppStore.IconLabelFontWeightOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.iconSize))
                        .font(.headline)
                    Slider(value: $appStore.iconScale, in: 0.6...1.1)
                    HStack {
                        Text(appStore.localized(.smaller)).font(.footnote)
                        Spacer()
                        Text(appStore.localized(.larger)).font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.folderWindowWidth))
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.0f%%", appStore.folderPopoverWidthFactor * 100))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $appStore.folderPopoverWidthFactor,
                           in: AppStore.folderPopoverWidthRange)
                        .disabled(appStore.isFullscreenMode)
                    HStack {
                        Text(String(format: "%.0f%%", AppStore.folderPopoverWidthRange.lowerBound * 100))
                            .font(.footnote)
                        Spacer()
                        Text(String(format: "%.0f%%", AppStore.folderPopoverWidthRange.upperBound * 100))
                            .font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.folderWindowHeight))
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.0f%%", appStore.folderPopoverHeightFactor * 100))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $appStore.folderPopoverHeightFactor,
                           in: AppStore.folderPopoverHeightRange)
                        .disabled(appStore.isFullscreenMode)
                    HStack {
                        Text(String(format: "%.0f%%", AppStore.folderPopoverHeightRange.lowerBound * 100))
                            .font(.footnote)
                        Spacer()
                        Text(String(format: "%.0f%%", AppStore.folderPopoverHeightRange.upperBound * 100))
                            .font(.footnote)
                    }
                }

                Text(appStore.localized(.folderWindowSizeHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.hoverMagnificationScale))
                        .font(.headline)
                    Slider(value: $appStore.hoverMagnificationScale,
                           in: AppStore.hoverMagnificationRange)
                        .disabled(!appStore.enableHoverMagnification)
                    HStack {
                        Text(String(format: "%.2fx", AppStore.hoverMagnificationRange.lowerBound))
                            .font(.footnote)
                        Spacer()
                        Text(String(format: "%.2fx", appStore.hoverMagnificationScale))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2fx", AppStore.hoverMagnificationRange.upperBound))
                            .font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.activePressScale))
                        .font(.headline)
                    Slider(value: $appStore.activePressScale,
                           in: AppStore.activePressScaleRange)
                        .disabled(!appStore.enableActivePressEffect)
                    HStack {
                        Text(String(format: "%.2fx", AppStore.activePressScaleRange.lowerBound))
                            .font(.footnote)
                        Spacer()
                        Text(String(format: "%.2fx", appStore.activePressScale))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2fx", AppStore.activePressScaleRange.upperBound))
                            .font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.iconsPerRow))
                            .font(.headline)
                        Spacer()
                        Stepper(value: $appStore.gridColumnsPerPage, in: AppStore.gridColumnRange) {
                            Text("\(appStore.gridColumnsPerPage)")
                                .font(.callout.monospacedDigit())
                        }
                        .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.rowsPerPage))
                            .font(.headline)
                        Spacer()
                        Stepper(value: $appStore.gridRowsPerPage, in: AppStore.gridRowRange) {
                            Text("\(appStore.gridRowsPerPage)")
                                .font(.callout.monospacedDigit())
                        }
                        .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.iconHorizontalSpacing))
                            .font(.headline)
                        Spacer()
                        Text("\(Int(appStore.iconColumnSpacing)) pt")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $appStore.iconColumnSpacing,
                           in: AppStore.columnSpacingRange,
                           step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.iconVerticalSpacing))
                            .font(.headline)
                        Spacer()
                        Text("\(Int(appStore.iconRowSpacing)) pt")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $appStore.iconRowSpacing,
                           in: AppStore.rowSpacingRange,
                           step: 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(appStore.localized(.gridSizeChangeWarning))
                    Text(appStore.localized(.pageIndicatorHint))
                        .foregroundStyle(.tertiary)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.globalShortcutTitle))
                        .font(.headline)
                    HStack(spacing: 12) {
                        Button {
                            if isCapturingShortcut {
                                stopShortcutCapture(cancel: true)
                            } else {
                                startShortcutCapture()
                            }
                        } label: {
                            Text(isCapturingShortcut ? appStore.localized(.cancel) : appStore.localized(.shortcutSetButton))
                        }

                        Button(appStore.localized(.shortcutSaveButton)) {
                            savePendingShortcut()
                        }
                        .disabled(!(isCapturingShortcut && pendingShortcut != nil))

                        Button(appStore.localized(.shortcutClearButton)) {
                            stopShortcutCapture(cancel: false)
                            pendingShortcut = nil
                            appStore.clearGlobalHotKey()
                        }
                        .disabled(!isCapturingShortcut && appStore.globalHotKey == nil)
                    }

                    Text(shortcutStatusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Toggle(appStore.localized(.rememberPageTitle), isOn: $appStore.rememberLastPage)
                    .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.labelFontSize))
                        .font(.headline)
                    Slider(value: $appStore.iconLabelFontSize, in: 9...16, step: 0.5)
                    HStack {
                        Text("9pt").font(.footnote)
                        Spacer()
                        Text("16pt").font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.scrollSensitivity))
                        .font(.headline)
                    Slider(value: $appStore.scrollSensitivity, in: 0.01...0.99)
                    HStack {
                        Text(appStore.localized(.low)).font(.footnote)
                        Spacer()
                        Text(appStore.localized(.high)).font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.pageIndicatorOffsetLabel))
                        .font(.headline)
                    Slider(value: $appStore.pageIndicatorOffset, in: 0...80)
                    HStack {
                        Text("0").font(.footnote)
                        Spacer()
                        Text(String(format: "%.0f", appStore.pageIndicatorOffset)).font(.footnote)
                        Spacer()
                        Text("80").font(.footnote)
                    }
                }
            }
        }
    }

    // MARK: - Export / Import Application Support Data
    private func supportDirectoryURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = appSupport.appendingPathComponent("LaunchNext", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func exportDataFolder() {
        do {
            let sourceDir = try supportDirectoryURL()
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = appStore.localized(.chooseButton)
            panel.message = appStore.localized(.exportPanelMessage)
            if panel.runModal() == .OK, let destParent = panel.url {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let folderName = "LaunchNext_Export_" + formatter.string(from: Date())
                let destDir = destParent.appendingPathComponent(folderName, isDirectory: true)
                try copyDirectory(from: sourceDir, to: destDir)
            }
        } catch {
            // 忽略错误或可在此添加用户提示
        }
    }

    private func importDataFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = appStore.localized(.importPrompt)
        panel.message = appStore.localized(.importPanelMessage)
        if panel.runModal() == .OK, let srcDir = panel.url {
            do {
                // 验证是否为有效的排序数据目录
                guard isValidExportFolder(srcDir) else { return }
                let destDir = try supportDirectoryURL()
                // 若用户选的就是目标目录，跳过
                if srcDir.standardizedFileURL == destDir.standardizedFileURL { return }
                try replaceDirectory(with: srcDir, at: destDir)
                // 导入完成后加载并刷新
                appStore.applyOrderAndFolders()
                appStore.refresh()
            } catch {
                // 忽略错误或可在此添加用户提示
            }
        }
    }

    private func copyDirectory(from src: URL, to dst: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dst.path) {
            try fm.removeItem(at: dst)
        }
        try fm.copyItem(at: src, to: dst)
    }

    private func replaceDirectory(with src: URL, at dst: URL) throws {
        let fm = FileManager.default
        // 确保父目录存在
        let parent = dst.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: dst.path) {
            try fm.removeItem(at: dst)
        }
        try fm.copyItem(at: src, to: dst)
    }

    private func isValidExportFolder(_ folder: URL) -> Bool {
        let fm = FileManager.default
        let storeURL = folder.appendingPathComponent("Data.store")
        guard fm.fileExists(atPath: storeURL.path) else { return false }
        // 尝试打开该库并检查是否有排序数据
        do {
            let config = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(for: TopItemData.self, PageEntryData.self, configurations: config)
            let ctx = container.mainContext
            let pageEntries = try ctx.fetch(FetchDescriptor<PageEntryData>())
            if !pageEntries.isEmpty { return true }
            let legacyEntries = try ctx.fetch(FetchDescriptor<TopItemData>())
            return !legacyEntries.isEmpty
        } catch {
            return false
        }
    }

    private func importFromLaunchpad() {
        Task {
            let result = await appStore.importFromNativeLaunchpad()

            DispatchQueue.main.async {
                let alert = NSAlert()
                if result.success {
                    alert.messageText = appStore.localized(.importSuccessfulTitle)
                    alert.informativeText = result.message
                    alert.alertStyle = .informational
                } else {
                    alert.messageText = appStore.localized(.importFailedTitle)
                    alert.informativeText = result.message
                    alert.alertStyle = .warning
                }
                alert.addButton(withTitle: appStore.localized(.okButton))
                alert.runModal()
            }
        }
    }

    private func importLegacyArchive() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ["lmy", "zip", "db"].compactMap { UTType(filenameExtension: $0) }
        panel.prompt = appStore.localized(.importPrompt)
        panel.message = appStore.localized(.legacyArchivePanelMessage)

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                let result = await appStore.importFromLegacyLaunchpadArchive(url: url)
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    if result.success {
                        alert.messageText = appStore.localized(.importSuccessfulTitle)
                        alert.informativeText = result.message
                        alert.alertStyle = .informational
                    } else {
                        alert.messageText = appStore.localized(.importFailedTitle)
                        alert.informativeText = result.message
                        alert.alertStyle = .warning
                    }
                    alert.addButton(withTitle: appStore.localized(.okButton))
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Update Check Section
    private var updatesSection: some View {
        let isChecking = appStore.updateState == .checking

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appStore.localized(.checkForUpdates))
                        .font(.headline)

                    switch appStore.updateState {
                    case .idle:
                        Button(action: {
                            appStore.checkForUpdates()
                        }) {
                            Label(appStore.localized(.checkForUpdatesButton), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)

                    case .checking:
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(appStore.localized(.checkingForUpdates))
                                .foregroundStyle(.secondary)
                        }

                    case .upToDate(let latest):
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(appStore.localized(.upToDate))
                                .foregroundStyle(.secondary)
                        }

                    case .updateAvailable(let release):
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "party.popper.fill")
                                    .foregroundStyle(.orange)
                                Text(appStore.localized(.updateAvailable))
                                    .font(.subheadline.weight(.medium))
                            }

                            Text(appStore.localized(.newVersion) + " \(release.version)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if let notes = release.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            Button {
                                appStore.launchUpdater(for: release)
                            } label: {
                                Label(appStore.localized(.downloadUpdate), systemImage: "arrow.down.circle")
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                appStore.openReleaseURL(release.url)
                            } label: {
                                Label(appStore.localized(.viewOnGitHub), systemImage: "arrow.up.right.square")
                            }
                            .buttonStyle(.bordered)
                        }

                    case .failed(let error):
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(appStore.localized(.updateCheckFailed))
                                    .font(.subheadline.weight(.medium))
                            }

                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button(action: {
                                appStore.checkForUpdates()
                            }) {
                                Label(appStore.localized(.tryAgain), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    appStore.checkForUpdates()
                } label: {
                    Label(appStore.localized(.updatesRefreshButton), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isChecking)

                Button {
                    appStore.openUpdaterConfigFile()
                } label: {
                    Label(appStore.localized(.openUpdaterConfig), systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 自动检查更新开关
            Toggle(appStore.localized(.autoCheckForUpdates), isOn: $appStore.autoCheckForUpdates)
                .font(.footnote)
        }
    }
}
