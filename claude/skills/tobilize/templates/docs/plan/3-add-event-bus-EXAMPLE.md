# Add event bus

> *Example file demonstrating the `{N}-` sequenced convention (later step) — delete or replace.*

Introduce a shared event bus for cross-service communication, replacing the current pattern of point-to-point HTTP calls between services.

## Why sequenced after billing extraction

The bus is introduced between the freshly-extracted billing service (see `2-extract-billing-service-EXAMPLE.md`) and the rest of the system. The payload format also assumes the legacy `user_id_old` column is already gone (see `1-finish-legacy-migration-EXAMPLE.md`).

## Done when

- Event bus is deployed.
- Billing service publishes domain events through it.
- At least one downstream consumer is subscribed and acting on those events.
