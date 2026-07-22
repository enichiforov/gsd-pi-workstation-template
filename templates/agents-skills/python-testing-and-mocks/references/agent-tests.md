# Agent and LLM Boundary Tests

## Separate deterministic and nondeterministic surfaces

Unit-test deterministically:

- prompt/message construction;
- tool schemas and routing;
- parser/validator behavior;
- state transitions;
- checkpoint keys and serialization;
- retry/guardrail decisions;
- provider-error translation.

Use recorded or hand-built provider responses that include malformed, missing, duplicate, and
unexpected fields. Do not mock the state transition you are trying to test.

## Tool calls

Verify tool name, typed arguments, authorization/context propagation, idempotency key, and handling
of tool errors. Avoid asserting provider-specific incidental metadata unless it is the contract.

## Checkpoints and memory

Create a node/graph whose implementation actually reads prior state before asserting recall. A
checkpoint alone cannot make a node mention earlier facts that it never consumes.

Test:

- new versus existing thread/session;
- isolation across thread IDs;
- resume after interruption;
- invalid/stale checkpoint;
- concurrent updates;
- storage outage;
- data retention/redaction.

## Live evaluations

Keep live model/provider evaluations separate from the ordinary deterministic test suite. Gate
them by credentials, cost, rate limits, and explicit datasets/rubrics. Record model/version and
inputs. Do not turn one stochastic response into a unit-test oracle.
