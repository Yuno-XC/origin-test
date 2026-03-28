//
//  KeyboardInputView.swift
//  TVremote
//
//  Text input keyboard overlay
//

import SwiftUI

struct KeyboardInputView: View {
    @Binding var text: String
    @Binding var isPresented: Bool

    let onSendCharacter: (String) -> Void
    let onDelete: () -> Void
    let onEnter: () -> Void
    let onDone: () -> Void

    @FocusState private var isFocused: Bool
    @State private var previousText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Type on TV")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    onDone()
                    isPresented = false
                }) {
                    Text("Done")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))

            // Text field
            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text("Start typing...")
                            .foregroundColor(Color(.systemGray3))
                    }

                    TextField("", text: $text)
                        .foregroundColor(.white)
                        .focused($isFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: text) { oldValue, newValue in
                            handleTextChange(old: oldValue, new: newValue)
                        }
                        .onSubmit {
                            onEnter()
                        }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                )

                // Send all button
                if !text.isEmpty {
                    Button(action: {
                        for char in text {
                            onSendCharacter(String(char))
                        }
                        text = ""
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.95))
        }
        .background(Color(.systemGray6))
        .onAppear {
            isFocused = true
            previousText = text
        }
    }

    private func handleTextChange(old: String, new: String) {
        if new.count > old.count {
            // Character added
            let addedChar = String(new.suffix(new.count - old.count))
            onSendCharacter(addedChar)
        } else if new.count < old.count {
            // Character deleted
            let deletedCount = old.count - new.count
            for _ in 0..<deletedCount {
                onDelete()
            }
        }
        previousText = new
    }
}

// MARK: - Full Screen Keyboard Input

struct FullScreenKeyboardView: View {
    @Binding var isPresented: Bool

    let onSendCharacter: (String) -> Void
    let onDelete: () -> Void
    let onEnter: () -> Void
    let onSendText: (String) -> Void  // New callback for sending full text

    @State private var text = ""
    @State private var recentTexts = PersistenceService.shared.loadRecentTexts()
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 20) {
                Spacer()

                // Typing indicator
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)

                    Text("Typing on TV")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                // Text display
                Text(text.isEmpty ? "Start typing..." : text)
                    .font(.title2)
                    .foregroundColor(text.isEmpty ? Color(.systemGray3) : .white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)

                if !recentTexts.isEmpty {
                    recentTextsSection
                }

                // Hidden text field for keyboard
                TextField("", text: $text)
                    .focused($isFocused)
                    .opacity(0)
                    .frame(height: 1)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: text) { oldValue, newValue in
                        handleTextChange(old: oldValue, new: newValue)
                    }
                    .onSubmit {
                        submitCurrentText()
                        onEnter()
                    }

                // Action buttons
                HStack(spacing: 16) {
                    Button(action: {
                        onEnter()
                    }) {
                        HStack {
                            Image(systemName: "return")
                            Text("Enter")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                    }

                    Button(action: {
                        submitCurrentText()
                        isPresented = false
                    }) {
                        Text("Done")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }

    private var recentTextsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                Button("Clear") {
                    PersistenceService.shared.clearRecentTexts()
                    recentTexts.removeAll()
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentTexts, id: \.self) { recentText in
                        Button {
                            text = recentText
                            isFocused = true
                        } label: {
                            Text(recentText)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                )
                        }
                        .accessibilityLabel("Use recent text \(recentText)")
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func submitCurrentText() {
        guard !text.isEmpty else { return }

        let submittedText = text
        onSendText(submittedText)
        recentTexts = PersistenceService.shared.rememberRecentText(submittedText)
        text = ""
    }

    private func handleTextChange(old: String, new: String) {
        // Don't send characters immediately - just update local text
        // Text will be sent when "Done" is clicked
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        FullScreenKeyboardView(
            isPresented: .constant(true),
            onSendCharacter: { print("Char: \($0)") },
            onDelete: { print("Delete") },
            onEnter: { print("Enter") },
            onSendText: { print("Text: \($0)") }
        )
    }
}
