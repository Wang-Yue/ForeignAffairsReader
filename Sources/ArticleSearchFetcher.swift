import Foundation

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

class ArticleSearchFetcher {
  static func search(query: String) async throws -> [ArticleHeader] {
    guard !query.isEmpty else {
      throw NSError(
        domain: "ArticleSearchFetcher", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Search query cannot be empty"])
    }

    let url = URL(string: "https://www.foreignaffairs.com/fa-search.php")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      forHTTPHeaderField: "User-Agent")

    let escapedQuery = query.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(
      of: "\"", with: "\\\"")
    let jsonString = """
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
