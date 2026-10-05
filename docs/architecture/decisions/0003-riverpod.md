# ADR 0003: Riverpod for application state

- Status: Accepted
- Decision: Use Riverpod for state management and dependency injection.
- Reason: It gives the app testable service boundaries and explicit loading,
  data, and error states without requiring a large app framework.
- Consequence: Keep providers close to app or feature boundaries and avoid
  putting all business behavior in widgets.

