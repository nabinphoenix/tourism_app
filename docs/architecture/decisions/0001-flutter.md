# ADR 0001: Flutter for the mobile client

- Status: Accepted
- Decision: Build Android and iOS from one Flutter/Dart application.
- Reason: A shared codebase fits the initial cross-platform scope and keeps the
  small team focused on one client implementation.
- Consequence: Generate both native platform folders from Flutter. iOS
  production builds still require macOS and Xcode.

