import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var role: String  // "user" or "assistant"
    var content: String
    var actionsTaken: [String] = []
    var isLoading: Bool = false
}

@MainActor
class AIViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isThinking = false
    @Published var error: String?

    // Triggers budget/transaction refresh in sibling VMs
    @Published var shouldRefreshBudget = false
    @Published var shouldRefreshTransactions = false

    private let baseURL: String = {
        ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:3000"
    }()

    func send(text: String, year: Int, month: Int) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Append user message
        messages.append(ChatMessage(role: "user", content: text))

        // Placeholder while loading
        var thinking = ChatMessage(role: "assistant", content: "")
        thinking.isLoading = true
        messages.append(thinking)
        isThinking = true
        error = nil

        // Build message history for API (exclude the thinking placeholder)
        let apiMessages = messages
            .filter { !$0.isLoading }
            .map { ["role": $0.role, "content": $0.content] }

        do {
            let result = try await callChat(messages: apiMessages, year: year, month: month)

            // Remove thinking placeholder
            messages.removeAll { $0.isLoading }

            var reply = ChatMessage(role: "assistant", content: result.content)
            reply.actionsTaken = result.actionsTaken
            messages.append(reply)

            if result.refreshBudget { shouldRefreshBudget = true }
            if result.refreshTransactions { shouldRefreshTransactions = true }
        } catch {
            messages.removeAll { $0.isLoading }
            self.error = error.localizedDescription
        }

        isThinking = false
    }

    func clearConversation() {
        messages = []
        error = nil
    }

    // MARK: - Network

    private struct ChatResponse: Decodable {
        let content: String
        let actionsTaken: [String]
        let refreshBudget: Bool
        let refreshTransactions: Bool

        enum CodingKeys: String, CodingKey {
            case content
            case actionsTaken = "actions_taken"
            case refreshBudget = "refresh_budget"
            case refreshTransactions = "refresh_transactions"
        }
    }

    private func callChat(messages: [[String: String]], year: Int, month: Int) async throws -> ChatResponse {
        guard let url = URL(string: "\(baseURL)/api/ai/chat") else {
            throw URLError(.badURL)
        }

        let body: [String: Any] = [
            "messages": messages,
            "year": year,
            "month": month
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60  // AI can take a while with tool calls

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Server \(http.statusCode): \(msg)"])
        }

        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }
}
