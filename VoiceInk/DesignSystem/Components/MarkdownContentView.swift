import SwiftUI

struct MarkdownContentView: View {
    let text: String
    var fontSize: CGFloat
    var foregroundColor: Color
    var alignment: Alignment

    init(
        _ text: String,
        fontSize: CGFloat,
        foregroundColor: Color,
        alignment: Alignment = .leading
    ) {
        self.text = text
        self.fontSize = fontSize
        self.foregroundColor = foregroundColor
        self.alignment = alignment
    }

    var body: some View {
        Text(text)
            .font(.system(size: fontSize))
            .foregroundStyle(foregroundColor)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}
