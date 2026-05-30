import Foundation
import Combine
import Translation

enum ReaderTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case sepia = "Sepia"
    case dark = "Dark"
    
    var id: String { self.rawValue }
    
    var cssClass: String {
        self.rawValue.lowercased()
    }
}

struct ArticleElement: Codable {
    let type: String // "p", "h3", "blockquote"
    let text: String
}

struct ArticleData: Codable {
    let title: String
    let subtitle: String
    let byline: String
    let date: String
    let issue: String
    let image: String
    let elements: [ArticleElement]
}

class AppModel: ObservableObject {
    // Active article URL and extraction state
    @Published var urlString: String = ""
    @Published var isLoading: Bool = false
    @Published var article: ArticleData? = nil
    @Published var translatedArticle: ArticleData? = nil
    @Published var extractionError: String? = nil
    @Published var loadedUrl: String? = nil
    
    // Sidebar states
    @Published var articleList: [ArticleHeader] = []
    @Published var isListLoading: Bool = false
    @Published var listError: String? = nil
    @Published var sidebarSection: String = "Featured" {
        didSet {
            searchQuery = ""
            fetchArticlesForCurrentSection()
        }
    }
    @Published var searchQuery: String = ""
    
    // Reader preferences
    @Published var readerTheme: ReaderTheme = .sepia
    @Published var fontSizeMultiplier: Double = 1.0
    @Published var selectedLanguage: String = "en" {
        didSet {
            if selectedLanguage == "en" {
                self.translatedArticle = nil
                self.translationConfig = nil
            } else {
                self.translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: selectedLanguage)
                )
            }
        }
    }
    
    // Translation trigger configuration
    @Published var translationConfig: TranslationSession.Configuration? = nil
    
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
        ("it", "Italian")
    ]
    
    init() {
        fetchArticlesForCurrentSection()
    }
    
    func fetchArticlesForCurrentSection() {
        let targetUrlString: String
        if !searchQuery.isEmpty {
            targetUrlString = "https://www.foreignaffairs.com/search/\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? searchQuery)"
        } else {
            switch sidebarSection {
            case "Featured":
                targetUrlString = "https://www.foreignaffairs.com"
            case "Latest":
                targetUrlString = "https://www.foreignaffairs.com/search"
            case "Most Read":
                targetUrlString = "https://www.foreignaffairs.com/most-read"
            default:
                targetUrlString = "https://www.foreignaffairs.com"
            }
        }
        
        guard let url = URL(string: targetUrlString) else { return }
        
        DispatchQueue.main.async {
            self.isListLoading = true
            self.listError = nil
        }
        
        ArticleListFetcher.fetch(url: url) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isListLoading = false
                switch result {
                case .success(let list):
                    self.articleList = list
                case .failure(let error):
                    self.listError = "Failed to fetch articles: \(error.localizedDescription)"
                    self.articleList = []
                }
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
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.extractionError = nil
            self.translatedArticle = nil
            self.selectedLanguage = "en"
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.httpShouldHandleCookies = false
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.extractionError = "Network request failed: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.extractionError = "Failed to download article HTML contents."
                }
                return
            }
            
            DispatchQueue.main.async {
                ArticleParser.parse(htmlString: htmlString) { result in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        switch result {
                        case .success(let articleData):
                            self.article = articleData
                            self.loadedUrl = self.urlString
                            self.extractionError = nil
                        case .failure(let parseError):
                            self.extractionError = "Failed to parse article data: \(parseError.localizedDescription)"
                        }
                    }
                }
            }
        }.resume()
    }
}
