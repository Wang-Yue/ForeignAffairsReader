import Foundation
import WebKit

struct ArticleHeader: Identifiable, Codable, Equatable {
    var id: String { url }
    let url: String
    let title: String
    let subtitle: String
    let byline: String
    let image: String
    let category: String
}

class ArticleListFetcher: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private var backgroundWebView: WKWebView!
    private var completion: (Result<[ArticleHeader], Error>) -> Void
    
    // Keep strong references to active fetchers so they don't get deallocated
    private static var activeFetchers = Set<ArticleListFetcher>()
    
    static func fetch(url: URL, completion: @escaping (Result<[ArticleHeader], Error>) -> Void) {
        let fetcher = ArticleListFetcher(url: url, completion: completion)
        activeFetchers.insert(fetcher)
    }
    
    private init(url: URL, completion: @escaping (Result<[ArticleHeader], Error>) -> Void) {
        self.completion = completion
        super.init()
        
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(WeakScriptMessageHandler(self), name: "faListParser")
        configuration.userContentController = contentController
        
        self.backgroundWebView = WKWebView(frame: .zero, configuration: configuration)
        self.backgroundWebView.navigationDelegate = self
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        self.backgroundWebView.load(request)
    }
    
    deinit {
        backgroundWebView?.configuration.userContentController.removeScriptMessageHandler(forName: "faListParser")
    }
    
    // WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let listJS = """
        (function() {
            var articles = [];
            var seenUrls = new Set();
            var blacklist = new Set([
                'authors', 'issues', 'subscribe', 'newsletter', 'podcasts', 'reviews', 'tags', 'topics', 
                'regions', 'search', 'most-read', 'myaccount', 'about-foreign-affairs', 'submissions', 
                'permissions', 'feedback', 'accessibility-statement', 'sites', 'themes', 'user', 'rss.xml', 
                'graduateschoolforum', 'subscription', 'terms-use', 'privacy-policy', 'manage-preferences', 
                'events', 'mediakit', 'staff', 'frequently-asked-questions', 'books-and-reviews', 'magazine'
            ]);

            var anchors = document.querySelectorAll('a[href]');
            anchors.forEach(function(a) {
                var href = a.getAttribute('href');
                if (!href) return;
                
                var urlObj;
                try {
                    urlObj = new URL(href, window.location.origin);
                } catch(e) {
                    return;
                }
                
                var pathname = urlObj.pathname;
                var segments = pathname.split('/').filter(Boolean);
                
                if (segments.length !== 2) return;
                
                var category = segments[0];
                var slug = segments[1];
                
                if (blacklist.has(category.toLowerCase())) return;
                
                var absoluteUrl = urlObj.origin + pathname;
                if (seenUrls.has(absoluteUrl)) return;
                
                var title = a.innerText.trim();
                if (title.length < 5) return;
                
                var container = a.closest('.card, [data-armstrong-id^="grid"], .col-12, .col-lg-6, .col-lg-5, article, li');
                var subtitle = '';
                var byline = '';
                var imgSrc = '';
                
                if (container) {
                    var subtitleEl = container.querySelector('.body-s.c-text-secondary, .body-l.c-text, .card__deck, h3.body-l');
                    if (subtitleEl && subtitleEl !== a.parentNode) {
                        subtitle = subtitleEl.innerText.trim();
                    }
                    
                    var authorLinks = container.querySelectorAll('a[href^="/authors/"]');
                    if (authorLinks.length > 0) {
                        var authors = [];
                        authorLinks.forEach(function(auth) {
                            authors.push(auth.innerText.trim());
                        });
                        byline = authors.join(', ');
                    } else {
                        var metaParagraphs = container.querySelectorAll('p.body-s, .body-s');
                        metaParagraphs.forEach(function(p) {
                            var text = p.innerText.trim();
                            if (text && text !== subtitle && !text.includes(title) && text.length < 100) {
                                byline = text;
                            }
                        });
                    }
                    
                    var imgEl = container.querySelector('img');
                    if (imgEl) {
                        if (imgEl.dataset.src) {
                            imgSrc = imgEl.dataset.src;
                        } else if (imgEl.srcset) {
                            var candidates = imgEl.srcset.split(',').map(function(s) {
                                var parts = s.trim().split(/\\\\s+/);
                                var url = parts[0];
                                var descriptor = parts[1] || '';
                                var width = 0;
                                if (descriptor.endsWith('w')) {
                                    width = parseInt(descriptor.slice(0, -1), 10) || 0;
                                } else if (descriptor.endsWith('x')) {
                                    width = parseFloat(descriptor.slice(0, -1)) * 1000 || 0;
                                }
                                return { url: url, width: width };
                            });
                            if (candidates.length > 0) {
                                candidates.sort(function(a, b) { return b.width - a.width; });
                                imgSrc = candidates[0].url;
                            }
                        }
                        if (!imgSrc) {
                            imgSrc = imgEl.src || '';
                        }
                        if (imgSrc.startsWith('data:')) {
                            imgSrc = '';
                        }
                    }
                }
                
                var displayCategory = category.replace(/-/g, ' ').toUpperCase();
                
                seenUrls.add(absoluteUrl);
                articles.push({
                    url: absoluteUrl,
                    title: title,
                    subtitle: subtitle,
                    byline: byline,
                    image: imgSrc,
                    category: displayCategory
                });
            });
            
            window.webkit.messageHandlers.faListParser.postMessage(JSON.stringify(articles));
        })();
        """
        webView.evaluateJavaScript(listJS) { [weak self] result, error in
            if let error = error {
                self?.completion(.failure(error))
                if let self = self {
                    ArticleListFetcher.activeFetchers.remove(self)
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.completion(.failure(error))
        ArticleListFetcher.activeFetchers.remove(self)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.completion(.failure(error))
        ArticleListFetcher.activeFetchers.remove(self)
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let error = NSError(domain: "ArticleListFetcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "Web content process terminated"])
        self.completion(.failure(error))
        ArticleListFetcher.activeFetchers.remove(self)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "faListParser", let bodyString = message.body as? String {
            if let data = bodyString.data(using: .utf8) {
                do {
                    let list = try JSONDecoder().decode([ArticleHeader].self, from: data)
                    self.completion(.success(list))
                } catch {
                    self.completion(.failure(error))
                }
            }
            ArticleListFetcher.activeFetchers.remove(self)
        }
    }
}
