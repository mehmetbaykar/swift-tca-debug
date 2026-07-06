import ComposableArchitecture
import Foundation
import Testing

@testable import Example

@MainActor
@Suite("AppFeature")
struct AppFeatureTests {
  @Test("counter actions update the count")
  func counterActions() async {
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }

    await store.send(.incrementTapped) {
      $0.count = 1
    }
    await store.send(.decrementTapped) {
      $0.count = 0
    }
    await store.send(.incrementTapped) {
      $0.count = 1
    }
    await store.send(.resetTapped) {
      $0.count = 0
      $0.posts = []
      $0.errorMessage = nil
    }
  }

  @Test("fetch posts stores successful responses")
  func fetchPostsSuccess() async {
    let posts = [
      Post(id: 1, title: "First post", body: "Body")
    ]
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.postsClient.fetch = { posts }
    }

    await store.send(.fetchPostsTapped) {
      $0.isLoading = true
      $0.errorMessage = nil
    }
    await store.receive(\.postsResponse.success) {
      $0.isLoading = false
      $0.posts = posts
    }
  }

  @Test("fetch posts stores failures")
  func fetchPostsFailure() async {
    struct FetchError: LocalizedError {
      var errorDescription: String? { "Could not load posts" }
    }

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.postsClient.fetch = { throw FetchError() }
    }

    await store.send(.fetchPostsTapped) {
      $0.isLoading = true
      $0.errorMessage = nil
    }
    await store.receive {
      guard case .postsResponse(.failure) = $0 else {
        return false
      }
      return true
    } assert: {
      $0.isLoading = false
      $0.errorMessage = "Could not load posts"
    }
  }
}
