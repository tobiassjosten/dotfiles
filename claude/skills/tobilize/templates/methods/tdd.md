# Test-Driven Development

This codebase is developed test-first. Each change starts with a failing test that captures the behavior we want; production code exists to make that test pass.

## What to honor

- **Red-Green-Refactor.** Write the smallest failing test that expresses the next bit of behavior. Make it pass with the simplest code that works. Then refactor — with the green bar as your safety net.
- **Behavior, not implementation.** Tests describe what the code should do for callers, not how it does it. Tests that lock in implementation detail rot fast.
- **One reason to fail.** A test that can fail for two unrelated reasons isn't telling you anything when it goes red. Split it.
- **Fast and isolated.** The fast tests run constantly; if they get slow or flaky, the loop breaks down. Slower integration tests have their place — keep them separate.

## How to apply it

- When asked to add behavior, propose the failing test first. Don't write production code until there's a test that demands it.
- When fixing a bug, write the bug-reproducing test first. It should fail in the way the bug manifests; the fix turns it green.
- Don't refactor with a red bar. Get to green, then refactor.
- If you find yourself writing production code without a test in mind, stop and write the test.
- Don't push code with a test you wrote that's skipped or pending. If a test is genuinely not ready, the production code it covers isn't ready either.
