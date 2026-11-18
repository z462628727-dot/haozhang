import SwiftUI
import Combine

private enum Palette {
    static let ink = Color(red: 0.21, green: 0.18, blue: 0.24)
    static let muted = Color(red: 0.53, green: 0.46, blue: 0.57)
    static let plum = Color(red: 0.47, green: 0.37, blue: 0.55)
    static let background = Color(red: 0.96, green: 0.94, blue: 0.91)
    static let paper = Color(red: 1.0, green: 0.99, blue: 0.97)
    static let line = Color(red: 0.89, green: 0.85, blue: 0.90)
}

@MainActor
struct CompanionView: View {
    @ObservedObject var model: CompanionModel
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { size in
            let landscape = size.size.width > size.size.height
            VStack(spacing: 14) {
                HStack(spacing: 11) {
                    Image(systemName: "sparkle").font(.title2).foregroundStyle(Palette.plum)
                        .frame(width: 40, height: 40).overlay(Circle().stroke(Palette.line))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.displayName).font(.system(size: 25, design: .serif))
                        Text("X I N G L I").font(.system(size: 8)).foregroundStyle(Palette.muted)
                    }
                    if size.size.width > 650 { Text("留一点时间，给自己。").font(.caption).foregroundStyle(Palette.muted).padding(.leading, 18) }
                    Spacer()
                    Button { model.showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3").font(.title3).frame(width: 44, height: 44)
                    }.accessibilityLabel("打开连接与偏好设置").disabled(model.sending)
                }
                .foregroundStyle(Palette.ink)

                if landscape {
                    HStack(spacing: 18) {
                        CharacterScene(model: model, compact: false).frame(width: max(250, size.size.width * 0.39))
                        ChatPanel(model: model)
                    }
                } else {
                    VStack(spacing: 14) {
                        CharacterScene(model: model, compact: true).frame(height: min(320, max(170, size.size.height * 0.30)))
                        ChatPanel(model: model)
                    }
                }
                HStack {
                    Text("陪伴有形，心事有处安放。")
                    Spacer()
                    Text("原生 iPad 应用 · 对话保存在本机")
                }.font(.system(size: 9)).foregroundStyle(Palette.muted.opacity(0.8))
            }
            .padding(.horizontal, size.size.width < 600 ? 14 : 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background.ignoresSafeArea())
        }
        .tint(Palette.plum)
        .onReceive(timer) { _ in model.updateFocus() }
        .sheet(isPresented: $model.showSettings) { CompanionSettingsView(model: model) }
    }
}

@MainActor
private struct CharacterScene: View {
    @ObservedObject var model: CompanionModel
    let compact: Bool
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var allowMotion: Bool { !systemReduceMotion && !model.settings.reduceMotion && !model.resting }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(red: 0.93, green: 0.88, blue: 0.89), Color(red: 0.83, green: 0.77, blue: 0.86)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RoundedRectangle(cornerRadius: width * 0.36)
                    .fill(Color.white.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: width * 0.36).stroke(Color.white.opacity(0.65), lineWidth: 2))
                    .frame(width: width * 0.66, height: height * 0.86)
                    .position(x: width * 0.60, y: height * 0.55)
                VStack(alignment: .leading, spacing: compact ? 8 : 14) {
                    Text("YOUR QUIET CORNER").font(.system(size: 8)).tracking(2)
                    Text(compact ? "此刻，陪你。" : "此刻，\n陪你。")
                        .font(.system(size: compact ? 32 : 48, weight: .regular, design: .serif)).tracking(4)
                        .foregroundStyle(Palette.ink.opacity(0.85))
                    Text("不急，我们慢慢说。").font(.caption)
                }
                .foregroundStyle(Palette.muted)
                .padding(.leading, width * 0.075).padding(.top, compact ? 26 : 36)
                Image("Xingli")
                    .resizable().scaledToFit()
                    .frame(width: width * (compact ? 0.48 : 0.93), height: height * (compact ? 0.90 : 0.82))
                    .rotationEffect(.degrees(allowMotion ? (breathing ? 0.35 : -0.35) : 0))
                    .offset(y: allowMotion && breathing ? -5 : 0)
                    .animation(allowMotion ? Animation.easeInOut(duration: 2.8).repeatForever(autoreverses: true) : nil, value: breathing)
                    .position(x: width * (compact ? 0.74 : 0.60), y: height * (compact ? 0.49 : 0.56))
                    .onTapGesture { model.touch() }
                    .accessibilityLabel("轻触\(model.displayName)，与她互动")
                    .accessibilityAddTraits(.isButton)
                if !model.bubble.isEmpty {
                    Text(model.bubble).font(.caption).lineSpacing(4).padding(13)
                        .frame(maxWidth: width * (compact ? 0.48 : 0.82), alignment: .leading)
                        .background(Palette.paper.opacity(0.96), in: RoundedRectangle(cornerRadius: 15))
                        .padding(.leading, width * 0.06).padding(.top, height * (compact ? 0.43 : 0.63))
                        .allowsHitTesting(false)
                }
                VStack {
                    Spacer()
                    HStack {
                        Label(model.displayName + "在这里", systemImage: "circle.fill")
                            .labelStyle(PresenceLabelStyle())
                        Spacer()
                        Button { model.toggleRest() } label: { Text(model.resting ? "✧ 唤醒星璃" : "☾ 安静陪伴").font(.caption2).padding(10) }
                            .background(Color.white.opacity(0.40), in: Capsule())
                    }.font(.caption2).foregroundStyle(Palette.muted).padding(compact ? 15 : 20)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .onAppear { breathing = true }
        .onChange(of: allowMotion) { enabled in
            breathing = false
            if enabled { DispatchQueue.main.async { breathing = true } }
        }
    }
}

