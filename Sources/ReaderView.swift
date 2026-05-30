import SwiftUI
import WebKit

struct ReaderView: NSViewRepresentable {
  var model: AppModel

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.customUserAgent =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    // Make WKWebView transparent so the native ReaderTheme background shines through
    webView.setValue(false, forKey: "drawsBackground")

    loadArticleHTML(in: webView, coordinator: context.coordinator)
    return webView
  }

  func updateNSView(_ nsView: WKWebView, context: Context) {
    let activeArticle = model.translatedArticle ?? model.article

    // Check if the article itself changed, or if we need to reload the template
    if context.coordinator.lastArticleId != activeArticle?.title
      || context.coordinator.lastLanguage != model.selectedLanguage
    {
      loadArticleHTML(in: nsView, coordinator: context.coordinator)
    } else {
      // Update settings in real-time
      nsView.evaluateJavaScript("setTheme('\(model.readerTheme.cssClass)')", completionHandler: nil)
      nsView.evaluateJavaScript(
        "setFontSizeMultiplier(\(model.fontSizeMultiplier))", completionHandler: nil)
    }
  }

  private func loadArticleHTML(in webView: WKWebView, coordinator: Coordinator) {
    guard let article = model.translatedArticle ?? model.article else {
      let themeClass = model.readerTheme.cssClass
      let placeholderHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <link rel="preconnect" href="https://fonts.googleapis.com">
            <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
            <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,600;1,400&family=Inter:wght@300;400;500&display=swap" rel="stylesheet">
            <style>
                :root {
                    --bg-color: #fdfbf7;
                    --text-color: #1c1b1a;
                    --accent-color: #9e2a2b;
                    --meta-color: #6f6c66;
                }
                
                body.theme-light {
                    --bg-color: #ffffff;
                    --text-color: #111111;
                    --accent-color: #9e2a2b;
                    --meta-color: #555555;
                }
                
                body.theme-dark {
                    --bg-color: #141414;
                    --text-color: #e0e0e0;
                    --accent-color: #ff7b7b;
                    --meta-color: #a0a0a0;
                }
                
                body.theme-sepia {
                    --bg-color: #f4ecd8;
                    --text-color: #5c4033;
                    --accent-color: #8b0000;
                    --meta-color: #705335;
                }
                
                body {
                    background-color: var(--bg-color);
                    color: var(--text-color);
                    font-family: 'Playfair Display', Georgia, serif;
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    align-items: center;
                    height: 90vh;
                    margin: 0;
                    text-align: center;
                    transition: background-color 0.25s, color 0.25s;
                }
                
                .icon {
                    color: var(--accent-color);
                    font-size: 48px;
                    margin-bottom: 20px;
                    opacity: 0.85;
                    transition: color 0.25s;
                }
                
                h2 {
                    font-weight: 400;
                    font-size: 28px;
                    margin-bottom: 12px;
                    font-style: italic;
                    color: var(--text-color);
                    transition: color 0.25s;
                }
                
                p {
                    font-family: 'Inter', sans-serif;
                    font-size: 14px;
                    font-weight: 300;
                    margin: 0;
                    color: var(--meta-color);
                    letter-spacing: 0.5px;
                    transition: color 0.25s;
                }
            </style>
        </head>
        <body class="theme-\(themeClass)">
            <div class="icon">✦</div>
            <h2>\(model.uiString("Welcome to Foreign Affairs"))</h2>
            <p>\(model.uiString("Select an article from the sidebar to begin reading in premium reader mode."))</p>
            
            <script type="text/javascript">
                function setTheme(theme) {
                    document.body.className = '';
                    document.body.classList.add('theme-' + theme);
                }
            </script>
        </body>
        </html>
        """
      webView.loadHTMLString(placeholderHTML, baseURL: nil)
      return
    }

    // Prepare Featured Image HTML
    let imageDiv =
      article.image.isEmpty
      ? ""
      : """
      <div class="featured-image">
          <img src="\(article.image)" alt="Featured Image">
      </div>
      """

    // Generate HTML body paragraphs dynamically
    var bodyHtml = ""
    for element in article.elements {
      if element.type == "h3" {
        bodyHtml += "<h3>\(element.text)</h3>"
      } else if element.type == "blockquote" {
        bodyHtml += "<blockquote>\(element.text)</blockquote>"
      } else {
        bodyHtml += "<p>\(element.text)</p>"
      }
    }

    let html = getReaderHTML(
      title: article.title,
      subtitle: article.subtitle,
      author: article.byline,
      date: article.date,
      issue: article.issue,
      imageDiv: imageDiv,
      body: bodyHtml,
      theme: model.readerTheme.cssClass,
      fontMultiplier: model.fontSizeMultiplier
    )

    // Base URL must be set to Foreign Affairs so relative resources work correctly
    webView.loadHTMLString(html, baseURL: URL(string: "https://www.foreignaffairs.com"))

    coordinator.lastArticleId = article.title
    coordinator.lastLanguage = model.selectedLanguage
  }

  class Coordinator: NSObject, WKNavigationDelegate {
    var parent: ReaderView
    var lastArticleId: String? = nil
    var lastLanguage: String = "en"

    init(_ parent: ReaderView) {
      self.parent = parent
      self.lastLanguage = parent.model.selectedLanguage
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      // Sync settings immediately after loading completes
      webView.evaluateJavaScript(
        "setTheme('\(parent.model.readerTheme.cssClass)')", completionHandler: nil)
      webView.evaluateJavaScript(
        "setFontSizeMultiplier(\(parent.model.fontSizeMultiplier))", completionHandler: nil)
    }
  }
}

// Helper function for clean formatted template HTML
func getReaderHTML(
  title: String, subtitle: String, author: String, date: String, issue: String, imageDiv: String,
  body: String, theme: String, fontMultiplier: Double
) -> String {
  return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(title)</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&family=Playfair+Display:ital,wght@0,400;0,600;0,700;1,400&display=swap" rel="stylesheet">
        <style>
            :root {
                --bg-color: #fdfbf7;
                --text-color: #1c1b1a;
                --accent-color: #9e2a2b;
                --meta-color: #6f6c66;
                --border-color: #e8e5dd;
                --font-size-multiplier: \(fontMultiplier);
            }
            
            body.theme-light {
                --bg-color: #ffffff;
                --text-color: #111111;
                --accent-color: #9e2a2b;
                --meta-color: #555555;
                --border-color: #eaeaea;
            }
            
            body.theme-dark {
                --bg-color: #141414;
                --text-color: #e0e0e0;
                --accent-color: #ff7b7b;
                --meta-color: #a0a0a0;
                --border-color: #2a2a2a;
            }
            
            body.theme-sepia {
                --bg-color: #f4ecd8;
                --text-color: #5c4033;
                --accent-color: #8b0000;
                --meta-color: #705335;
                --border-color: #e4d9c4;
            }
            
            body {
                background-color: var(--bg-color);
                color: var(--text-color);
                font-family: 'Playfair Display', Georgia, serif;
                line-height: 1.68;
                margin: 0;
                padding: 40px 20px;
                transition: background-color 0.25s, color 0.25s;
                display: flex;
                flex-direction: column;
                align-items: center;
            }
            
            .container {
                max-width: 680px;
                width: 100%;
            }
            
            header {
                border-bottom: 1px solid var(--border-color);
                padding-bottom: 25px;
                margin-bottom: 35px;
            }
            
            .issue {
                font-family: 'Inter', sans-serif;
                font-size: 12px;
                font-weight: 600;
                text-transform: uppercase;
                letter-spacing: 1.5px;
                color: var(--accent-color);
                margin-bottom: 10px;
            }
            
            h1 {
                font-size: calc(36px * var(--font-size-multiplier));
                line-height: 1.2;
                margin: 0 0 15px 0;
                font-weight: 700;
                font-family: 'Playfair Display', Georgia, serif;
            }
            
            .subtitle {
                font-size: calc(19px * var(--font-size-multiplier));
                line-height: 1.4;
                font-style: italic;
                color: var(--meta-color);
                margin-bottom: 20px;
            }
            
            .byline-container {
                font-family: 'Inter', sans-serif;
                font-size: 13px;
                color: var(--meta-color);
                display: flex;
                justify-content: space-between;
                align-items: center;
                flex-wrap: wrap;
                gap: 10px;
            }
            
            .author {
                font-weight: 600;
                color: var(--text-color);
            }
            
            .featured-image {
                margin-bottom: 35px;
                border-radius: 8px;
                overflow: hidden;
                box-shadow: 0 4px 16px rgba(0, 0, 0, 0.06);
                width: 100%;
            }
            .featured-image img {
                width: 100%;
                height: auto;
                display: block;
            }
            
            .article-body {
                font-size: calc(18px * var(--font-size-multiplier));
                font-family: 'Playfair Display', Georgia, serif;
            }
            
            p {
                margin-top: 0;
                margin-bottom: 1.7em;
            }
            
            h3 {
                font-family: 'Inter', sans-serif;
                font-size: calc(21px * var(--font-size-multiplier));
                font-weight: 600;
                margin-top: 45px;
                margin-bottom: 20px;
                color: var(--accent-color);
            }
            
            blockquote {
                font-style: italic;
                border-left: 3px solid var(--accent-color);
                margin: 30px 0;
                padding: 5px 0 5px 20px;
                font-size: calc(22px * var(--font-size-multiplier));
                color: var(--meta-color);
            }
            
            a {
                color: var(--accent-color);
                text-decoration: none;
                border-bottom: 1px solid var(--border-color);
                transition: border-bottom-color 0.2s;
            }
            a:hover {
                border-bottom-color: var(--accent-color);
            }
        </style>
    </head>
    <body class="theme-\(theme)">
        <div class="container">
            <header>
                <div class="issue">\(issue)</div>
                <h1>\(title)</h1>
                <div class="subtitle">\(subtitle)</div>
                <div class="byline-container">
                    <div>By <span class="author">\(author)</span></div>
                    <div>\(date)</div>
                </div>
            </header>
            
            \(imageDiv)
            
            <div class="article-body">
                \(body)
            </div>
        </div>

        <script type="text/javascript">
            function setTheme(theme) {
                document.body.className = '';
                document.body.classList.add('theme-' + theme);
            }
            
            function setFontSizeMultiplier(mult) {
                document.documentElement.style.setProperty('--font-size-multiplier', mult);
            }
        </script>
    </body>
    </html>
    """
}
