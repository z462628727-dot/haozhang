import Foundation
import Combine
import AVFoundation

enum CompanionMode: String, Codable, CaseIterable, Hashable {
    case offline, ai
    var title: String { self == .offline ? "离线互动" : "连接 AI" }
}

enum ModelProvider: String, Codable, CaseIterable, Hashable {
    case deepseek, openai
    var title: String { self == .deepseek ? "DeepSeek" : "OpenAI" }
    var endpoint: URL {
        URL(string: self == .deepseek ? "https://api.deepseek.com/chat/completions" : "https://api.openai.com/v1/chat/completions")!
    }
}

struct CompanionSettings: Codable {
    var name = "星璃"
    var mode = CompanionMode.offline
    var provider = ModelProvider.deepseek
    var model = ""
    var readAloud = false
    var reduceMotion = false
    var focusEnd: Date?
}

enum MessageSource: String, Codable { case offline, ai, pending, failed }
struct CompanionMessage: Codable, Identifiable {
    var id = UUID()
    var role: String
    var text: String
    var source: MessageSource
    var createdAt = Date()
}

private struct SavedCompanion: Codable {
    var settings: CompanionSettings
    var messages: [CompanionMessage]
}

private struct Completion: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { var content: String? }
        var message: Message
    }
    var choices: [Choice]
}

private struct CompanionFailure: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

