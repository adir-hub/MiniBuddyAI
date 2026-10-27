import Cocoa
import SwiftUI

@main
struct MiniBuddyApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = AppDelegate()
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var buddyWindow: NSWindow!
    private var chatWindow: NSWindow!
    private let model = BuddyModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupBuddyWindow()
        setupChatWindow()
        setupStatusBar()
    }

    private func setupBuddyWindow() {
        let content = BuddyView(model: model)

        buddyWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 180),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        buddyWindow.isReleasedWhenClosed = false
        buddyWindow.backgroundColor = .clear
        buddyWindow.isOpaque = false
        buddyWindow.hasShadow = false
        buddyWindow.level = .floating
        buddyWindow.isMovableByWindowBackground = true
        buddyWindow.contentView = NSHostingView(rootView: content)
        buddyWindow.center()
        buddyWindow.makeKeyAndOrderFront(nil)
    }

    private func setupChatWindow() {
        chatWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        chatWindow.title = "MiniBuddy"
        chatWindow.center()
        chatWindow.contentView = NSHostingView(rootView: ChatView(model: model))
        chatWindow.isReleasedWhenClosed = false
        chatWindow.orderOut(nil)
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "✨"
            button.target = self
            button.action = #selector(toggleChatWindow)
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open MiniBuddy", action: #selector(toggleChatWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let buddyItem = NSMenuItem(title: "Show/Hide Buddy", action: #selector(toggleBuddy), keyEquivalent: "b")
        buddyItem.target = self
        menu.addItem(buddyItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleChatWindow() {
        if chatWindow.isVisible {
            chatWindow.orderOut(nil)
        } else {
            chatWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func toggleBuddy() {
        if buddyWindow.isVisible {
            buddyWindow.orderOut(nil)
        } else {
            buddyWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

enum AIProvider: String, CaseIterable, Identifiable {
    case ollama
    case openAI

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ollama: return "Ollama"
        case .openAI: return "OpenAI-compatible"
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

final class BuddyModel: ObservableObject {
    enum Mood: String {
        case idle = "🙂"
        case listening = "👂"
        case thinking = "🤔"
        case speaking = "😊"
        case happy = "😄"
        case confused = "😵"
        case error = "😬"
    }

    @Published var mood: Mood = .idle
    @Published var isTalking = false
    @Published var inputText: String = ""
    @Published var messages: [ChatMessage] = [
        ChatMessage(text: "Hey! I’m MiniBuddy. Ask me anything.", isUser: false)
    ]
    @Published var provider: AIProvider = .ollama
    @Published var modelName: String = "llama3.2"
    @Published var apiKey: String = ""
    @Published var isProcessing = false

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        messages.append(ChatMessage(text: text, isUser: true))
        mood = .listening
        isTalking = false
        isProcessing = true

        Task {
            let reply = await AIService.generateReply(
                prompt: text,
                provider: provider,
                modelName: modelName,
                apiKey: apiKey
            )

            await MainActor.run {
                messages.append(ChatMessage(text: reply, isUser: false))
                mood = .idle
                isProcessing = false
            }
        }
    }

    func cycleMood() {
        let all: [Mood] = [.idle, .listening, .thinking, .speaking, .happy, .confused, .error]
        if let idx = all.firstIndex(of: mood) {
            mood = all[(idx + 1) % all.count]
        }
    }

    func setMood(_ mood: Mood) {
        self.mood = mood
    }
}

enum AIService {
    static func generateReply(prompt: String, provider: AIProvider, modelName: String, apiKey: String) async -> String {
        switch provider {
        case .ollama:
            return await callOllama(prompt: prompt, modelName: modelName)
        case .openAI:
            return await callOpenAI(prompt: prompt, apiKey: apiKey)
        }
    }

    static func callOllama(prompt: String, modelName: String) async -> String {
        let model = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            return "No Ollama model is configured yet. Set a model name in Settings."
        }

        let urlString = "http://localhost:11434/api/generate"
        guard let url = URL(string: urlString) else {
            return "Cannot reach local Ollama server."
        }

        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return "I couldn’t reach Ollama. Make sure Ollama is running and the model is installed."
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let text = json?["response"] as? String ?? "No response from Ollama."
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "Ollama is not responding. Start it and try again."
        }
    }

    static func callOpenAI(prompt: String, apiKey: String) async -> String {
        guard !apiKey.isEmpty else {
            return "No API key configured. Add your token in Settings."
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return "OpenAI request failed. Check your API key and internet connection."
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let choices = json?["choices"] as? [[String: Any]]
            let firstChoice = choices?.first
            let message = firstChoice?["message"] as? [String: Any]
            let content = message?["content"] as? String ?? "No response from OpenAI."

            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "OpenAI request failed."
        }
    }
}

struct BuddyView: View {
    @ObservedObject var model: BuddyModel

    var body: some View {
        VStack(spacing: 8) {
            Text(model.mood.rawValue)
                .font(.system(size: 58))
                .scaleEffect(model.isTalking ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: model.isTalking)

            Text("MiniBuddy")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text(model.isProcessing ? "Thinking..." : "Ready")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(width: 180, height: 180)
        .background(Color.black.opacity(0.22))
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        .onTapGesture {
            model.cycleMood()
            model.isTalking.toggle()
        }
    }
}

struct ChatView: View {
    @ObservedObject var model: BuddyModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MiniBuddy")
                    .font(.title2.bold())
                Spacer()
                Button(model.isProcessing ? "Working..." : "Send") {
                    model.sendMessage()
                }
                .disabled(model.isProcessing || model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(model.messages) { msg in
                            HStack {
                                if msg.isUser {
                                    Spacer()
                                }

                                Text(msg.text)
                                    .padding(10)
                                    .frame(maxWidth: 420, alignment: msg.isUser ? .trailing : .leading)
                                    .background(msg.isUser ? Color.blue.opacity(0.8) : Color.gray.opacity(0.2))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)

                                if !msg.isUser {
                                    Spacer()
                                }
                            }
                            .id(msg.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: model.messages.count) { _, _ in
                    if let last = model.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            HStack {
                TextField("Type your message...", text: $model.inputText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                Button("Send") {
                    model.sendMessage()
                }
                .disabled(model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isProcessing)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("AI Settings")
                    .font(.headline)

                Picker("Provider", selection: $model.provider) {
                    ForEach(AIProvider.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                if model.provider == .ollama {
                    TextField("Model name", text: $model.modelName)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("API key", text: $model.apiKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(10)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9))
    }
}