private struct PresenceLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) { configuration.icon.font(.system(size: 5)); configuration.title }
    }
}

@MainActor
private struct ChatPanel: View {
    @ObservedObject var model: CompanionModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text("A LITTLE CONVERSATION").font(.system(size: 8)).tracking(1.7).foregroundStyle(Palette.muted)
                    Text("想说什么，都可以。").font(.system(size: 23, design: .serif))
                }
                Spacer()
                Text(model.modeTitle).font(.system(size: 10)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Palette.line.opacity(0.4), in: Capsule()).foregroundStyle(Palette.muted)
            }.padding(22)

            if model.settings.mode == .offline || model.apiKey.isEmpty {
                HStack(alignment: .center, spacing: 8) {
                    Text("✧")
                    Text(model.settings.mode == .offline ? "现在是离线预设互动。连接 AI 后，就能自由聊天。" : "填写模型和本次使用的密钥后，就能继续 AI 对话。")
                        .font(.system(size: 10)).lineSpacing(3)
                    Spacer(minLength: 2)
                    Button("设置 ↗") { model.showSettings = true }.font(.system(size: 10)).disabled(model.sending)
                }.foregroundStyle(Palette.muted).padding(11).background(Palette.line.opacity(0.25), in: RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 22)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if model.messages.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(model.displayName).font(.caption2).foregroundStyle(Palette.muted)
                                Text("你好，我是\(model.displayName)。\n今天想聊点什么？\n\n一件小事、一点疲惫，\n或只是安静待一会儿，都可以。")
                                    .font(.system(size: 18, design: .serif)).lineSpacing(9).foregroundStyle(Palette.plum)
                                    .padding(.leading, 15).overlay(alignment: .leading) { Rectangle().fill(Palette.line).frame(width: 1) }
                            }.padding(.vertical, 8)
                        }
                        ForEach(model.messages) { message in
                            MessageBubble(message: message, name: model.displayName) { model.speak(message.text) }.id(message.id)
                        }
                    }.padding(22)
                }
                .onChange(of: model.messages.count) { _ in
                    if let id = model.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }
            if !model.status.isEmpty {
                Text(model.status).font(.caption2).foregroundStyle(model.sending ? Palette.muted : Color(red: 0.65, green: 0.30, blue: 0.28))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.vertical, 7)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    Button("☁ 今天有点累") { model.send("今天有点累，想和你聊聊。") }.disabled(model.sending)
                    Button("◷ " + model.focusTitle) { model.toggleFocus() }
                    Button("☾ 说声晚安") { model.send("准备休息了，和我说声晚安吧。") }.disabled(model.sending)
                }.buttonStyle(ChipStyle()).padding(.horizontal, 20).padding(.vertical, 7)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("把今天的小事，说给我听…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...4).font(.system(size: 16)).submitLabel(.send).onSubmit { model.send() }
                    .padding(.vertical, 8)
                Button { model.send() } label: {
                    Image(systemName: model.sending ? "stop.fill" : "arrow.up").font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white).frame(width: 44, height: 44).background(Palette.plum, in: RoundedRectangle(cornerRadius: 12))
                }.accessibilityLabel(model.sending ? "停止回复" : "发送消息")
            }.padding(10).padding(.leading, 5).overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line)).padding(.horizontal, 20)
            HStack {
                Text("对话保存在这台 iPad · 密钥不落盘")
                Spacer()
                Text(model.sending ? "轻点方块可停止" : "此刻，陪你")
            }.font(.system(size: 9)).foregroundStyle(Palette.muted).padding(.horizontal, 23).padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Palette.ink).background(Palette.paper, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.line.opacity(0.8)))
    }
}

