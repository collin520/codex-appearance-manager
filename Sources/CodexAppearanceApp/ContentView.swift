import AppKit
import SwiftUI
import CodexAppearanceCore

public struct ContentView: View {
    @ObservedObject private var viewModel: AppearanceViewModel

    public init(viewModel: AppearanceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedThemeID) {
                Section("THEMES") {
                    ForEach(viewModel.themes, id: \.manifest.id) { theme in
                        ThemeRow(theme: theme)
                            .tag(Optional(theme.manifest.id))
                    }
                }
            }
            .navigationTitle("Codex 外观")
            .onChange(of: viewModel.selectedThemeID) { _, id in
                viewModel.selectTheme(id: id)
            }
        } detail: {
            if let theme = viewModel.selectedTheme {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ThemeHeader(theme: theme, status: viewModel.status)
                        controls
                        cssEditor
                    }
                    .padding(28)
                }
                .background(Color(nsColor: .windowBackgroundColor))
            } else {
                ContentUnavailableView("没有可用主题", systemImage: "paintpalette", description: Text("打开主题文件夹后，可添加有效的主题包。"))
            }
        }
        .frame(minWidth: 850, minHeight: 620)
        .onAppear { viewModel.load() }
        .alert("以本机调试模式重新打开 Codex？", isPresented: $viewModel.restartConfirmationPresented) {
            Button("取消", role: .cancel) {}
            Button("重新打开 Codex") {
                Task { await viewModel.restartAndInject() }
            }
        } message: {
            Text("请先用 ⌘Q 完全退出当前 Codex。此操作不会强制关闭它；管理器会直接以本机调试参数启动可执行文件。窗口出现后先检查连接，再点击“注入 Codex 样式”。")
        }
    }

    private var cssEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("主题 CSS", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.headline)
                Spacer()
                Button("保存 CSS") { viewModel.saveDraft() }
                    .buttonStyle(.borderless)
            }
            TextEditor(text: $viewModel.cssDraft)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 290)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.35)))
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button("Inject Codex Style") {
                    Task { await viewModel.injectSelectedTheme() }
                }
                .buttonStyle(.borderedProminent)

                Button("Restore Original") {
                    Task { await viewModel.restoreOriginal() }
                }

                Button("Restart Codex and Inject") {
                    viewModel.restartConfirmationPresented = true
                }

                Button("Check Codex Connection") {
                    Task { await viewModel.checkCodexConnection() }
                }
            }
            HStack(spacing: 14) {
                Button("Open Themes Folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([viewModel.themesFolderURL])
                }
                .buttonStyle(.link)
                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(statusColor)
            }
        }
    }

    private var statusText: String {
        switch viewModel.status {
        case .idle: return "准备中"
        case .ready: return "主题已准备好；尚未连接或注入。"
        case .injected(let id): return "已注入：\(id)。关闭管理器不会撤销当前窗口的效果。"
        case .incompatible(let selectors): return "当前 Codex 不兼容：缺少 \(selectors.joined(separator: "、"))"
        case .restored: return "已移除本管理器注入的样式。"
        case .restartNeeded: return "尚未发现本机调试连接。手动退出 Codex 后，选择重新打开。"
        case .quitCodexFirst: return "Codex 仍在运行。请先用 ⌘Q 完全退出，再重试。"
        case .debugLaunchStarted: return "已直接以调试参数启动 Codex；等待窗口出现后点击 Check Codex Connection。"
        case .debugConnectionReady: return "已确认连接到本机 Codex 调试目标；现在可以注入样式。"
        case .missingApplication: return "未在 /Applications 找到 Codex 或 ChatGPT。"
        case .failure(let message): return message
        }
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .injected, .restored, .ready, .debugConnectionReady: return .green
        case .incompatible, .restartNeeded, .quitCodexFirst, .debugLaunchStarted, .missingApplication: return .orange
        case .failure: return .red
        case .idle: return .secondary
        }
    }
}

private struct ThemeRow: View {
    let theme: ThemePackage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(theme.manifest.name)
                    .fontWeight(.medium)
                Spacer()
                PaletteSwatches(colors: theme.manifest.palette)
            }
            Text(theme.manifest.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 5)
    }
}

private struct ThemeHeader: View {
    let theme: ThemePackage
    let status: AppearanceStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(theme.manifest.name)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(theme.manifest.description)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                PaletteSwatches(colors: theme.manifest.palette)
            }
            Text("仅针对本机运行中的 Codex；不会修改 App、不会常驻，也不会自动注入。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(LinearGradient(colors: theme.manifest.palette.prefix(2).map(Color.init(hex:)) + [.black.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.34), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct PaletteSwatches: View {
    let colors: [String]

    var body: some View {
        HStack(spacing: -5) {
            ForEach(colors, id: \.self) { color in
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(.white.opacity(0.35)))
            }
        }
    }
}

private extension Color {
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
