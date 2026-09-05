import SwiftUI

/// The script content as ONE laid-out block of styled text (WP5).
///
/// Layout happens once per content/settings/width change; per-frame scrolling
/// is a pure `.offset` translation applied by the parent — never a re-layout
/// (this is what keeps 10k-word scripts at 60 FPS, see team/PLAN.md).
///
/// Very long scripts are chunked by lines into a handful of `Text` views
/// stacked in a plain (non-lazy) VStack. The stack spacing equals the
/// line-spacing gap, so chunk boundaries are visually identical to the line
/// breaks they replace, and the whole stack still translates as one unit.
struct PrompterTextBlock: View, Equatable {
    let content: String
    let settings: ReadingSettings
    let viewportWidth: CGFloat

    /// Closure-free equality lets the parent wrap this view in `.equatable()`
    /// so its body is NOT re-evaluated on every frame of scrolling.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.viewportWidth == rhs.viewportWidth
            && lhs.settings == rhs.settings
            && lhs.content == rhs.content
    }

    /// Extra points between lines: multiplier 1.0 means no extra gap.
    private var lineGap: CGFloat {
        CGFloat((settings.lineSpacing - 1) * settings.fontSize)
    }

    var body: some View {
        textStack
            .font(settings.font.font(size: settings.fontSize))
            .lineSpacing(lineGap)
            .multilineTextAlignment(.leading)
            .foregroundStyle(settings.textColor.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, viewportWidth * settings.marginFraction)
        // Height is measured by PrompterView via onGeometryChange — a
        // preference key from a background GeometryReader was not reliably
        // delivered on iPadOS 26 (QA Bug B).
    }

    @ViewBuilder
    private var textStack: some View {
        if content.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: lineGap) {
                ForEach(Array(chunks.enumerated()), id: \.offset) { chunk in
                    Text(chunk.element)
                }
            }
        }
    }

    // MARK: Chunking

    private static let linesPerChunk = 24

    private var chunks: [String] {
        let lines = content.components(separatedBy: "\n")
        guard lines.count > Self.linesPerChunk else { return [content] }
        var result: [String] = []
        result.reserveCapacity(lines.count / Self.linesPerChunk + 1)
        var start = 0
        while start < lines.count {
            let end = min(start + Self.linesPerChunk, lines.count)
            result.append(lines[start..<end].joined(separator: "\n"))
            start = end
        }
        return result
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.plaintext")
                .font(.system(size: 44))
            Text("This script has no content")
                .font(.title3.weight(.medium))
            Text("Close the prompter and write something first.")
                .font(.callout)
                .opacity(0.8)
        }
        .foregroundStyle(settings.textColor.color.opacity(0.45))
        .frame(maxWidth: .infinity)
        .padding(.top, 160)
        .padding(.bottom, 80)
    }
}

// MARK: - Font mapping

/// Settings/ is SwiftUI-free, so the 5 fixed font choices (SPEC F3) map to
/// SwiftUI fonts here in the view layer.
extension PrompterFont {
    func font(size: Double) -> Font {
        switch self {
        case .sfPro: .system(size: size)
        case .newYork: .system(size: size, design: .serif)
        case .helveticaNeue: .custom("Helvetica Neue", size: size)
        case .georgia: .custom("Georgia", size: size)
        case .menlo: .custom("Menlo", size: size)
        }
    }
}