private struct ChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.horizontal, 12).frame(minHeight: 37)
            .background(configuration.isPressed ? Palette.line.opacity(0.6) : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(Palette.line))
    }
}

private struct MessageBubble: View {
    let message: CompanionMessage
    let name: String
    let read: () -> Void
    private var isUser: Bool { message.role == "user" }
    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 7) {
            HStack {
                if isUser { Spacer() }
                Text(isUser ? "你" : name + (message.source == .offline ? " · 离线回应" : ""))
                if message.source == .failed { Text("未完成") }
                if !isUser { Spacer(); Button(action: read) { Image(systemName: "speaker.wave.2").frame(width: 30, height: 28) }.accessibilityLabel("朗读这条回复") }
            }.font(.system(size: 10)).foregroundStyle(Palette.muted)
            Text(message.text).font(.system(size: 14)).lineSpacing(7).textSelection(.enabled)
                .padding(15).frame(maxWidth: .infinity, alignment: .leading)
                .background(isUser ? Palette.line.opacity(0.7) : Palette.line.opacity(0.28), in: RoundedRectangle(cornerRadius: 15))
        }.padding(.leading, isUser ? 40 : 0).padding(.trailing, isUser ? 0 : 30)
    }
}

@MainActor
private struct CompanionSettingsView: View {
    @ObservedObject var model: CompanionModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false
    var body: some View {
        NavigationStack {
            Form {
                Section("角色") {
                    TextField("角色称呼", text: $model.settings.name)
                        .onChange(of: model.settings.name) { value in if value.count > 16 { model.settings.name = String(value.prefix(16)) } }
                    Toggle("减少动画", isOn: $model.settings.reduceMotion)
                    Toggle("读出回复", isOn: $model.settings.readAloud)
                }
                Section {
                    Picker("陪伴方式", selection: $model.settings.mode) {
                        ForEach(CompanionMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    if model.settings.mode == .ai {
                        Picker("模型服务", selection: $model.settings.provider) {
                            ForEach(ModelProvider.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        TextField("模型名称", text: $model.settings.model).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("本次使用的 API 密钥", text: $model.apiKey).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                } header: { Text("AI 对话") } footer: {
                    Text("默认提供明确标注的离线预设回应。连接 AI 后，消息和最近的 AI 对话由 iPad 直接提交给所选模型服务。需要自备模型账户；服务可能收费。密钥仅保留在当前运行内存，重新启动应用后需再填写。")
                }
                Section {
                    ShareLink(item: model.exportText) { Label("分享或备份聊天文本", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) { confirmClear = true } label: { Label("清空本机聊天", systemImage: "trash") }.disabled(model.sending)
                } header: { Text("本机数据") } footer: {
                    Text("角色、设置和最多 100 条消息保存在当前设备，不需要登录 ChatGPT，也不通过网站加载角色。聊天不自动跨设备同步。")
                }
            }
            .navigationTitle("连接与偏好")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { model.save(); dismiss() } } }
            .confirmationDialog("清空当前设备上保存的聊天？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("确认清空", role: .destructive) { model.clearMessages() }
                Button("取消", role: .cancel) { }
            }
        }.tint(Palette.plum).onDisappear { model.save() }
    }
}
