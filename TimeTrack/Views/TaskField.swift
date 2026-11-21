import SwiftUI

/// Task text field with suggestion chips from the project's earlier tasks.
struct TaskField: View {
    @Binding var text: String
    let project: Project?
    var onCommit: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Task (optional)", text: $text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(onCommit)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { onCommit() }
                }

            let suggestions = TimerService.taskSuggestions(for: project, matching: text)
            if focused && !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                text = suggestion
                                focused = false
                                onCommit()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}
