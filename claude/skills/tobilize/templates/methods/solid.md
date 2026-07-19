# SOLID Principles

Five design principles for class and module design that, applied together, keep code easy to change. They are not laws — they are heuristics that flag where a design will hurt under future pressure.

## What to honor

- **Single Responsibility (SRP).** Each module has one reason to change. If a class is touched by two unrelated kinds of requirement, those concerns belong in two classes.
- **Open/Closed (OCP).** Modules are open for extension, closed for modification. Adding a new variant of behavior should mean a new type, not editing an existing one.
- **Liskov Substitution (LSP).** Subtypes must be usable wherever their base type is, without surprises. If a subclass weakens a postcondition or strengthens a precondition, the hierarchy is broken.
- **Interface Segregation (ISP).** Clients shouldn't depend on methods they don't use. Many small, focused interfaces beat one fat one.
- **Dependency Inversion (DIP).** Depend on abstractions, not concretions. The abstraction is owned by the higher-level module that uses it — not by the lower-level module that implements it.

## How to apply it

- When a class accumulates unrelated responsibilities, split it before it grows further.
- When you see a `switch` or `if/else` ladder on type, replace it with polymorphism — that's OCP in practice.
- When a small change ripples across many modules, look for the abstraction that's missing.
- When an interface forces implementers to leave methods empty or throw "not supported," it's too wide — split it.
- When a high-level module imports a low-level module, the dependency is pointing the wrong way — introduce a port owned by the high level and have the low level implement it.
