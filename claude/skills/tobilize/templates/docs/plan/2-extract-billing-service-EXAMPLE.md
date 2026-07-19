# Extract billing service

> *Example file demonstrating the `{N}-` sequenced convention — delete or replace.*

Pull billing logic out of the monolith into its own service so it can be deployed and scaled independently.

## Why sequenced

Step 1 of a two-step refactor. The event-bus change in `3-add-event-bus-EXAMPLE.md` introduces a bus *between* the new billing service and the rest of the system. Doing the bus first would force billing extraction to fit a bus payload convention that doesn't exist yet — easier to extract first, bus second.

## Done when

- Billing service is deployed and serving production traffic.
- The monolith calls it over the network for all billing operations.
- The in-process billing module is deleted from the monolith.
