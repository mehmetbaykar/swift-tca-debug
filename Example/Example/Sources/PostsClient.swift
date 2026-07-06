import ComposableArchitecture
import Foundation

struct Post: Codable, Equatable, Identifiable, Sendable {
  let id: Int
  let title: String
  let body: String
}

@DependencyClient
struct PostsClient: Sendable {
  var fetch: @Sendable () async throws -> [Post]
}

extension PostsClient: DependencyKey {
  // Uses URLSession.shared on purpose: TCADebug.enableNetworkLogging() captures it,
  // so every fetch shows up in the console's network view.
  static let liveValue = PostsClient {
    guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts") else {
      throw URLError(.badURL)
    }
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([Post].self, from: data)
  }
}

extension DependencyValues {
  var postsClient: PostsClient {
    get { self[PostsClient.self] }
    set { self[PostsClient.self] = newValue }
  }
}
