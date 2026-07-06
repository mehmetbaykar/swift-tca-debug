import ComposableArchitecture
import Foundation
import Logging

@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable {
    var count = 0
    var posts: [Post] = []
    var isLoading = false
    var errorMessage: String?
  }

  enum Action {
    case incrementTapped
    case decrementTapped
    case resetTapped
    case fetchPostsTapped
    case postsResponse(Result<[Post], any Error>)
  }

  @Dependency(\.postsClient) var postsClient

  // Demonstrates app-level logging alongside the reducer's debugLog: these messages
  // land in the same Pulse store and show up in the console next to the TCA dumps.
  private let logger = Logger(label: "example.app-feature")

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .incrementTapped:
        state.count += 1
        return .none

      case .decrementTapped:
        state.count -= 1
        return .none

      case .resetTapped:
        state.count = 0
        state.posts = []
        state.errorMessage = nil
        return .none

      case .fetchPostsTapped:
        state.isLoading = true
        state.errorMessage = nil
        self.logger.info("Fetching posts")
        return .run { send in
          await send(.postsResponse(Result { try await self.postsClient.fetch() }))
        }

      case .postsResponse(.success(let posts)):
        state.isLoading = false
        state.posts = posts
        self.logger.info("Fetched posts", metadata: ["count": "\(posts.count)"])
        return .none

      case .postsResponse(.failure(let error)):
        state.isLoading = false
        state.errorMessage = error.localizedDescription
        self.logger.error("Fetching posts failed", error: error)
        return .none
      }
    }
  }
}
