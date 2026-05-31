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
                  .foregroundColor(model.readerTheme.accentColor)
                  .tracking(1.5)
                  .textCase(.uppercase)
              }

              Text(article.title)
                .font(.serif(size: 36 * model.fontSizeMultiplier))
                .fontWeight(.bold)
                .foregroundColor(model.readerTheme.primaryTextColor)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

              if !article.subtitle.isEmpty {
                Text(article.subtitle)
                  .font(.serif(size: 19 * model.fontSizeMultiplier))
                  .italic()
                  .foregroundColor(model.readerTheme.secondaryTextColor)
                  .lineSpacing(4)
                  .fixedSize(horizontal: false, vertical: true)
              }

              Divider()
                .background(model.readerTheme.borderColor)
                .padding(.vertical, 8)

              HStack {
                if !article.byline.isEmpty {
                  Text("By ")
                    .font(.sansSerif(size: 13))
                    .foregroundColor(model.readerTheme.secondaryTextColor)
                  + Text(article.byline)
                    .font(.sansSerif(size: 13, weight: .semibold))
                    .foregroundColor(model.readerTheme.primaryTextColor)
                }
                Spacer()
                if !article.date.isEmpty {
                  Text(article.date)
                    .font(.sansSerif(size: 13))
                    .foregroundColor(model.readerTheme.secondaryTextColor)
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
                    .shadow(
                      color: Color.black.opacity(model.readerTheme == .dark ? 0.3 : 0.06),
                      radius: 16,
                      x: 0,
                      y: 6
                    )
                case .empty, .failure(_):
                  EmptyView()
                @unknown default:
                  EmptyView()
                }
              }
              .padding(.bottom, 12)
            }

            // Article Body Paragraphs
            VStack(alignment: .leading, spacing: 20) {
              ForEach(0..<article.elements.count, id: \.self) { index in
                let element = article.elements[index]
                switch element.type {
                case "h3":
                  Text(element.text)
                    .font(.sansSerif(size: 21 * model.fontSizeMultiplier, weight: .bold))
                    .foregroundColor(model.readerTheme.accentColor)
                    .padding(.top, 20)
                    .fixedSize(horizontal: false, vertical: true)
                case "blockquote":
                  HStack(spacing: 0) {
                    Rectangle()
                      .fill(model.readerTheme.accentColor)
                      .frame(width: 3)
                    Text(element.text)
                      .font(.serif(size: 22 * model.fontSizeMultiplier))
                      .italic()
                      .foregroundColor(model.readerTheme.secondaryTextColor)
                      .lineSpacing(6)
                      .padding(.leading, 20)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                  .padding(.vertical, 12)
                default:
                  // "p" or any fallback tag
                  Text(element.text)
                    .font(.serif(size: 18 * model.fontSizeMultiplier))
                    .foregroundColor(model.readerTheme.primaryTextColor)
                    .lineSpacing(8)
                    .padding(.bottom, 8)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
            }
          }
          .frame(maxWidth: 680)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.horizontal, 32)
          .padding(.vertical, 48)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      } else {
        // Elegant Empty/Welcome Screen
        VStack(spacing: 24) {
          Spacer()
          Text("✦")
            .font(.system(size: 48))
            .foregroundColor(model.readerTheme.accentColor)
            .opacity(0.85)

          Text(model.uiString("Welcome to Foreign Affairs"))
            .font(.serif(size: 28))
            .italic()
            .foregroundColor(model.readerTheme.primaryTextColor)
            .multilineTextAlignment(.center)

          Text(
            model.uiString(
              "Select an article from the sidebar to begin reading in premium reader mode."
            )
          )
          .font(.sansSerif(size: 14, weight: .light))
          .foregroundColor(model.readerTheme.secondaryTextColor)
          .multilineTextAlignment(.center)
          .lineSpacing(6)
          .frame(maxWidth: 380)

          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
      }
    }
    .background(model.readerTheme.backgroundColor)
    .animation(.easeInOut(duration: 0.25), value: activeArticle == nil)
    .animation(.easeInOut(duration: 0.25), value: model.readerTheme)
  }
}

// Helper extensions to dynamically select custom pre-installed fonts or fall back to beautiful system fonts
extension Font {
  static func serif(size: CGFloat) -> Font {
    if NSFont(name: "Playfair Display", size: size) != nil {
      return .custom("Playfair Display", size: size)
    } else if NSFont(name: "Georgia", size: size) != nil {
      return .custom("Georgia", size: size)
    } else {
      return .system(size: size, design: .serif)
    }
  }

  static func sansSerif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    if NSFont(name: "Inter", size: size) != nil {
      return .custom("Inter", size: size).weight(weight)
    } else {
      return .system(size: size, weight: weight, design: .default)
    }
  }
}
