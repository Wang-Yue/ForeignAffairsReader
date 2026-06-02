import Foundation
import Observation
import Translation

struct ArticleHeader: Identifiable, Codable, Hashable, Equatable, Sendable {
  var id: String { url }
  let url: String
  var title: String
  var subtitle: String
  var byline: String
  var image: String
  var category: String
}

struct ArticleElement: Codable, Sendable, Hashable {
  let type: String  // "p", "h3", "blockquote"
  var text: String
}

struct ArticleData: Codable, Sendable, Hashable {
  var title: String
  var subtitle: String
  var byline: String
  var date: String
  var issue: String
  var image: String
  var elements: [ArticleElement]
}

@MainActor
@Observable
class AppModel {
  // Active article URL and extraction state
  var urlString: String = ""
  var isLoading: Bool = false
  var article: ArticleData? = nil
  var translatedArticle: ArticleData? = nil
  var extractionError: String? = nil {
    didSet {
      if extractionError != nil {
        Task {
          try? await Task.sleep(for: .seconds(5))
          if self.extractionError != nil {
            self.extractionError = nil
          }
        }
      }
    }
  }
  var loadedUrl: String? = nil

  // Sidebar states
  var articleList: [ArticleHeader] = []
  var translatedArticleList: [ArticleHeader] = []
  var translatedUI: [String: String] = [:]
  var isListLoading: Bool = false
  var listError: String? = nil
  var searchQuery: String = ""

  // Reader preferences
  var fontSizeMultiplier: Double = 1.0
  var selectedLanguage: String = "en" {
    didSet {
      self.translatedArticle = nil
      self.translatedArticleList = []
      self.translatedUI = [:]

      if selectedLanguage == "en" {
        self.translationConfig = nil
      } else {
        self.translationConfig = TranslationSession.Configuration(
          source: Locale.Language(identifier: "en"),
          target: Locale.Language(identifier: selectedLanguage)
        )
        self.translationTriggerCount += 1
      }
    }
  }

  // Translation trigger configuration
  var translationConfig: TranslationSession.Configuration? = nil
  var translationTriggerCount: Int = 0

  // Available translation languages (Language Code, Display Name)
  let languages: [(code: String, name: String)] = [
    ("en", "English (Original)"),
    ("zh-CN", "Chinese (Simplified)"),
    ("zh-TW", "Chinese (Traditional)"),
    ("es", "Spanish"),
    ("fr", "French"),
    ("de", "German"),
    ("ja", "Japanese"),
    ("ko", "Korean"),
    ("ru", "Russian"),
    ("ar", "Arabic"),
    ("pt", "Portuguese"),
    ("it", "Italian"),
  ]

  // Available UI strings to translate dynamically
  let uiStringsToTranslate = [
    "Search articles...",
    "Fetching feed from live site...",
    "No articles found",
    "Try refining your query.",
    "Retry",
    "Translating Natively...",
    "Preparing Reader Mode...",
    "Translate",
    "Decrease Font Size",
    "Increase Font Size",

    "Welcome to Foreign Affairs",
    "Select an article from the sidebar to begin reading in premium reader mode.",
  ]

  init() {
    fetchArticlesForCurrentSection()
  }

  func uiString(_ string: String) -> String {
    if selectedLanguage == "en" {
      return string
    }
    return translatedUI[string] ?? string
  }

  func triggerTranslationUpdate() {
    guard selectedLanguage != "en" else { return }
    translationTriggerCount += 1
  }

  func fetchArticlesForCurrentSection() {
    self.isListLoading = true
    self.listError = nil

    Task {
      do {
        let list: [ArticleHeader]
        if !searchQuery.isEmpty {
          list = try await ArticleSearchFetcher.search(query: searchQuery)
        } else {
          list = try await ArticleListFetcher.fetch()
        }
        self.articleList = list
        self.isListLoading = false
        if self.selectedLanguage != "en" {
          self.triggerTranslationUpdate()
        }
      } catch {
        self.listError = "Failed to fetch articles: \(error.localizedDescription)"
        self.articleList = []
        self.isListLoading = false
      }
    }
  }

  func selectArticle(_ header: ArticleHeader) {
    self.urlString = header.url
    self.extractReaderArticle()
  }

