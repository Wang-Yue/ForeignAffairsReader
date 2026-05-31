import Foundation
import WebKit

struct ArticleHeader: Identifiable, Codable, Equatable, Sendable {
  var id: String { url }
  let url: String
  let title: String
  let subtitle: String
  let byline: String
  let image: String
  let category: String
}

struct ESHitSource: Codable, Sendable {
  let title: [String]?
  let fa_url: [String]?
  let field_subtitle: [String]?
  let field_display_authors: [String]?
  let fa_node_type_or_subtype: [String]?
  let fa_node_primary_image_url__desktop_1x: [String]?
}

struct ESHit: Codable, Sendable {
  let _source: ESHitSource
}

struct ESHitsContainer: Codable, Sendable {
  let hits: [ESHit]
}

struct ESResponse: Codable, Sendable {
  let hits: ESHitsContainer
}

@MainActor
class ArticleListFetcher: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
  private var backgroundWebView: WKWebView!
  private var completion: (Result<[ArticleHeader], any Error>) -> Void

  // Keep strong references to active fetchers so they don't get deallocated
  private static var activeFetchers = Set<ArticleListFetcher>()

  static func fetch(url: URL) async throws -> [ArticleHeader] {
    // Intercept keyword searches and empty searches (Latest) and query the Elasticsearch API natively
    if url.pathComponents.contains("search") {
      let query = url.lastPathComponent == "search" ? "" : url.lastPathComponent
      return try await fetchNativeSearch(query: query)
    }

    return try await withCheckedThrowingContinuation { continuation in
      let fetcher = ArticleListFetcher(url: url) { result in
        continuation.resume(with: result)
      }
      activeFetchers.insert(fetcher)
    }
  }

  private init(url: URL, completion: @escaping (Result<[ArticleHeader], any Error>) -> Void) {
    self.completion = completion
    super.init()

    let configuration = WKWebViewConfiguration()
    let contentController = WKUserContentController()
    contentController.add(WeakScriptMessageHandler(self), name: "faListParser")
    configuration.userContentController = contentController

    self.backgroundWebView = WKWebView(frame: .zero, configuration: configuration)
    self.backgroundWebView.navigationDelegate = self

    var request = URLRequest(url: url)
    request.setValue(
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      forHTTPHeaderField: "User-Agent")

    self.backgroundWebView.load(request)
  }

  // WKNavigationDelegate
  nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    Task { @MainActor in
      print("ArticleListFetcher: didFinish loading URL: \(webView.url?.absoluteString ?? "nil")")

      let listJS = """
        (function() {
            var maxAttempts = 50; // 5 seconds total (50 * 100ms)
            var attempt = 0;
            
            function tryExtract() {
                var articles = [];
                var seenUrls = new Set();
                var blacklist = new Set([
                    'authors', 'issues', 'subscribe', 'newsletter', 'podcasts', 'reviews', 'tags', 'topics', 
                    'regions', 'search', 'most-read', 'myaccount', 'about-foreign-affairs', 'submissions', 
                    'permissions', 'feedback', 'accessibility-statement', 'sites', 'themes', 'user', 'rss.xml', 
                    'graduateschoolforum', 'subscription', 'terms-use', 'privacy-policy', 'manage-preferences', 
                    'events', 'mediakit', 'staff', 'frequently-asked-questions', 'books-and-reviews', 'magazine',
                    'browse'
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
                    
                    if (urlObj.origin !== window.location.origin) return;
                    
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
                return articles;
            }
            
            function poll() {
                var results = tryExtract();
                attempt++;
                if (results.length > 0 || attempt >= maxAttempts) {
                    window.webkit.messageHandlers.faListParser.postMessage(JSON.stringify(results));
                } else {
                    setTimeout(poll, 100);
                }
            }
            
            poll();
        })();
        """
      do {
        _ = try await webView.evaluateJavaScript(listJS)
      } catch {
        self.completion(.failure(error))
        ArticleListFetcher.activeFetchers.remove(self)
      }
    }
  }

  nonisolated func webView(
    _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error
  ) {
    Task { @MainActor in
      print("ArticleListFetcher: didFail navigation: \(error.localizedDescription)")
      self.completion(.failure(error))
      ArticleListFetcher.activeFetchers.remove(self)
    }
  }

  nonisolated func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: any Error
  ) {
    Task { @MainActor in
      print("ArticleListFetcher: didFailProvisionalNavigation: \(error.localizedDescription)")
      self.completion(.failure(error))
      ArticleListFetcher.activeFetchers.remove(self)
    }
  }

  nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    Task { @MainActor in
      let error = NSError(
        domain: "ArticleListFetcher", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Web content process terminated"])
      self.completion(.failure(error))
      ArticleListFetcher.activeFetchers.remove(self)
    }
  }

  nonisolated func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    Task { @MainActor in
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

  private static func fetchNativeSearch(query: String) async throws -> [ArticleHeader] {
    let url = URL(string: "https://www.foreignaffairs.com/fa-search.php")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      forHTTPHeaderField: "User-Agent")

    let jsonString: String
    if query.isEmpty {
      jsonString = """
        {
          "query": {
            "bool": {
              "must": { "match_all": {} },
              "must_not": [ { "terms": { "fa_node_type_or_subtype": ["Audio", "Issue"] } } ],
              "filter": [
                { "terms": { "search_api_language": ["en", "und"] } },
                { "range": { "fa_normalized_date": { "gte": "1922-09-01T05:00:00.000Z", "lte": "2026-12-31T23:59:59.999Z" } } }
              ]
            }
          },
          "size": 30,
          "from": 0,
          "sort": [ { "fa_normalized_date": "desc" } ]
        }
        """
    } else {
      let escapedQuery = query.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(
        of: "\"", with: "\\\"")
      jsonString = """
        {
          "query": {
            "bool": {
              "must": {
                "function_score": {
                  "query": {
                    "bool": {
                      "should": [
                        { "multi_match": { "query": "\(escapedQuery)", "fields": [], "operator": "and", "type": "phrase_prefix" } },
                        { "multi_match": { "query": "\(escapedQuery)", "fields": [], "operator": "and", "type": "best_fields" } },
                        { "multi_match": { "query": "\(escapedQuery)", "fields": [], "operator": "and", "type": "cross_fields" } }
                      ]
                    }
                  },
                  "score_mode": "max",
                  "boost_mode": "multiply",
                  "functions": [
                    {
                      "script_score": {
                        "script": {
                          "lang": "painless",
                          "inline": "List boost_types = ['Collection', 'Comment', 'Essay', 'Interview', 'Review', 'Roundtable']; double score = _score; if (doc.containsKey('fa_node_type_or_subtype') && !doc['fa_node_type_or_subtype'].empty) { String type = doc['fa_node_type_or_subtype'].value; if (boost_types.contains(type)) { score *= 1.5; } } return score;"
                        }
                      }
                    }
                  ]
                }
              },
              "must_not": [ { "terms": { "fa_node_type_or_subtype": ["Audio", "Issue"] } } ],
              "filter": [
                { "terms": { "search_api_language": ["en", "und"] } },
                { "range": { "fa_normalized_date": { "gte": "1922-09-01T05:00:00.000Z", "lte": "2026-12-31T23:59:59.999Z" } } }
              ]
            }
          },
          "size": 30,
          "from": 0,
          "sort": [ { "_score": "desc" } ]
        }
        """
    }

    guard let data = jsonString.data(using: .utf8) else {
      throw NSError(
        domain: "Search", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid payload encoding"])
    }
    request.httpBody = data

    let (responseData, _) = try await URLSession.shared.data(for: request)
    let decoded = try JSONDecoder().decode(ESResponse.self, from: responseData)
    return decoded.hits.hits.map { hit -> ArticleHeader in
      let src = hit._source
      let title = src.title?.first ?? ""
      let url = src.fa_url?.first ?? ""
      let subtitle = src.field_subtitle?.first ?? ""
      let byline = src.field_display_authors?.joined(separator: ", ") ?? ""
      let image = src.fa_node_primary_image_url__desktop_1x?.first ?? ""
      let category = src.fa_node_type_or_subtype?.first?.uppercased() ?? ""
      return ArticleHeader(
        url: url, title: title, subtitle: subtitle, byline: byline, image: image, category: category
      )
    }
  }
}
