import Foundation
import SwiftUI
@preconcurrency import Translation

struct ArticleCardView: View {
  let article: ArticleHeader
  let isSelected: Bool
  let theme: ReaderTheme
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(article.category)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(isSelected ? theme.accentColor : theme.secondaryTextColor)
            .tracking(1.2)

          Text(article.title)
            .font(.custom("Playfair Display", size: 13))
            .fontWeight(.semibold)
            .foregroundColor(theme.primaryTextColor)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

          if !article.byline.isEmpty {
            Text(article.byline)
              .font(.system(size: 10))
              .foregroundColor(theme.secondaryTextColor)
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
              theme.secondaryTextColor.opacity(0.1)
                .frame(width: 50, height: 50)
                .cornerRadius(6)
            }
          }
        }
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 12)
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(theme.cardBackgroundColor(isSelected: isSelected, isHovered: isHovered))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isSelected ? theme.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
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
  @State private var isFullScreen = false
  @State private var selectedArticleHeader: ArticleHeader?

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      // Left Side: Sidebar
      VStack(spacing: 0) {
        Text("Foreign Affairs")
          .font(.custom("Playfair Display", size: 20))
          .fontWeight(.bold)
          .foregroundColor(model.readerTheme.primaryTextColor)
          .padding(.horizontal, 16)
          .padding(.bottom, 12)

        // Elegant Search Bar
        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundColor(model.readerTheme.secondaryTextColor)
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
          .foregroundColor(model.readerTheme.primaryTextColor)

          if !searchInput.isEmpty {
            Button(action: {
              searchInput = ""
              model.searchQuery = ""
              model.fetchArticlesForCurrentSection()
            }) {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(model.readerTheme.secondaryTextColor)
                .font(.system(size: 12))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(model.readerTheme.controlBackgroundColor)
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(model.readerTheme.borderColor, lineWidth: 1)
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
                .foregroundColor(model.readerTheme.secondaryTextColor)
            }
            .frame(maxHeight: .infinity)
          } else if let listErr = model.listError {
            VStack(spacing: 12) {
              Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(model.readerTheme.accentColor)
              Text(listErr)
                .font(.system(size: 11))
                .foregroundColor(model.readerTheme.secondaryTextColor)
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
                .foregroundColor(model.readerTheme.secondaryTextColor)
              Text(model.uiString("No articles found"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(model.readerTheme.primaryTextColor)
              Text(model.uiString("Try refining your query."))
                .font(.system(size: 10))
                .foregroundColor(model.readerTheme.secondaryTextColor)
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
                    theme: model.readerTheme,
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
          Rectangle()
            .fill(model.readerTheme.borderColor)
            .frame(height: 1)

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
              .foregroundColor(model.readerTheme.primaryTextColor)
              .padding(.horizontal, 8)
              .padding(.vertical, 6)
              .background(model.readerTheme.controlBackgroundColor)
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(model.readerTheme.borderColor, lineWidth: 1)
              )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)

            Spacer()

            // Theme Selector Circles
            HStack(spacing: 8) {
              ForEach(ReaderTheme.allCases) { theme in
                Button(action: {
                  withAnimation(.easeInOut(duration: 0.2)) {
                    model.readerTheme = theme
                  }
                }) {
                  Circle()
                    .fill(theme.backgroundColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                      Circle()
                        .stroke(
                          model.readerTheme == theme
                            ? model.readerTheme.accentColor : model.readerTheme.borderColor,
                          lineWidth: model.readerTheme == theme ? 2 : 1)
                    )
                    .shadow(
                      color: Color.black.opacity(model.readerTheme == theme ? 0.15 : 0.05),
                      radius: 1, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .help(model.uiString("\(theme.rawValue) Theme"))
              }
            }

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
                  .foregroundColor(model.readerTheme.primaryTextColor)
                  .frame(width: 26, height: 26)
                  .background(model.readerTheme.controlBackgroundColor)
                  .cornerRadius(6)
                  .overlay(
                    RoundedRectangle(cornerRadius: 6)
                      .stroke(model.readerTheme.borderColor, lineWidth: 1)
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
                  .foregroundColor(model.readerTheme.primaryTextColor)
                  .frame(width: 26, height: 26)
                  .background(model.readerTheme.controlBackgroundColor)
                  .cornerRadius(6)
                  .overlay(
                    RoundedRectangle(cornerRadius: 6)
                      .stroke(model.readerTheme.borderColor, lineWidth: 1)
                  )
              }
              .buttonStyle(.plain)
              .help(model.uiString("Increase Font Size"))
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(model.readerTheme.sidebarBackgroundColor)
        }
      }
      .background(model.readerTheme.sidebarBackgroundColor)
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
          await translateContent(session: session)
        }
        .id("\(model.selectedLanguage)-\(model.translationTriggerCount)")
    )
    #if os(macOS)
      .frame(minWidth: 850, minHeight: 600)
      .toolbar(isFullScreen ? .hidden : .automatic, for: .windowToolbar)
      .onReceive(
        NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)
      ) { _ in
        isFullScreen = true
      }
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification))
      {
        _ in
        isFullScreen = false
      }
    #endif
  }

  private func translateContent(session: TranslationSession) async {
    guard model.selectedLanguage != "en", model.translationConfig != nil else { return }

    model.isLoading = true
    model.extractionError = nil

    do {
      // 1. Stream UI Strings (only if not already translated)
      if model.translatedUI.isEmpty {
        for originalString in model.uiStringsToTranslate {
          model.translatedUI[originalString] = originalString
        }

        var uiRequests: [TranslationSession.Request] = []
        for originalString in model.uiStringsToTranslate {
          let trimmed = originalString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          if !trimmed.isEmpty {
            uiRequests.append(
              TranslationSession.Request(
                sourceText: originalString, clientIdentifier: originalString))
          }
        }

        if !uiRequests.isEmpty {
          if Task.isCancelled { return }
          let responses = session.translate(batch: uiRequests)
          for try await response in responses {
            if Task.isCancelled { return }
            if let key = response.clientIdentifier {
              model.translatedUI[key] = response.targetText
            }
          }
        }
      }

      // 2. Stream Article List (only if not already translated)
      let isListAlreadyTranslated = {
        guard model.translatedArticleList.count == model.articleList.count else {
          return false
        }
        return zip(model.translatedArticleList, model.articleList).allSatisfy {
          $0.0.url == $0.1.url && !$0.0.title.isEmpty && $0.0.title != $0.1.title
        }
      }()

      if !isListAlreadyTranslated {
        model.translatedArticleList = model.articleList

        var listRequests: [TranslationSession.Request] = []
        let headers = model.articleList

        for index in headers.indices {
          let header = headers[index]
          let fields = [header.title, header.subtitle, header.byline, header.category]

          for (fIdx, text) in fields.enumerated() {
            if fIdx == 2 { continue }  // Never translate byline
            let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !trimmed.isEmpty {
              let identifier = "\(index)-\(fIdx)"
              listRequests.append(
                TranslationSession.Request(sourceText: text, clientIdentifier: identifier))
            }
          }
        }

        if !listRequests.isEmpty {
          if Task.isCancelled { return }
          let responses = session.translate(batch: listRequests)

          var tempHeaders = headers
          for try await response in responses {
            if Task.isCancelled { return }
            guard let identifier = response.clientIdentifier else { continue }
            let parts = identifier.split(separator: "-")
            guard parts.count == 2,
              let hIdx = Int(parts[0]),
              let fIdx = Int(parts[1])
            else { continue }

            let transText = response.targetText
            let header = tempHeaders[hIdx]

            switch fIdx {
            case 0:
              tempHeaders[hIdx] = ArticleHeader(
                url: header.url, title: transText, subtitle: header.subtitle, byline: header.byline,
                image: header.image, category: header.category)
            case 1:
              tempHeaders[hIdx] = ArticleHeader(
                url: header.url, title: header.title, subtitle: transText, byline: header.byline,
                image: header.image, category: header.category)
            case 2:
              tempHeaders[hIdx] = ArticleHeader(
                url: header.url, title: header.title, subtitle: header.subtitle, byline: transText,
                image: header.image, category: header.category)
            case 3:
              tempHeaders[hIdx] = ArticleHeader(
                url: header.url, title: header.title, subtitle: header.subtitle,
                byline: header.byline, image: header.image, category: transText)
            default:
              break
            }

            model.translatedArticleList = tempHeaders
          }
        }
      }

      // 3. Stream Active Article (if any)
      if let article = model.article {
        var currentTranslated = ArticleData(
          title: article.title,
          subtitle: article.subtitle,
          byline: article.byline,
          date: article.date,
          issue: article.issue,
          image: article.image,
          elements: article.elements
        )
        model.translatedArticle = currentTranslated
        model.isLoading = false

        var articleRequests: [TranslationSession.Request] = []

        // A. Topper Fields
        let topperFields = [
          (article.title, 0),
          (article.subtitle, 1),
          (article.byline, 2),
          (article.date, 3),
          (article.issue, 4),
        ]
        for (text, type) in topperFields {
          if type == 2 { continue }  // Never translate byline
          let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          if !trimmed.isEmpty {
            let identifier = "topper-\(type)"
            articleRequests.append(
              TranslationSession.Request(sourceText: text, clientIdentifier: identifier))
          }
        }

        // B. Elements (Paragraphs)
        for index in article.elements.indices {
          let element = article.elements[index]
          let trimmed = element.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          if !trimmed.isEmpty {
            let identifier = "element-\(index)"
            articleRequests.append(
              TranslationSession.Request(sourceText: element.text, clientIdentifier: identifier))
          }
        }

        if !articleRequests.isEmpty {
          if Task.isCancelled { return }
          let responses = session.translate(batch: articleRequests)

          var transTitle = article.title
          var transSubtitle = article.subtitle
          var transByline = article.byline
          var transDate = article.date
          var transIssue = article.issue
          var transElements = article.elements

          for try await response in responses {
            if Task.isCancelled { return }
            guard let identifier = response.clientIdentifier else { continue }
            let transText = response.targetText

            if identifier.hasPrefix("topper-") {
              let typeString = identifier.replacingOccurrences(of: "topper-", with: "")
              guard let type = Int(typeString) else { continue }
              switch type {
              case 0: transTitle = transText
              case 1: transSubtitle = transText
              case 2: transByline = transText
              case 3: transDate = transText
              case 4: transIssue = transText
              default: break
              }
            } else if identifier.hasPrefix("element-") {
              let indexString = identifier.replacingOccurrences(of: "element-", with: "")
              guard let index = Int(indexString), index < transElements.count else { continue }
              transElements[index] = ArticleElement(
                type: article.elements[index].type, text: transText)
            }

            currentTranslated = ArticleData(
              title: transTitle,
              subtitle: transSubtitle,
              byline: transByline,
              date: transDate,
              issue: transIssue,
              image: article.image,
              elements: transElements
            )

            model.translatedArticle = currentTranslated
          }
        }
      } else {
        model.translatedArticle = nil
        model.isLoading = false
      }
    } catch {
      guard !Task.isCancelled else { return }
      model.isLoading = false
      model.extractionError =
        "Native Apple Translation failed: \(error.localizedDescription)"
      model.selectedLanguage = "en"
    }
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
          .foregroundColor(model.readerTheme.secondaryTextColor)
        }
        .padding(30)
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(model.readerTheme.controlBackgroundColor)
            .shadow(
              color: Color.black.opacity(model.readerTheme == .dark ? 0.4 : 0.08), radius: 15)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(model.readerTheme.borderColor, lineWidth: 1)
        )
      }

      if let err = model.extractionError {
        VStack {
          Text(err)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(model.readerTheme == .dark ? .black : .white)
            .multilineTextAlignment(.center)
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(model.readerTheme.accentColor)
            )
        }
        .padding(.top, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.extractionError)
    .background(model.readerTheme.backgroundColor)
  }
}
