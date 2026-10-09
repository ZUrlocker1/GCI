import SpriteKit

#if os(macOS)
typealias WrapFont = NSFont
#else
typealias WrapFont = UIFont
#endif

extension SKLabelNode {

    /// Wraps at spaces, centres every line, and puts air between them.
    ///
    /// `numberOfLines` and `preferredMaxLayoutWidth` alone will break a string
    /// onto two lines, and that is all they do: the lines sit hard against each
    /// other and each one is laid out to the same edge rather than centred
    /// under the one above. "BLACK KING / DESTROYED" wants both — the lines
    /// centred on each other, and a gap between them — and both come from a
    /// paragraph style, which means the text has to be attributed.
    ///
    /// Returns nothing; read `frame` afterwards for the height it came to.
    func wrapCentred(to width: CGFloat, fontNamed name: String) {
        guard width > 0, let string = text, !string.isEmpty else { return }

        numberOfLines = 0
        preferredMaxLayoutWidth = width

        // Measured before the paragraph style goes on, because a single word
        // longer than the width cannot be wrapped — only made smaller.
        if frame.width > width { fontSize *= width / frame.width }

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        // A fifth of the type size: enough to separate two lines of a pixel
        // font, small enough that they still read as one message.
        style.lineSpacing = fontSize * 0.2

        let font = WrapFont(name: name, size: fontSize)
            ?? WrapFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        attributedText = NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: fontColor ?? SKColor.white,
            .paragraphStyle: style,
        ])
    }
}
