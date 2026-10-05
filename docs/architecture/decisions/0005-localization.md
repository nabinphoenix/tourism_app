# ADR 0005: English and Nepali localization from day one

- Status: Accepted
- Decision: Use Flutter gen-l10n with English and Nepali ARB resources.
- Reason: Both languages are core to the intended audience and should be
  represented in the app foundation before product copy grows.
- Consequence: Add user-visible copy to translation resources and test both
  locales. Persist the language choice with shared_preferences.