  func extractReaderArticle() {
    guard let url = URL(string: urlString) else {
      self.extractionError = "Invalid URL string"
      return
    }

    self.isLoading = true
    self.extractionError = nil
    self.translatedArticle = nil

    Task {
      do {
        var request = URLRequest(url: url)
        request.setValue(
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.httpShouldHandleCookies = false

        let (responseData, _) = try await URLSession.shared.data(for: request)
        guard let htmlString = String(data: responseData, encoding: .utf8) else {
          throw NSError(
            domain: "AppModel", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to download article HTML contents."])
        }

        let articleData = try await ArticleParser.parse(htmlString: htmlString)
        self.article = articleData
        self.loadedUrl = self.urlString
        self.extractionError = nil
        self.isLoading = false
        if self.selectedLanguage != "en" {
          self.triggerTranslationUpdate()
        }
      } catch {
        self.extractionError = "Failed to retrieve or parse article: \(error.localizedDescription)"
        self.isLoading = false
      }
    }
  }

  func translateContent(using session: TranslationSession) async {
    guard selectedLanguage != "en", translationConfig != nil else { return }

    isLoading = true
    extractionError = nil

    do {
      // 1. Stream UI Strings (only if not already translated)
      if translatedUI.isEmpty {
        for originalString in uiStringsToTranslate {
          translatedUI[originalString] = originalString
        }

        let uiRequests =
          uiStringsToTranslate
          .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
          .map { TranslationSession.Request(sourceText: $0, clientIdentifier: $0) }

        if !uiRequests.isEmpty {
          if Task.isCancelled { return }
          let responses = session.translate(batch: uiRequests)
          for try await response in responses {
            if Task.isCancelled { return }
            if let key = response.clientIdentifier {
              translatedUI[key] = response.targetText
            }
          }
        }
      }

      // 2. Stream Article List (only if not already translated)
      let isListAlreadyTranslated = {
        guard translatedArticleList.count == articleList.count else {
          return false
        }
        return zip(translatedArticleList, articleList).allSatisfy {
          $0.0.url == $0.1.url && !$0.0.title.isEmpty && $0.0.title != $0.1.title
        }
      }()

      if !isListAlreadyTranslated {
        translatedArticleList = articleList

        var listRequests: [TranslationSession.Request] = []
        for (index, header) in articleList.enumerated() {
          let fields = [header.title, header.subtitle, header.byline, header.category]
          for (fIdx, text) in fields.enumerated()
          where fIdx != 2 && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            listRequests.append(
              TranslationSession.Request(sourceText: text, clientIdentifier: "\(index)-\(fIdx)"))
          }
        }

        if !listRequests.isEmpty {
          if Task.isCancelled { return }
          let responses = session.translate(batch: listRequests)

          var tempHeaders = articleList
          for try await response in responses {
            if Task.isCancelled { return }
            guard let identifier = response.clientIdentifier else { continue }
            let parts = identifier.split(separator: "-")
            guard parts.count == 2,
              let hIdx = Int(parts[0]),
              let fIdx = Int(parts[1])
            else { continue }

            let transText = response.targetText

            switch fIdx {
            case 0: tempHeaders[hIdx].title = transText
            case 1: tempHeaders[hIdx].subtitle = transText
            case 2: tempHeaders[hIdx].byline = transText
            case 3: tempHeaders[hIdx].category = transText
            default: break
            }

            translatedArticleList = tempHeaders
          }
        }
      }

      // 3. Stream Active Article (if any)
      if let article = article {
        var currentTranslated = article
        translatedArticle = currentTranslated
        isLoading = false

        var articleRequests: [TranslationSession.Request] = []

        // A. Topper Fields
        let topperFields = [
          (article.title, 0),
          (article.subtitle, 1),
          (article.byline, 2),
          (article.date, 3),
          (article.issue, 4),
        ]
        for (text, type) in topperFields
        where type != 2 && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          articleRequests.append(
            TranslationSession.Request(sourceText: text, clientIdentifier: "topper-\(type)"))
        }

        // B. Elements (Paragraphs)
        for (index, element) in article.elements.enumerated()
        where !element.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          articleRequests.append(
            TranslationSession.Request(
              sourceText: element.text, clientIdentifier: "element-\(index)"))
        }

        if !articleRequests.isEmpty {
          if Task.isCancelled { return }
          let responses = session.translate(batch: articleRequests)

          for try await response in responses {
            if Task.isCancelled { return }
            guard let identifier = response.clientIdentifier else { continue }
            let transText = response.targetText

            if identifier.hasPrefix("topper-") {
              let typeString = identifier.replacingOccurrences(of: "topper-", with: "")
              guard let type = Int(typeString) else { continue }
              switch type {
              case 0: currentTranslated.title = transText
              case 1: currentTranslated.subtitle = transText
              case 2: currentTranslated.byline = transText
              case 3: currentTranslated.date = transText
              case 4: currentTranslated.issue = transText
              default: break
              }
            } else if identifier.hasPrefix("element-") {
              let indexString = identifier.replacingOccurrences(of: "element-", with: "")
              guard let index = Int(indexString), index < currentTranslated.elements.count else {
                continue
              }
              currentTranslated.elements[index].text = transText
            }

            translatedArticle = currentTranslated
          }
        }
      } else {
        translatedArticle = nil
        isLoading = false
      }
    } catch {
      guard !Task.isCancelled else { return }
      isLoading = false
      extractionError =
        "Native Apple Translation failed: \(error.localizedDescription)"
      selectedLanguage = "en"
    }
  }
}
