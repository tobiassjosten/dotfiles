# Hexagonal Architecture (Ports and Adapters)

The application core knows nothing about what's outside it. Inbound use cases drive the core through input ports; the core declares the output ports it needs, and infrastructure adapters implement them at the edge.

## What to honor

- **Core in the middle.** The domain and application layers contain no framework imports, no HTTP, no SQL, no message brokers. They describe behavior in their own vocabulary.
- **Ports are interfaces owned by the core.** Input ports are how the outside world asks the core to do something (use cases). Output ports are what the core needs from the outside world (repositories, gateways, clocks, ID generators).
- **Adapters implement ports.** HTTP handlers, CLI commands, queue consumers are inbound adapters. Database clients, HTTP clients, file readers are outbound adapters. They depend on the core; the core never depends on them.
- **Composition at the edge.** Wiring (which adapter implements which port) happens at the composition root — `main`, an entry point, a DI container. The core has no idea which adapter is running.

## How to apply it

- When adding a feature, ask: what's the use case (inbound)? What external dependencies does it need (outbound)? Define the ports first.
- Never import infrastructure code from the core. Not a database driver, not an HTTP client, not a framework annotation.
- Never put framework decorators (`@Controller`, `@Entity`, ORM mappings) on domain types. Those live on adapter-side DTOs that map to domain objects at the boundary.
- If a new dependency direction would point from core to adapter, that's a design error — invert it with a port.
- Tests for the core use in-memory or fake adapters; tests for adapters verify the contract their port specifies.
