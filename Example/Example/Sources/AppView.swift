import ComposableArchitecture
import SwiftUI

struct AppView: View {
  let store: StoreOf<AppFeature>

  var body: some View {
    NavigationStack {
      List {
        Section("Actions") {
          LabeledContent("Count", value: "\(self.store.count)")
          Button("Increment") {
            self.store.send(.incrementTapped)
          }
          .accessibilityIdentifier("example.increment")
          Button("Decrement") {
            self.store.send(.decrementTapped)
          }
          .accessibilityIdentifier("example.decrement")
          Button("Reset", role: .destructive) {
            self.store.send(.resetTapped)
          }
          .accessibilityIdentifier("example.reset")
        }

        Section("Network") {
          Button {
            self.store.send(.fetchPostsTapped)
          } label: {
            if self.store.isLoading {
              HStack {
                Text("Fetching…")
                Spacer()
                ProgressView()
              }
            } else {
              Text("Fetch Posts")
            }
          }
          .disabled(self.store.isLoading)
          .accessibilityIdentifier("example.fetch")

          if let errorMessage = self.store.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
              .foregroundStyle(.red)
          }

          ForEach(self.store.posts) { post in
            VStack(alignment: .leading, spacing: 4) {
              Text(post.title)
                .font(.headline)
              Text(post.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            .accessibilityIdentifier("example.post")
          }
        }
      }
      .navigationTitle("TCADebug Example")
    }
  }
}
