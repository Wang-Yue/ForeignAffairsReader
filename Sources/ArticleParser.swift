import Foundation
import WebKit

class ArticleParser: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private var backgroundWebView: WKWebView!
    private var completion: (Result<ArticleData, Error>) -> Void
    
    // Keep a strong reference to the parser while it is running
    private static var activeParsers = Set<ArticleParser>()
    
    static func parse(htmlString: String, completion: @escaping (Result<ArticleData, Error>) -> Void) {
        let parser = ArticleParser(htmlString: htmlString, completion: completion)
        activeParsers.insert(parser)
    }
    
    private init(htmlString: String, completion: @escaping (Result<ArticleData, Error>) -> Void) {
        self.completion = completion
        super.init()
        
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "faParser")
        configuration.userContentController = contentController
        
        self.backgroundWebView = WKWebView(frame: .zero, configuration: configuration)
        self.backgroundWebView.navigationDelegate = self
        
        // Load the raw HTML string with a simulated base URL
        self.backgroundWebView.loadHTMLString(htmlString, baseURL: URL(string: "https://www.foreignaffairs.com"))
    }
    
    // WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let extractionJS = """
        (function() {
            var title = document.querySelector('.topper__title')?.innerText || document.title;
            var subtitle = document.querySelector('.topper__subtitle')?.innerText || '';
            var byline = document.querySelector('.topper__byline')?.innerText || document.querySelector('.author-about__description h2')?.innerText || '';
            var date = document.querySelector('.topper__date')?.innerText || '';
            var issue = document.querySelector('.topper__issue')?.innerText || '';
            
            // Extract Cover Image
            var imgEl = document.querySelector('.topper__image');
            var imgSrc = '';
            if (imgEl) {
                if (imgEl.srcset) {
                    imgSrc = imgEl.srcset.split(',')[0].trim().split(' ')[0];
                } else {
                    imgSrc = imgEl.src || '';
                }
            }
            
            // Extract all structural paragraphs and elements recursively
            var elements = [];
            
            function parseNodeList(container) {
                container.childNodes.forEach(function(node) {
                    if (node.nodeType === 1) { // Element node
                        var tag = node.tagName.toLowerCase();
                        
                        // If it is a paragraph, header, or blockquote
                        if (tag === 'p' || tag === 'h3' || tag === 'blockquote') {
                            var text = node.innerText.trim();
                            if (text.length > 0) {
                                elements.push({ type: tag, text: text });
                            }
                        } else if (node.childNodes.length > 0) {
                            // Recurse for nested structural divisions like figure or div blocks
                            parseNodeList(node);
                        }
                    }
                });
            }
            
            var paywallContent = document.querySelector('.paywall-content') || document.querySelector('.article-dropcap--inner');
            if (paywallContent) {
                parseNodeList(paywallContent);
            } else {
                var bodyContentEl = document.querySelector('.article__body-content') || document.querySelector('.rich-text__inner');
                if (bodyContentEl) {
                    parseNodeList(bodyContentEl);
                }
            }
            
            var result = {
                title: title.trim(),
                subtitle: subtitle.trim(),
                byline: byline.trim(),
                date: date.trim(),
                issue: issue.trim(),
                image: imgSrc,
                elements: elements
            };
            
            window.webkit.messageHandlers.faParser.postMessage(JSON.stringify(result));
        })();
        """
        
        webView.evaluateJavaScript(extractionJS, completionHandler: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.completion(.failure(error))
        ArticleParser.activeParsers.remove(self)
    }
    
    // WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "faParser", let bodyString = message.body as? String {
            if let data = bodyString.data(using: .utf8) {
                do {
                    let articleData = try JSONDecoder().decode(ArticleData.self, from: data)
                    self.completion(.success(articleData))
                } catch {
                    self.completion(.failure(error))
                }
            }
            ArticleParser.activeParsers.remove(self)
        }
    }
}

