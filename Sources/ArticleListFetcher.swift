import Foundation

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

class ArticleListFetcher {
  static func fetch(url: URL) async throws -> [ArticleHeader] {
    if url.pathComponents.contains("search") {
      let query = url.lastPathComponent == "search" ? "" : url.lastPathComponent
      return try await fetchNativeSearch(query: query)
    }

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
