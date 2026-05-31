import Foundation

class ArticleParser {
  static func parse(htmlString: String) async throws -> ArticleData {
    let title = extractMetadata(
      patterns: [
        #"class="[^"]*topper__title[^"]*"[^>]*>([\s\S]*?)</h1>"#,
        #"<title>([\s\S]*?)</title>"#,
      ],
      in: htmlString
    )
    let subtitle = extractMetadata(
      patterns: [#"class="[^"]*topper__subtitle[^"]*"[^>]*>([\s\S]*?)</h2>"#],
      in: htmlString
    )
    let byline = extractMetadata(
      patterns: [#"class="[^"]*topper__byline[^"]*"[^>]*>([\s\S]*?)</h3>"#],
      in: htmlString
    )
    let date = extractMetadata(
      patterns: [#"class="[^"]*topper__date[^"]*"[^>]*>([\s\S]*?)</span>"#],
      in: htmlString
    )
    let issue = extractMetadata(
      patterns: [#"class="[^"]*topper__issue[^"]*"[^>]*>([\s\S]*?)</span>"#],
      in: htmlString
    )
    let image =
      firstMatch(pattern: #"<meta property="og:image" content="([^"]+)"#, in: htmlString) ?? ""

    // Narrow down to body block
    var bodyBlock = ""
    let primaryContainers = ["paywall-content", "article-dropcap--inner"]
    let secondaryContainers = ["article__body-content", "rich-text__inner"]

    for containerClass in primaryContainers {
      if let matched = extractBalancedContainer(html: htmlString, containerClass: containerClass) {
        bodyBlock = matched
        break
      }
    }

    if bodyBlock.isEmpty {
      for containerClass in secondaryContainers {
        if let matched = extractBalancedContainer(html: htmlString, containerClass: containerClass)
        {
          bodyBlock = matched
          break
        }
      }
    }

    if bodyBlock.isEmpty {
      bodyBlock = htmlString
    }

    // Extract elements
    let nsBody = bodyBlock as NSString
    var elements: [ArticleElement] = []
    let elementPattern = #"<(p|h3|blockquote)[^>]*>([\s\S]*?)</\1>"#
    if let regex = try? NSRegularExpression(pattern: elementPattern, options: [.caseInsensitive]) {
      let matches = regex.matches(
        in: bodyBlock, options: [], range: NSRange(location: 0, length: nsBody.length))
      for match in matches {
        if match.numberOfRanges >= 3 {
          let type = nsBody.substring(with: match.range(at: 1)).lowercased()
          let rawContent = nsBody.substring(with: match.range(at: 2))
          let content = decodeHTMLEntities(in: cleanHTMLTags(from: rawContent))
          if !content.isEmpty {
            elements.append(ArticleElement(type: type, text: content))
          }
        }
      }
    }

    return ArticleData(
      title: title,
      subtitle: subtitle,
      byline: byline,
      date: date,
      issue: issue,
      image: image,
      elements: elements
    )
  }

  private static func cleanHTMLTags(from string: String) -> String {
    let pattern = "<[^>]+>"
    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
      let range = NSRange(string.startIndex..<string.endIndex, in: string)
      let cleaned = regex.stringByReplacingMatches(
        in: string, options: [], range: range, withTemplate: "")
      return cleaned
    }
    return string
  }

  private static func decodeHTMLEntities(in string: String) -> String {
    let entities = [
      "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'",
      "&#039;": "'", "&#39;": "'", "&rsquo;": "’", "&lsquo;": "‘",
      "&ldquo;": "“", "&rdquo;": "”", "&mdash;": "—", "&ndash;": "–",
    ]
    var result = string
    for (entity, char) in entities {
      result = result.replacingOccurrences(of: entity, with: char)
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func firstMatch(pattern: String, in text: String) -> String? {
    guard
      let regex = try? NSRegularExpression(
        pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    else { return nil }
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    if let match = regex.firstMatch(in: text, options: [], range: nsRange) {
      if match.numberOfRanges >= 2 {
        let groupRange = match.range(at: 1)
        if let swiftRange = Range(groupRange, in: text) {
          return String(text[swiftRange])
        }
      }
    }
    return nil
  }

  private static func extractMetadata(patterns: [String], in html: String) -> String {
    for pattern in patterns {
      if let match = firstMatch(pattern: pattern, in: html) {
        return decodeHTMLEntities(in: cleanHTMLTags(from: match))
      }
    }
    return ""
  }

  private static func extractBalancedContainer(html: String, containerClass: String) -> String? {
    let nsHtml = html as NSString
    let startPattern = #"<(div|section)[^>]*class="[^"]*\b\#(containerClass)\b[^"]*"[^>]*>"#
    guard
      let regex = try? NSRegularExpression(pattern: startPattern, options: [.caseInsensitive])
    else { return nil }

    guard
      let match = regex.firstMatch(
        in: html, options: [], range: NSRange(location: 0, length: nsHtml.length))
    else { return nil }
    let tagName = nsHtml.substring(with: match.range(at: 1)).lowercased()

    let scanStart = match.range.location + match.range.length
    let remainingRange = NSRange(location: scanStart, length: nsHtml.length - scanStart)

    let tagPattern = #"</?\#(tagName)\b[^>]*>"#
    guard
      let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive])
    else { return nil }

    let matches = tagRegex.matches(in: html, options: [], range: remainingRange)
    var depth = 1

    for tagMatch in matches {
      let tagText = nsHtml.substring(with: tagMatch.range)
      if tagText.hasPrefix("</") {
        depth -= 1
        if depth == 0 {
          let contentLength = tagMatch.range.location - scanStart
          return nsHtml.substring(with: NSRange(location: scanStart, length: contentLength))
        }
      } else {
        depth += 1
      }
    }
    return nil
  }
}
