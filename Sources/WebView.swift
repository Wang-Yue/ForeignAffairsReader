import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    @ObservedObject var model: AppModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Setup message handler for communication from JS to Swift
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "faReader")
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Custom user-agent to mimic modern desktop Safari/Chrome browser
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        // Load initial URL
        if let url = URL(string: model.urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        context.coordinator.observeURL(webView: webView)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Handle navigation controls
        if model.triggerBack {
            if nsView.canGoBack {
                nsView.goBack()
            }
            DispatchQueue.main.async { model.triggerBack = false }
        }
        
        if model.triggerForward {
            if nsView.canGoForward {
                nsView.goForward()
            }
            DispatchQueue.main.async { model.triggerForward = false }
        }
        
        if model.triggerReload {
            nsView.reload()
            DispatchQueue.main.async { model.triggerReload = false }
        }
        
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        var urlObservation: NSKeyValueObservation?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        deinit {
            urlObservation?.invalidate()
        }
        
        func observeURL(webView: WKWebView) {
            urlObservation = webView.observe(\.url, options: .new) { [weak self] webView, change in
                guard let self = self, let newURL = change.newValue as? URL else { return }
                DispatchQueue.main.async {
                    self.parent.model.urlString = newURL.absoluteString
                }
            }
        }
        
        // Receive messages from Javascript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "faReader", let bodyString = message.body as? String {
                if let data = bodyString.data(using: .utf8) {
                    do {
                        let articleData = try JSONDecoder().decode(ArticleData.self, from: data)
                        DispatchQueue.main.async {
                            self.parent.model.article = articleData
                            self.parent.model.extractionError = nil
                            self.parent.model.currentTab = .reader
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.parent.model.extractionError = "Failed to parse extracted article: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
        
        // WKNavigationDelegate methods
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.model.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.model.isLoading = false
                if let url = webView.url {
                    self.parent.model.urlString = url.absoluteString
                }
            }
            
            // Run a script in-place to bypass paywall CSS blockages automatically
            runInPlaceBypass(on: webView)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.model.isLoading = false
            }
        }
        
        // Unblocks scrolling and styling in-place on the live site
        private func runInPlaceBypass(on webView: WKWebView) {
            let inPlaceJS = """
            (function() {
                // Remove paywall overlays and blockers
                var selectorsToHide = [
                    '.paywall',
                    '.paywall-free-article',
                    '.newsletter-backdrop',
                    '.messages--container',
                    '.inline-newsletter-sign-up',
                    '.article-newsletter-signup--container'
                ];
                selectorsToHide.forEach(function(sel) {
                    document.querySelectorAll(sel).forEach(function(el) {
                        el.style.display = 'none';
                        el.remove();
                    });
                });
                
                // Unhide content body if container is height-limited or overflow blocked
                var paywallContent = document.querySelector('.paywall-content');
                if (paywallContent) {
                    paywallContent.style.maxHeight = 'none';
                    paywallContent.style.height = 'auto';
                    paywallContent.style.overflow = 'visible';
                    paywallContent.style.opacity = '1';
                }
                
                // Enable scrollability
                document.body.style.overflow = 'auto';
                document.body.style.position = 'static';
                document.documentElement.style.overflow = 'auto';
            })();
            """
            webView.evaluateJavaScript(inPlaceJS, completionHandler: nil)
        }
        
        // Extracts article full text and posts it back to Swift
        func runExtractionScript(on webView: WKWebView) {
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
                
                window.webkit.messageHandlers.faReader.postMessage(JSON.stringify(result));
            })();
            """
            
            webView.evaluateJavaScript(extractionJS) { result, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.parent.model.extractionError = "Extraction script error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
