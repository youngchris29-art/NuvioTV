import SwiftUI

/// Focusable poster. `.buttonStyle(.card)` already gives the tvOS lift + parallax,
/// but we add a focus ring + title reveal to match Nuvio's look.
struct PosterCard: View {
    let title: String
    let url: URL?

    @Environment(\.isFocused) private var isFocused

    private let posterSize = CGSize(width: 240, height: 360)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.gray.opacity(0.2))
                    .overlay(ProgressView())
            }
            .frame(width: posterSize.width, height: posterSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.12, green: 0.53, blue: 0.90), // Nuvio accent #1E88E5
                            lineWidth: isFocused ? 4 : 0)
            )

            Text(title)
                .font(.caption)
                .lineLimit(1)
                .frame(width: posterSize.width, alignment: .leading)
                .opacity(isFocused ? 1 : 0.6)
        }
    }
}
