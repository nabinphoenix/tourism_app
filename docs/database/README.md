# Database planning

Production tables, relationships, access rules, and indexes are intentionally
not designed in this milestone.

Before writing the first production migration, document the requirements,
review the data model, define Row Level Security policies for each exposed
table, and agree on seed-data boundaries. Store ordered SQL changes in
supabase/migrations. Keep local development fixtures in supabase/seed.

