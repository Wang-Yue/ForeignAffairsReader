import Foundation
import Combine
import Translation

enum ActiveTab: String, CaseIterable, Identifiable {
    case browser = "Browser"
    case reader = "Reader Mode"
    
    var id: String { self.rawValue }
}

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
    // Navigation and tabs
    @Published var currentTab: ActiveTab = .browser
    @Published var urlString: String = "https://www.foreignaffairs.com"
    @Published var isLoading: Bool = false
    
    // Extracted Article
    @Published var article: ArticleData? = nil
    @Published var translatedArticle: ArticleData? = nil
    @Published var extractionError: String? = nil
    
    @Published var loadedUrl: String? = nil
    
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
    
    // WebView triggers
    @Published var triggerBack: Bool = false
    @Published var triggerForward: Bool = false
    @Published var triggerReload: Bool = false
    
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
    
    func breakPaywall() {
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
                            self.currentTab = .reader
                        case .failure(let parseError):
                            self.extractionError = "Failed to parse article data: \(parseError.localizedDescription)"
                        }
                    }
                }
            }
        }.resume()
    }
}
