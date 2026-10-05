# ADR 0002: Supabase as the initial backend

- Status: Accepted
- Decision: Use Supabase for authentication, PostgreSQL, and storage.
- Reason: It provides the first backend services without introducing a
  separate custom API service.
- Consequence: Define and review PostgreSQL Row Level Security policies with
  the future schema. Keep service-role credentials server-side only.

