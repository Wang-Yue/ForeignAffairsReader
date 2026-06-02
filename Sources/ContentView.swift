import Foundation
import SwiftUI
import Translation

struct ArticleCardView: View {
  let article: ArticleHeader
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(article.category)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(isSelected ? Color.accentColor : Color.secondary)
            .tracking(1.2)

          Text(article.title)
            .font(.custom("Playfair Display", size: 13))
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

          if !article.byline.isEmpty {
            Text(article.byline)
              .font(.system(size: 10))
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }

        Spacer()

        if !article.image.isEmpty {
          AsyncImage(url: URL(string: article.image)) { phase in
            switch phase {
            case .success(let image):
              image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .cornerRadius(6)
            default:
              RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 50, height: 50)
            }
          }
        }
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 12)
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(
            isSelected
              ? AnyShapeStyle(.tertiary)
              : (isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.clear)))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.easeOut(duration: 0.15)) {
        self.isHovered = hovering
      }
    }
  }
}

struct ContentView: View {
  @State private var model = AppModel()
  @State private var searchInput: String = ""
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @State private var selectedArticleHeader: ArticleHeader?

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      // Left Side: Sidebar
      VStack(spacing: 0) {
        Text("Foreign Affairs")
          .font(.custom("Playfair Display", size: 20))
          .fontWeight(.bold)
          .foregroundColor(.primary)
          .padding(.horizontal, 16)
          .padding(.bottom, 12)

        // Elegant Search Bar
        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundColor(.secondary)
            .font(.system(size: 12))

          TextField(
            model.uiString("Search articles..."), text: $searchInput,
            onCommit: {
              model.searchQuery = searchInput.trimmingCharacters(in: .whitespacesAndNewlines)
              model.fetchArticlesForCurrentSection()
            }
          )
          .textFieldStyle(.plain)
          .font(.system(size: 12))
          .foregroundColor(.primary)

          if !searchInput.isEmpty {
            Button(action: {
              searchInput = ""
              model.searchQuery = ""
              model.fetchArticlesForCurrentSection()
            }) {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.background)
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(.tertiary, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)

        // Article List Scroll Area
        ZStack {
          if model.isListLoading {
            VStack(spacing: 12) {
              ProgressView()
                .controlSize(.small)
              Text(model.uiString("Fetching feed from live site..."))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            .frame(maxHeight: .infinity)
          } else if let listErr = model.listError {
            VStack(spacing: 12) {
              Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
              Text(listErr)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

              Button(model.uiString("Retry")) {
                model.fetchArticlesForCurrentSection()
              }
              .buttonStyle(.bordered)
            }
            .frame(maxHeight: .infinity)
          } else if model.articleList.isEmpty {
            VStack(spacing: 8) {
              Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
              Text(model.uiString("No articles found"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
              Text(model.uiString("Try refining your query."))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(30)
            .frame(maxHeight: .infinity)
          } else {
            ScrollView {
              LazyVStack(spacing: 4) {
                let displayList =
                  (model.selectedLanguage == "en" || model.translatedArticleList.isEmpty)
                  ? model.articleList : model.translatedArticleList
                ForEach(displayList) { articleHeader in
                  ArticleCardView(
                    article: articleHeader,
                    isSelected: model.urlString == articleHeader.url,
                    action: {
                      model.selectArticle(articleHeader)
                      selectedArticleHeader = articleHeader
                    }
                  )
                }
              }
              .padding(.vertical, 10)
              .padding(.horizontal, 12)
            }
          }
        }

        // Bottom Control Bar
        VStack(spacing: 0) {
          Divider()

          HStack(spacing: 12) {
            // Translation Selector Menu
            Menu {
              ForEach(model.languages, id: \.code) { lang in
                Button(action: {
                  model.selectedLanguage = lang.code
                }) {
                  HStack {
                    Text(lang.name)
                    if model.selectedLanguage == lang.code {
                      Spacer()
                      Image(systemName: "checkmark")
                    }
                  }
                }
              }
            } label: {
              HStack(spacing: 6) {
                Image(systemName: "translate")
                  .font(.system(size: 11, weight: .medium))

                Text(
                  model.uiString(
                    model.languages.first(where: { $0.code == model.selectedLanguage })?.name
                      .components(separatedBy: " (").first ?? "Translate")
                )
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                  .font(.system(size: 8))
              }
              .foregroundColor(.primary)
              .padding(.horizontal, 8)
              .padding(.vertical, 6)
              .background(.background)
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(.tertiary, lineWidth: 1)
              )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)

            Spacer()

            // Font Resizing Buttons
            HStack(spacing: 4) {
              Button(action: {
                if model.fontSizeMultiplier > 0.6 {
                  withAnimation(.spring(response: 0.2)) {
                    model.fontSizeMultiplier -= 0.1
                  }
                }
              }) {
                Image(systemName: "textformat.size.smaller")
                  .font(.system(size: 10, weight: .medium))
                  .foregroundColor(.primary)
                  .frame(width: 26, height: 26)
                  .background(.background)
                  .cornerRadius(6)
                  .overlay(
                    RoundedRectangle(cornerRadius: 6)
                      .stroke(.tertiary, lineWidth: 1)
                  )
              }
              .buttonStyle(.plain)
              .help(model.uiString("Decrease Font Size"))

              Button(action: {
                if model.fontSizeMultiplier < 2.0 {
                  withAnimation(.spring(response: 0.2)) {
                    model.fontSizeMultiplier += 0.1
                  }
                }
              }) {
                Image(systemName: "textformat.size.larger")
                  .font(.system(size: 10, weight: .medium))
                  .foregroundColor(.primary)
                  .frame(width: 26, height: 26)
                  .background(.background)
                  .cornerRadius(6)
                  .overlay(
                    RoundedRectangle(cornerRadius: 6)
                      .stroke(.tertiary, lineWidth: 1)
                  )
              }
              .buttonStyle(.plain)
              .help(model.uiString("Increase Font Size"))
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
      }
      .navigationSplitViewColumnWidth(min: 320, ideal: 340, max: 400)
      #if os(iOS)
        .navigationDestination(item: $selectedArticleHeader) { header in
          DetailReaderView(model: model)
          .navigationBarTitleDisplayMode(.inline)
        }
      #endif
    } detail: {
      DetailReaderView(model: model)
        .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity)
        .navigationTitle("")
    }
    .background(
      Color.clear
        .translationTask(model.translationConfig) { session in
          await model.translateContent(using: session)
        }
        .id("\(model.selectedLanguage)-\(model.translationTriggerCount)")
    )
  }
}

struct DetailReaderView: View {
  var model: AppModel

  var body: some View {
    ZStack {
      ReaderView(model: model)

      if model.isLoading {
        VStack(spacing: 15) {
          ProgressView()
            .controlSize(.large)
          Text(
            model.uiString(
              model.selectedLanguage != "en"
                ? "Translating Natively..." : "Preparing Reader Mode...")
          )
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.secondary)
        }
        .padding(30)
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.background)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(.tertiary, lineWidth: 1)
        )
      }

      if let err = model.extractionError {
        VStack {
          Text(err)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(.red)
            )
        }
        .padding(.top, 20)
        .transition(.move(edge: .top))
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.extractionError)
    .background(.background)
  }
}
