# Domain-Driven Design

This codebase treats the domain as the heart of the system. Code expresses the language the business uses, and behavior lives on the domain objects that own the data — not in services, managers, or controllers.

## What to honor

- **Ubiquitous language.** Names in code mirror the names users and the business use. If the business says "policy holder," the code says `PolicyHolder` — not `User`, not `Customer`. Synonyms get reconciled; one term per concept.
- **Aggregates.** A cluster of related objects treated as a single unit, with one root that enforces the invariants. External code interacts only with the root. Cross-aggregate references go by ID, not by direct reference.
- **Value objects.** Immutable, compared by value (not identity). Money, dates, ranges, identifiers — these are value objects, not primitive strings or numbers.
- **Domain events.** Past-tense facts about what happened (`PolicyRenewed`, not `RenewPolicy`). They flow outward from the domain; downstream concerns react.
- **Bounded contexts.** Different parts of the business have different models. The same word (`Account`) can mean two different things in two contexts — keep them apart; translate at the boundary.

## How to apply it

- When adding behavior, push it onto the domain object that owns the data. Resist the temptation to put it in a service "for now."
- Anemic models (data-only classes with all logic outside) are a smell. If a domain object has only getters/setters, the design is leaking.
- When naming, ask: would someone in the business recognize this word? If not, rename.
- When in doubt about where to put a method, ask which object's invariants it protects — that's where it goes.
