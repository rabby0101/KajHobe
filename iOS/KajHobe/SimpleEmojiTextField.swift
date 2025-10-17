import SwiftUI

struct EmojiTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    @Binding var isEmoji: Bool
    
    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .textFieldStyle(PlainTextFieldStyle())
            .lineLimit(1...6)
    }
}