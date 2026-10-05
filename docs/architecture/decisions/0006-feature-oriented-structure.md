# ADR 0006: Feature-oriented Flutter structure

- Status: Accepted
- Decision: Group implementation by product feature, with small shared app
  and core areas for cross-cutting concerns.
- Reason: Feature ownership stays understandable as the app grows, without
  creating layers of abstraction before they are needed.
- Consequence: Add feature files when implementing them; do not populate every
  planned feature with placeholder boilerplate.

