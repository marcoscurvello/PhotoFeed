### Live Unsplash API

To run against the live API:

1. Rename `Secrets.example.xcconfig` to `Secrets.xcconfig`.
2. Replace `your_key_here` with a valid Unsplash API access key:

```text
UNSPLASH_ACCESS_KEY = your_key_here
```

3. In `PhotoFeedApp.swift`, change:

```swift
private static let environment: Environment = .fixture
```

to:

```swift
private static let environment: Environment = .live
```