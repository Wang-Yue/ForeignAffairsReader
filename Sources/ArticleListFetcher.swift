import Foundation

class ArticleListFetcher {
  static func fetch() async throws -> [ArticleHeader] {
    // Use the RSS feed URL for all other list fetches
    let rssURL = URL(string: "https://www.foreignaffairs.com/rss.xml")!
    var request = URLRequest(url: rssURL)
    request.setValue(
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      forHTTPHeaderField: "User-Agent")

    let (responseData, _) = try await URLSession.shared.data(for: request)
    let parser = RSSParser()
    let list = parser.parse(xmlData: responseData)

    if list.isEmpty {
      throw NSError(
        domain: "ArticleListFetcher", code: -2,
        userInfo: [
          NSLocalizedDescriptionKey: "No articles found in RSS feed"
        ])
    }
    return list
  }
}

class RSSParser: NSObject, XMLParserDelegate {
  private var items: [ArticleHeader] = []

  private var currentElement = ""
  private var currentTitle = ""
  private var currentLink = ""
  private var currentDescription = ""
  private var currentCreator = ""
  private var currentImageUrl = ""
  private var inItem = false

  func parse(xmlData: Data) -> [ArticleHeader] {
    let parser = XMLParser(data: xmlData)
    parser.shouldProcessNamespaces = false
    parser.shouldReportNamespacePrefixes = false
    parser.delegate = self
    parser.parse()
    return items
  }

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    currentElement = elementName
    if elementName == "item" {
      inItem = true
      currentTitle = ""
      currentLink = ""
      currentDescription = ""
      currentCreator = ""
      currentImageUrl = ""
    } else if inItem {
      if elementName == "media:content" || qName == "media:content" {
        if let url = attributeDict["url"] {
          currentImageUrl = url
        }
      }
    }
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    guard inItem else { return }

    switch currentElement {
    case "title":
      currentTitle += string
    case "link":
      currentLink += string
    case "description":
      currentDescription += string
    case "dc:creator", "creator":
      currentCreator += string
    default:
      break
    }
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if elementName == "item" {
      inItem = false

      let trimmedTitle = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedDescription = currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedCreator = currentCreator.trimmingCharacters(in: .whitespacesAndNewlines)

      // Extract category
      var category = "FEATURED"
      if let url = URL(string: trimmedLink) {
        let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        if pathComponents.count >= 2 {
          category = pathComponents[0].replacingOccurrences(of: "-", with: " ").uppercased()
        }
      }

      let header = ArticleHeader(
        url: trimmedLink,
        title: trimmedTitle,
        subtitle: trimmedDescription,
        byline: trimmedCreator,
        image: currentImageUrl,
        category: category
      )
      items.append(header)
    }
  }
}
