import Foundation
import WebKit

@MainActor
class ArticleParser: NSObject, WKNavigationDelegate {
  private var backgroundWebView: WKWebView!
  private var completion: (Result<ArticleData, any Error>) -> Void

  private static var activeParsers = Set<ArticleParser>()

  static func parse(htmlString: String) async throws -> ArticleData {
    let cleanedHTML = stripScriptTags(from: htmlString)
    return try await withCheckedThrowingContinuation { continuation in
      let parser = ArticleParser(htmlString: cleanedHTML) { result in
        continuation.resume(with: result)
      }
      activeParsers.insert(parser)
    }
  }

  private static func stripScriptTags(from html: String) -> String {
    let pattern = "<script[^>]*>[\\s\\S]*?</script>"
    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
      let range = NSRange(html.startIndex..<html.endIndex, in: html)
      return regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "")
    }
    return html
  }

  private init(htmlString: String, completion: @escaping (Result<ArticleData, any Error>) -> Void) {
    self.completion = completion
    super.init()

    let configuration = WKWebViewConfiguration()
    self.backgroundWebView = WKWebView(frame: .zero, configuration: configuration)
    self.backgroundWebView.navigationDelegate = self

    self.backgroundWebView.loadHTMLString(
      htmlString, baseURL: URL(string: "https://www.foreignaffairs.com"))
  }

  // WKNavigationDelegate
  nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    Task { @MainActor in
      do {
        let extractionJS = """
          (function() {
              var title = (document.querySelector('.topper__title')?.textContent || document.querySelector('.topper__title')?.innerText || document.title).trim();
              var subtitle = (document.querySelector('.topper__subtitle')?.textContent || document.querySelector('.topper__subtitle')?.innerText || '').trim();
              var byline = (document.querySelector('.topper__byline')?.textContent || document.querySelector('.topper__byline')?.innerText || document.querySelector('.author-about__description h2')?.textContent || document.querySelector('.author-about__description h2')?.innerText || '').trim();
              var date = (document.querySelector('.topper__date')?.textContent || document.querySelector('.topper__date')?.innerText || '').trim();
              var issue = (document.querySelector('.topper__issue')?.textContent || document.querySelector('.topper__issue')?.innerText || '').trim();
              
              var imgEl = document.querySelector('.topper__image') || document.querySelector('.article__header-image img');
              var imgSrc = '';
              if (imgEl) {
                  if (imgEl.srcset) {
                      var candidates = imgEl.srcset.split(',').map(function(s) {
                          var parts = s.trim().split(/\\s+/);
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
              }
              
              var elements = [];
              function parseNodeList(container) {
                  container.childNodes.forEach(function(node) {
                      if (node.nodeType === 1) {
                          var tag = node.tagName.toLowerCase();
                          if (tag === 'p' || tag === 'h3' || tag === 'blockquote') {
                              var text = (node.textContent || node.innerText || '').trim();
                              if (text.length > 0) {
                                  elements.push({ type: tag, text: text });
                              }
                          } else if (node.childNodes.length > 0) {
                              parseNodeList(node);
                          }
                      }
                  });
              }
              
              var contentContainer = document.querySelector('.paywall-content') || document.querySelector('.article-dropcap--inner');
              if (contentContainer) {
                  parseNodeList(contentContainer);
              } else {
                  var bodyContentEl = document.querySelector('.article__body-content') || document.querySelector('.rich-text__inner');
                  if (bodyContentEl) {
                      parseNodeList(bodyContentEl);
                  }
              }
              
              return JSON.stringify({
                  title: title,
                  subtitle: subtitle,
                  byline: byline,
                  date: date,
                  issue: issue,
                  image: imgSrc,
                  elements: elements
              });
          })();
          """
        guard let resultStr = try await webView.evaluateJavaScript(extractionJS) as? String,
          let data = resultStr.data(using: .utf8)
        else {
          throw NSError(
            domain: "ArticleParser", code: -2,
            userInfo: [NSLocalizedDescriptionKey: "Failed to parse HTML content"])
        }
        let articleData = try JSONDecoder().decode(ArticleData.self, from: data)
        self.completion(.success(articleData))
      } catch {
        self.completion(.failure(error))
      }
      ArticleParser.activeParsers.remove(self)
    }
  }

  nonisolated func webView(
    _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error
  ) {
    Task { @MainActor in
      self.completion(.failure(error))
      ArticleParser.activeParsers.remove(self)
    }
  }

  nonisolated func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: any Error
  ) {
    Task { @MainActor in
      self.completion(.failure(error))
      ArticleParser.activeParsers.remove(self)
    }
  }

  nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    Task { @MainActor in
      let error = NSError(
        domain: "ArticleParser", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Web content process terminated"])
      self.completion(.failure(error))
      ArticleParser.activeParsers.remove(self)
    }
  }
}
