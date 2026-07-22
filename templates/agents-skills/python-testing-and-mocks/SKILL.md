---
name: python-testing-and-mocks
description: "Design and implement Python test suites with pytest: unit/integration/contract/E2E layering, stubs/fakes/mocks/spies, patch-where-looked-up, fixtures and isolation, pytest-asyncio strict mode, time/filesystem/external-service control, database and Alembic tests, property-based tests, and agent/LLM boundary tests. Use when adding tests or replacing real APIs/DB/LLM/providers safely."
---

# Python Testing and Mocks

Test observable contracts at the cheapest layer that can prove them. Replace boundaries, not the
business behavior under test.

## Workflow

1. **State the contract.** List input, output, durable effects, expected absence/failure states,
   invariants, and compatibility promises.
2. **Choose the proving layer.**
   - Unit: pure behavior and use cases through ports.
   - Integration: real adapter plus database/filesystem/provider sandbox.
   - Contract: both sides agree on a schema/protocol.
   - End-to-end: a small set of critical user flows.
3. **Choose the smallest test double.** Use a stub for canned values, fake for working simplified
   behavior, mock for interaction expectations, and spy to observe real behavior.
4. **Inject the boundary.** Prefer constructor/function DI. Patch only as a constrained seam and
   patch the name where the system under test looks it up.
5. **Control lifecycle and nondeterminism.** Isolate mutable state, time, randomness, filesystem,
   environment, queues, and async tasks with explicit fixtures/owners.
6. **Test negative and absence paths.** Include provider failure, invalid state, duplicates,
   cancellation, partial writes, and authorization denial according to the real contract.
7. **Assert behavior, not implementation trivia.** Assert outputs, state, events, and meaningful
   boundary interactions. Avoid exact internal call order unless it is the contract.
8. **Run the smallest relevant suite, then required project gates.** Remove duplicate tests and
   verify the test itself fails before the fix when practical.

## Core rules

- Never call paid/live external APIs, production databases, or real LLMs from ordinary unit tests.
- Do not mock the function/class whose business behavior is the subject of the test.
- Keep fake contracts type-correct, including absence types such as `User | None`.
- Reset/restore patches, env changes, dependency overrides, clocks, and temporary resources.
- In pytest-asyncio strict mode, decorate async fixtures with `@pytest_asyncio.fixture`.
- Await or cancel every task a test starts. Do not let background tasks leak between tests.
- Prefer deterministic events/barriers over sleeps for concurrency tests.
- Keep migration and adapter tests on the real target database engine when dialect behavior matters.
- Treat LLM output as untrusted/nondeterministic; test prompts/tool schemas/parsers/guardrails with
  fixtures and contract properties, then keep limited live evals in a separate gated lane.
- Do not invent fallback behavior in a test. Derive recovery expectations from a named product or
  loop contract.

## Load references selectively

- For doubles, patching, fixtures, parametrization, properties, and isolation, read
  [pytest-fixtures-and-doubles.md](references/pytest-fixtures-and-doubles.md).
- For pytest-asyncio, task cleanup, cancellation, and race tests, read
  [async-tests.md](references/async-tests.md).
- For FastAPI dependency overrides, application lifespan, and runtime-boundary tests, use
  `python-web-service-runtime`.
- For repositories, transactions, constraints, and Alembic replay, read
  [database-and-migrations.md](references/database-and-migrations.md).
- For agent/LLM/tool/checkpoint boundaries, read [agent-tests.md](references/agent-tests.md).
- For provenance and corrected examples, read
  [advice17-source-map.md](references/advice17-source-map.md).

## Output contract

Return:

1. contract and risks;
2. selected test layers;
3. boundary/double choices;
4. fixtures and isolation strategy;
5. positive, negative, absence, and concurrency cases;
6. commands/gates and evidence.

Name what remains untested and why.
