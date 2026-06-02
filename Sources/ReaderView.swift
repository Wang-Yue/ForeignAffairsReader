import SwiftUI

struct ReaderView: View {
  var model: AppModel

  var body: some View {
    let activeArticle = model.translatedArticle ?? model.article

    ZStack {
      if let article = activeArticle {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            // Header Area
            VStack(alignment: .leading, spacing: 16) {
              if !article.issue.isEmpty {
                Text(article.issue)
                  .font(.sansSerif(size: 12, weight: .bold))
                  .foregroundColor(.accentColor)
                  .tracking(1.5)
                  .textCase(.uppercase)
              }

              Text(article.title)
                .font(.serif(size: 36 * model.fontSizeMultiplier))
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

              if !article.subtitle.isEmpty {
                Text(article.subtitle)
                  .font(.serif(size: 19 * model.fontSizeMultiplier))
                  .italic()
                  .foregroundColor(.secondary)
                  .lineSpacing(4)
                  .fixedSize(horizontal: false, vertical: true)
              }

              Divider()
                .padding(.vertical, 8)

              HStack {
                if !article.byline.isEmpty {
                  Text(article.byline)
                    .font(.sansSerif(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                }
                Spacer()
                if !article.date.isEmpty {
                  Text(article.date)
                    .font(.sansSerif(size: 13))
                    .foregroundColor(.secondary)
                }
              }
            }
            .padding(.bottom, 12)

            // Cover/Featured Image
            if !article.image.isEmpty {
              AsyncImage(url: URL(string: article.image)) { phase in
                switch phase {
                case .success(let image):
                  image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                case .empty, .failure(_):
                  EmptyView()
                @unknown default:
                  EmptyView()
                }
              }
              .padding(.bottom, 12)
            }

            // Article Body Paragraphs (rendered as a single Text block to allow seamless cross-paragraph selection)
            Text(buildBodyAttributedString(for: article))
              .lineSpacing(8)
              .id(article)
          }
          .frame(maxWidth: 680)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.horizontal, 32)
          .padding(.vertical, 48)
          .textSelection(.enabled)
        }
        .transition(.move(edge: .bottom))
      } else {
        // Elegant Empty/Welcome Screen
        VStack(spacing: 24) {
          Spacer()
          Text("✦")
            .font(.system(size: 48))
            .foregroundColor(.accentColor)

          Text(model.uiString("Welcome to Foreign Affairs"))
            .font(.serif(size: 28))
            .italic()
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)

          Text(
            model.uiString(
              "Select an article from the sidebar to begin reading in premium reader mode."
            )
          )
          .font(.sansSerif(size: 14, weight: .light))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(6)
          .frame(maxWidth: 380)

          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
      }
    }
    .background(.background)
    .animation(.easeInOut(duration: 0.25), value: activeArticle == nil)
  }

  private func buildBodyAttributedString(for article: ArticleData) -> AttributedString {
    var result = AttributedString()

    for (index, element) in article.elements.enumerated() {
      if index > 0 {
        result.append(AttributedString("\n\n"))
      }

      var elementStr = AttributedString(element.text)

      switch element.type {
      case "h3":
        elementStr.font = .sansSerif(size: 21 * model.fontSizeMultiplier, weight: .bold)
        elementStr.foregroundColor = .accentColor
        result.append(elementStr)

      case "blockquote":
        var prefixStr = AttributedString("┃   ")
        prefixStr.font = .serif(size: 22 * model.fontSizeMultiplier)
        prefixStr.foregroundColor = .accentColor

        elementStr.font = .serif(size: 22 * model.fontSizeMultiplier).italic()
        elementStr.foregroundColor = .secondary

        result.append(prefixStr)
        result.append(elementStr)

      default:
        elementStr.font = .serif(size: 18 * model.fontSizeMultiplier)
        elementStr.foregroundColor = .primary
        result.append(elementStr)
      }
    }

    return result
  }
}

// Helper extensions to dynamically select custom pre-installed fonts or fall back to beautiful system fonts
extension Font {
  static func serif(size: CGFloat) -> Font {
    return .system(size: size, design: .serif)
  }

  static func sansSerif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    return .system(size: size, weight: weight, design: .default)
  }
}