private final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class CompanionModel: ObservableObject {
    @Published var settings = CompanionSettings()
    @Published var messages: [CompanionMessage] = []
    @Published var draft = ""
    @Published var apiKey = ""
    @Published var sending = false
    @Published var status = ""
    @Published var showSettings = false
    @Published var resting = false
    @Published var bubble = ""
    @Published var focusSeconds = 0
    private var requestTask: Task<Void, Never>?
    private var bubbleTask: Task<Void, Never>?
    private let speaker = AVSpeechSynthesizer()

    private var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("companion.json")
    }
    var displayName: String {
        let value = settings.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "星璃" : String(value.prefix(16))
    }
    var modeTitle: String {
        settings.mode == .offline ? "离线互动" : (apiKey.isEmpty ? "AI 待连接" : "AI 已配置")
    }
    var focusTitle: String {
        focusSeconds > 0 ? String(format: "%02d:%02d · 结束", focusSeconds / 60, focusSeconds % 60) : "陪我专注"
    }

    init() {
        if let data = try? Data(contentsOf: saveURL), let stored = try? JSONDecoder().decode(SavedCompanion.self, from: data) {
            settings = stored.settings
            messages = Array(stored.messages.suffix(100))
            for index in messages.indices where messages[index].source == .pending { messages[index].source = .failed }
        }
        updateFocus()
    }

    func save() {
        do {
            let stored = SavedCompanion(settings: settings, messages: Array(messages.suffix(100)))
            try JSONEncoder().encode(stored).write(to: saveURL, options: .atomic)
        } catch { status = "本次内容未能保存，请先导出重要对话。" }
    }

    func touch() {
        sayBubble(["不急，我们慢慢来。", "想说点什么，或安静待着，都可以。", "给自己留一点小小的休息时间吧。"].randomElement()!)
    }
    func sayBubble(_ text: String) {
        bubbleTask?.cancel(); bubble = String(text.prefix(85))
        bubbleTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 6_000_000_000) } catch { return }
            self?.bubble = ""
        }
    }
    func toggleRest() { resting.toggle(); sayBubble(resting ? "好，我们安静待一会儿。" : "回来啦。今天过得怎么样？") }

    func toggleFocus() {
        settings.focusEnd = focusSeconds > 0 ? nil : Date().addingTimeInterval(25 * 60)
        updateFocus(); save()
        sayBubble(focusSeconds > 0 ? "开始 25 分钟专注，按自己的节奏来。" : "计时结束了，随时可以再开始。")
    }
    func updateFocus() {
        let remaining = max(0, Int(ceil(settings.focusEnd?.timeIntervalSinceNow ?? 0)))
        if settings.focusEnd != nil && remaining == 0 {
            settings.focusEnd = nil
            sayBubble("这一段专注完成了，起来伸个懒腰吧。")
            save()
        }
        focusSeconds = remaining
    }
    func speak(_ text: String) {
        speaker.stopSpeaking(at: .immediate)
        let speech = AVSpeechUtterance(string: String(text.prefix(4000)))
        speech.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        speech.rate = 0.46
        speaker.speak(speech)
    }
    func clearMessages() {
        guard !sending else { return }
        messages = []; status = ""; speaker.stopSpeaking(at: .immediate); save()
    }
    var exportText: String {
        (["星璃陪伴 · 本机聊天记录", "导出不包含 API 密钥", ""] + messages.map {
            ($0.role == "user" ? "你" : displayName) + ($0.source == .offline ? "（离线互动）" : "") + "：\n" + $0.text + "\n"
        }).joined(separator: "\n")
    }

    func send(_ preset: String? = nil) {
        if sending { requestTask?.cancel(); return }
        let input = (preset ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        guard input.count <= 12000 else { status = "消息较长，请缩短后再发送。"; return }
        let selected = settings
        let token = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if selected.mode == .ai {
            guard !token.isEmpty && !selected.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                status = "先在设置里填写模型名称和本次使用的密钥。"; showSettings = true; return
            }
            guard !token.contains(where: { $0.isWhitespace }) else { status = "请检查密钥格式。"; showSettings = true; return }
        }
        let context = Array(messages.filter { $0.source == .ai }.suffix(24))
        let userMessage = CompanionMessage(role: "user", text: input, source: .pending)
        messages.append(userMessage); draft = ""; sending = true
        status = selected.mode == .ai ? "星璃正在认真想…" : "正在准备离线回应…"
        requestTask = Task { [weak self] in
            guard let self = self else { return }
            defer { self.sending = false; self.requestTask = nil }
            do {
                let reply: String
                if selected.mode == .offline {
                    try await Task.sleep(nanoseconds: 400_000_000)
                    reply = self.offlineReply(input)
                } else {
                    reply = try await self.fetchReply(input, settings: selected, token: token, context: context)
                }
                try Task.checkCancellation()
                let source: MessageSource = selected.mode == .offline ? .offline : .ai
                if let index = self.messages.firstIndex(where: { $0.id == userMessage.id }) { self.messages[index].source = source }
                self.messages.append(CompanionMessage(role: "assistant", text: reply, source: source))
                if self.messages.count > 100 { self.messages = Array(self.messages.suffix(100)) }
                self.status = ""; self.save(); self.sayBubble(reply)
                if self.settings.readAloud { self.speak(reply) }
            } catch {
                if let index = self.messages.firstIndex(where: { $0.id == userMessage.id }) { self.messages[index].source = .failed }
                if Task.isCancelled || (error as? URLError)?.code == .cancelled { self.status = "本次回复已停止。" }
                else if (error as? URLError)?.code == .timedOut { self.status = "等待回复超时，请稍后重试。" }
                else if error is URLError { self.status = "连接失败，请检查网络和模型服务是否可用。" }
                else { self.status = error.localizedDescription }
                self.draft = input; self.save()
            }
        }
    }

    private func fetchReply(_ input: String, settings: CompanionSettings, token: String, context: [CompanionMessage]) async throws -> String {
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard model.count <= 120, model.range(of: "^[A-Za-z0-9_.:/-]+$", options: .regularExpression) != nil else {
            throw CompanionFailure(message: "请检查模型名称。")
        }
        let persona = "你是名叫\(displayName)的AI虚拟陪伴角色，黑色卷发、淡紫眼睛、紫白裙装。用温柔自然的中文说话，有一点轻松俏皮感，通常回答2到5句话。回应用户具体内容，避免套话、过度赞美和说教，不要每次追问。可以陪聊天、学习、计划休息和分享日常。清楚自己是AI，不自称真人，不声称看到用户或读取屏幕。不索求独占，不制造内疚或依赖，尊重用户的现实生活和自主选择。不能确定的事情如实说明。没有工具，不能执行外部操作。"
        let payload: [String: Any] = ["model": model, "stream": false, "messages": [["role": "system", "content": persona]] + context.map { ["role": $0.role, "content": $0.text] } + [["role": "user", "content": input]]]
        var request = URLRequest(url: settings.provider.endpoint)
        request.httpMethod = "POST"; request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let session = URLSession(configuration: .ephemeral, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw CompanionFailure(message: "服务没有返回有效响应。") }
        guard (200...299).contains(response.statusCode) else {
            switch response.statusCode {
            case 401, 403: throw CompanionFailure(message: "服务拒绝访问，请检查密钥、模型权限和服务可用地区。")
            case 429: throw CompanionFailure(message: "服务限流或余额不足，请检查模型账户后重试。")
            case 404: throw CompanionFailure(message: "找不到这个模型，请检查模型名称。")
            default: throw CompanionFailure(message: "AI 服务暂时没有完成回复，请稍后重试。")
            }
        }
        guard let completion = try? JSONDecoder().decode(Completion.self, from: data), let text = completion.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw CompanionFailure(message: "服务没有返回可用的文字。")
        }
        return String(text.prefix(24000))
    }

    private func offlineReply(_ input: String) -> String {
        if input.range(of: "累|难过|烦|伤心|压力", options: .regularExpression) != nil { return "听起来今天有些不好过。先让肩膀松下来，给自己一点喘息的时间。\n\n如果愿意，可以把最在意的那件事写下来。此刻不需要急着找到答案。" }
        if input.range(of: "晚安|睡|休息", options: .regularExpression) != nil { return "今天就先到这里吧。没做完的事，可以留一小条便签给明天。\n\n今晚先好好休息。晚安，愿你醒来时轻松一点。" }
        if input.range(of: "专注|学习|工作", options: .regularExpression) != nil { return "我们先选一件小事，专心做 25 分钟吧。点一下「陪我专注」就能开始计时。\n\n不用一下子完成所有事，我们一小步一小步来。" }
        return "我收到了你写下的话。现在是离线互动，我只能提供几种预设回应。\n\n你可以先在这里记下心事；以后在设置里连接 AI，就能自由聊天。"
    }
}
