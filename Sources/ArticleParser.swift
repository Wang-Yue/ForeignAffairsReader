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
    let containers = [
      "paywall-content", "article-dropcap--inner",
      "article__body-content", "rich-text__inner",
    ]

    for containerClass in containers {
      if let matched = extractBalancedContainer(html: htmlString, containerClass: containerClass) {
        bodyBlock = matched
        break
      }
    }

    if bodyBlock.isEmpty {
      bodyBlock = htmlString
    }

    // Extract elements
    var elements: [ArticleElement] = []
    let elementPattern = #"<(p|h3|blockquote)[^>]*>([\s\S]*?)</\1>"#
    if let regex = try? Regex(elementPattern).ignoresCase() {
      for match in bodyBlock.matches(of: regex) {
        if match.count >= 3,
          let typeRange = match[1].range,
          let contentRange = match[2].range
        {
          let type = String(bodyBlock[typeRange]).lowercased()
          let rawContent = String(bodyBlock[contentRange])
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
    guard let regex = try? Regex(#"<[^>]+>"#) else { return string }
    return string.replacing(regex, with: "")
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
    guard let regex = try? Regex(pattern).ignoresCase() else { return nil }
    if let match = try? regex.firstMatch(in: text) {
      if match.count > 1, let range = match[1].range {
        return String(text[range])
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
    let startPattern = #"<(div|section)[^>]*class="[^"]*\b\#(containerClass)\b[^"]*"[^>]*>"#
    guard let startRegex = try? Regex(startPattern).ignoresCase(),
      let startMatch = try? startRegex.firstMatch(in: html)
    else { return nil }

    let tagName = String(html[startMatch[1].range!]).lowercased()
    let scanStart = startMatch.range.upperBound

    let remainingString = html[scanStart...]
    let tagPattern = #"</?\#(tagName)\b[^>]*>"#
    guard let tagRegex = try? Regex(tagPattern).ignoresCase() else { return nil }

    var depth = 1
    var currentRange = remainingString.startIndex..<remainingString.endIndex

    while depth > 0 {
      guard let tagMatch = try? tagRegex.firstMatch(in: remainingString[currentRange]) else {
        break
      }
      let tagText = remainingString[tagMatch.range]
      if tagText.hasPrefix("</") {
        depth -= 1
        if depth == 0 {
          return String(remainingString[..<tagMatch.range.lowerBound])
        }
      } else {
        depth += 1
      }
      currentRange = tagMatch.range.upperBound..<remainingString.endIndex
    }
    return nil
  }
}
