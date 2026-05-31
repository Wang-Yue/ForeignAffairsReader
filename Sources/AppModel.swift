import Foundation
import Observation
@preconcurrency import Translation

enum ReaderTheme: String, CaseIterable, Identifiable, Sendable {
  case light = "Light"
  case sepia = "Sepia"
  case dark = "Dark"

  var id: String { self.rawValue }

  var cssClass: String {
    self.rawValue.lowercased()
  }
}

struct ArticleElement: Codable, Sendable, Hashable {
  let type: String  // "p", "h3", "blockquote"
  let text: String
}

struct ArticleData: Codable, Sendable, Hashable {
  let title: String
  let subtitle: String
  let byline: String
  let date: String
  let issue: String
  let image: String
  let elements: [ArticleElement]
}

@MainActor
@Observable
class AppModel {
  // Active article URL and extraction state
  var urlString: String = ""
  var isLoading: Bool = false
  var article: ArticleData? = nil
  var translatedArticle: ArticleData? = nil
  var extractionError: String? = nil
  var loadedUrl: String? = nil

  // Sidebar states
  var articleList: [ArticleHeader] = []
  var translatedArticleList: [ArticleHeader] = []
  var translatedUI: [String: String] = [:]
  var isListLoading: Bool = false
  var listError: String? = nil
  var searchQuery: String = ""

  // Reader preferences
  var readerTheme: ReaderTheme = .sepia
  var fontSizeMultiplier: Double = 1.0
  var selectedLanguage: String = "en" {
    didSet {
      if selectedLanguage == "en" {
        self.translatedArticle = nil
        self.translatedArticleList = []
        self.translatedUI = [:]
        self.translationConfig = nil
      } else {
        self.translatedArticle = nil
        self.translatedArticleList = []
        self.translatedUI = [:]
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
    "Light Theme",
    "Sepia Theme",
    "Dark Theme",
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
}
