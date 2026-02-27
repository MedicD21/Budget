import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject var aiVM: AIViewModel
    @EnvironmentObject var budgetVM: BudgetViewModel
    @EnvironmentObject var txVM: TransactionViewModel

    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    private let starterPrompts = [
        ("wand.and.stars", "Fund upcoming bills", "Fund all upcoming bills from ready to assign"),
        ("chart.line.uptrend.xyaxis", "Spending summary", "Give me a summary of my spending this month"),
        ("dollarsign.circle", "Budget advice", "How should I allocate my remaining budget?"),
        ("arrow.left.arrow.right.circle", "Move money", "Help me move money between categories"),
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages list
                if aiVM.messages.isEmpty {
                    emptyState
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(aiVM.messages) { msg in
                                    MessageBubble(message: msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                        }
                        .onChange(of: aiVM.messages.count) { _, _ in
                            if let last = aiVM.messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }

                Divider().background(Theme.surfaceHigh)

                // Input bar
                inputBar
            }
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !aiVM.messages.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { aiVM.clearConversation() }) {
                        Image(systemName: "trash")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .onChange(of: aiVM.shouldRefreshBudget) { _, refresh in
            if refresh {
                Task { await budgetVM.load() }
                aiVM.shouldRefreshBudget = false
            }
        }
        .onChange(of: aiVM.shouldRefreshTransactions) { _, refresh in
            if refresh {
                Task { await txVM.load() }
                aiVM.shouldRefreshTransactions = false
            }
        }
        .alert("Error", isPresented: .init(
            get: { aiVM.error != nil },
            set: { if !$0 { aiVM.error = nil } }
        )) {
            Button("OK") { aiVM.error = nil }
        } message: {
            Text(aiVM.error ?? "")
        }
    }

    // MARK: - Empty state with starter prompts

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.green.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "brain.filled.head.profile")
                            .font(.system(size: 32))
                            .foregroundStyle(Theme.green)
                    }
                    Text("Budget Assistant")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Ask me anything about your finances,\nor tell me what you want to do.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Text("QUICK ACTIONS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)

                    ForEach(starterPrompts, id: \.1) { icon, label, prompt in
                        Button(action: { sendMessage(prompt) }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Theme.green.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(Theme.green)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(label)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(prompt)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Theme.surface)
                            .cornerRadius(14)
                            .padding(.horizontal, 16)
                        }
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask or tell me something…", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.green)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.surfaceHigh)
                .cornerRadius(20)
                .onSubmit { sendMessage(inputText) }

            Button(action: { sendMessage(inputText) }) {
                ZStack {
                    Circle()
                        .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty || aiVM.isThinking
                              ? Theme.surfaceHigh : Theme.green)
                        .frame(width: 40, height: 40)
                    if aiVM.isThinking {
                        ProgressView()
                            .tint(Theme.green)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                             ? Theme.textTertiary : .black)
                    }
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || aiVM.isThinking)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.surface)
    }

    // MARK: - Helpers

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !aiVM.isThinking else { return }
        inputText = ""
        inputFocused = false
        Task {
            await aiVM.send(
                text: trimmed,
                year: budgetVM.selectedYear,
                month: budgetVM.selectedMonth
            )
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    var message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                if !isUser {
                    assistantAvatar
                }

                if message.isLoading {
                    TypingIndicator()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Theme.surface)
                        .cornerRadius(18)
                } else {
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundStyle(isUser ? Color.black : Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isUser ? Theme.green : Theme.surface)
                        .cornerRadius(18)
                        .textSelection(.enabled)
                }

                if isUser {
                    Spacer().frame(width: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            // Actions taken chips
            if !message.actionsTaken.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(message.actionsTaken, id: \.self) { action in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.green)
                                Text(action)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.leading, isUser ? 0 : 44)
                }
            }
        }
    }

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(Theme.green.opacity(0.15))
                .frame(width: 30, height: 30)
            Image(systemName: "brain.filled.head.profile")
                .font(.system(size: 14))
                .foregroundStyle(Theme.green)
        }
    }
}

// MARK: - Typing indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.textTertiary)
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1.3 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}
