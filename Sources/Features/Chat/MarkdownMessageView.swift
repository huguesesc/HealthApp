import Foundation
import SwiftUI

enum ChatMarkdownRenderer {
    static func attributedString(from markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }
}

struct MarkdownMessageView: View {
    let markdown: String

    var body: some View {
        Text(ChatMarkdownRenderer.attributedString(from: markdown))
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
            .tint(Theme.evergreen)
    }
}
