---
name: python-testing-and-mocks
description: "Write Python tests with test doubles (stub/mock/fake), dependency injection for testability, pytest fixtures, unittest.mock patching, database/Alembic tests, and LangGraph agent tests. Use when writing tests, mocking external APIs/DB/LLM, setting up fixtures, or testing agents without hitting real services."
---

# Python Testing & Mocks

**Source:** @advice17 Channel (posts #56, #31, #49, #14, #8, #24)

## When to Use

**Triggers:**
- "How do I test this without hitting the database"
- "Write tests for this agent"
- "Mock the external API call"
- "Set up test fixtures"
- "How should I structure test data"
- Building pytest fixtures for LangGraph agents
- Testing agents with dependency injection

## Core Concepts

### 1. Test Doubles Hierarchy

From [post #31 - Mocks, Stubs, Patches]:

```
        Test Double
       /    |    \
      /     |     \
   Stub  Mock  Fake
    |      |      |
    |      |      |
Pure  Verifies  Works
reply behavior  logic
```

**Stub:** Returns fixed data, doesn't care about calls
```python
class StubEmailService:
    def send(self, to: str, body: str) -> bool:
        return True  # Always succeeds
```

**Mock:** Verifies behavior (was it called? how many times?)
```python
class MockEmailService:
    def __init__(self):
        self.calls = []
    
    def send(self, to: str, body: str) -> bool:
        self.calls.append((to, body))
        return True
    
    def assert_called_with(self, to: str, body: str):
        assert (to, body) in self.calls
```

**Fake:** Actually works but simplified (in-memory DB)
```python
class FakeUserRepository:
    def __init__(self):
        self._data = {}
    
    async def save(self, user: User):
        self._data[user.id] = user
    
    async def find(self, user_id: str) -> User:
        return self._data.get(user_id)
```

**Spy/Patch:** Wraps real object to track calls
```python
from unittest.mock import patch, MagicMock

with patch('my_module.external_api.call') as mock_api:
    mock_api.return_value = {"status": "ok"}
    result = my_function_calling_api()
    assert mock_api.called  # Verify it was called
```

---

### 2. Dependency Injection for Testing

From [post #56 - Dependency Injection]:

**Without DI (hard to test):**
```python
# ❌ BAD
class EmailAgent:
    def __init__(self):
        self.email_service = GmailService()  # Hard-coded
        self.memory = Mem0Backend()  # Hard-coded
    
    async def send_email(self, ...):
        # Can't replace these with mocks!
```

**With DI (testable):**
```python
# ✅ GOOD
class EmailAgent:
    def __init__(self, 
                 email_service: EmailServiceProtocol,
                 memory: MemoryProviderProtocol):
        self.email_service = email_service
        self.memory = memory

# Real code
real_agent = EmailAgent(
    email_service=GmailService(),
    memory=Mem0Backend()
)

# Test code
test_agent = EmailAgent(
    email_service=MockEmailService(),
    memory=FakeMemory()
)
```

---

### 3. Test Structure with Fixtures

From [post #14 - FastAPI & Dependency Injection]:

> **pytest-asyncio note:** an `async def` fixture must be declared with `@pytest_asyncio.fixture` (not `@pytest.fixture`) in the default **strict** mode, or set `asyncio_mode = "auto"` in config so plain `@pytest.fixture` async fixtures/tests are picked up. Otherwise the fixture is never awaited and your test gets a coroutine object.

```python
# Fixtures (setup/teardown for tests)
import pytest
import pytest_asyncio   # required for async fixtures in strict mode

@pytest_asyncio.fixture
async def db():
    """Real or test database connection."""
    db = AsyncSession(engine)
    yield db
    await db.close()

@pytest_asyncio.fixture
async def mock_memory():
    """Mocked memory provider."""
    class MockMemory:
        async def recall(self, query: str):
            return ["test_memory_1", "test_memory_2"]
    return MockMemory()

@pytest_asyncio.fixture
async def agent(mock_memory, db):
    """Agent with mocked dependencies."""
    return Agent(memory=mock_memory, db=db)

# Use fixtures in tests
@pytest.mark.asyncio
async def test_agent_recall(agent, mock_memory):
    result = await agent.process("test query")
    # Verify behavior
    assert "test_memory_1" in result
```

---

### 4. Patching & Mocking (unittest.mock)

```python
from unittest.mock import patch, MagicMock, AsyncMock

# Patch a single function
@patch('my_module.external_api.fetch')
def test_with_mock(mock_fetch):
    mock_fetch.return_value = {"data": "test"}
    result = my_function()
    assert result == {"data": "test"}
    mock_fetch.assert_called_once()

# Patch async functions (needs the pytest-asyncio marker, or auto mode)
@pytest.mark.asyncio
@patch('my_module.async_api.call', new_callable=AsyncMock)
async def test_async(mock_call):
    mock_call.return_value = {"status": "ok"}
    result = await my_async_function()
    mock_call.assert_called()

# Side effects (simulate behavior)
mock_api = MagicMock()
mock_api.side_effect = [
    {"status": "ok"},     # First call returns this
    {"status": "error"},  # Second call returns this
    ValueError("timeout") # Third call raises
]

# Context manager for temporary patching
with patch.dict('os.environ', {'API_KEY': 'test_key'}):
    # Temporarily change environment
    result = my_function_using_env()
    # Back to normal after context exits
```

---

### 5. Database Testing (Alembic)

From [post #49 - Alembic Trickiness]:

**Problem:** Alembic migrations need to be tested.

```python
# Don't: Reset DB each time (slow)
# Do: Use test transactions + rollback

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

@pytest.fixture(scope="session")
def test_engine():
    """Create test database (runs once per test session)."""
    return create_engine("sqlite:///:memory:")

@pytest.fixture
def test_db(test_engine):
    """Transaction-scoped DB that rolls back after each test.

    NOTE: `engine.begin()` COMMITS on a clean exit — it does not roll back.
    For per-test isolation, open a connection, begin a transaction, and
    roll it back in teardown:
    """
    conn = test_engine.connect()
    trans = conn.begin()
    Base.metadata.create_all(conn)
    try:
        yield conn
    finally:
        trans.rollback()   # explicit rollback — nothing is committed
        conn.close()

# Or use pytest-postgresql for real DB
@pytest.fixture
def postgres_db():
    """Real PostgreSQL for integration tests."""
    with postgres_container():
        yield db
```

**Testing migrations:** use the real Alembic command API — there is no `script.get_revision(...).up()` method.
```python
from alembic.config import Config
from alembic.command import upgrade, downgrade
from alembic.script import ScriptDirectory

def test_migration_roundtrip():
    """Upgrade to head, then downgrade to base, using the command API."""
    config = Config("alembic.ini")          # or Config() + set_main_option(...)
    upgrade(config, "head")                 # apply all migrations
    # ... inspect schema here (see next example) ...
    downgrade(config, "base")               # revert them

def test_single_head():
    """Guard against branch/merge mistakes: exactly one head."""
    script = ScriptDirectory.from_config(Config("alembic.ini"))
    assert len(script.get_heads()) == 1
```

---

### 6. Agent/LangGraph Testing

```python
from langgraph.graph import StateGraph
from langgraph.checkpoint.memory import MemorySaver  # in-memory checkpointer

@pytest.fixture
def mock_llm():
    """Mock LLM that returns fixed responses AND records calls.

    Use MagicMock so `.invoke.assert_called()` works; wrap it so the
    return value is deterministic.
    """
    from unittest.mock import MagicMock
    llm = MagicMock()
    llm.invoke.side_effect = lambda prompt: {"content": f"Mock response to: {prompt[:20]}"}
    return llm

@pytest.fixture   # plain fixture — no await inside, so not async
def test_graph(mock_llm):
    """Simple agent graph for testing."""
    builder = StateGraph(AgentState)

    builder.add_node("router", lambda state: {"next": "think"})
    builder.add_node("think", lambda state: {
        "response": mock_llm.invoke(state["input"])
    })

    builder.add_edge("router", "think")
    builder.set_entry_point("router")

    return builder.compile()

@pytest.mark.asyncio
async def test_agent_basic_flow(test_graph, mock_llm):
    """Test agent basic routing."""
    result = test_graph.invoke({
        "input": "What is 2+2?",
        "messages": []
    })
    
    assert result["response"]["content"]
    mock_llm.invoke.assert_called()  # MagicMock records the call

# Test with checkpointing
@pytest.fixture
def test_graph_with_memory(mock_llm):
    """Agent with conversation memory (in-memory checkpointer)."""
    memory = MemorySaver()  # correct in-memory checkpointer API
    builder = StateGraph(AgentState)
    builder.add_node("think", lambda state: {"response": mock_llm.invoke(state["input"])})
    builder.set_entry_point("think")
    graph = builder.compile(checkpointer=memory)
    return graph

def test_agent_with_memory(test_graph_with_memory):
    """Test that the checkpointer persists state across turns.

    IMPORTANT: memory only "works" if your nodes actually READ prior state.
    The trivial `think` node above just echoes the current input, so it can't
    recall Turn 1 — a real test needs a message-accumulating state (a reducer
    like `add_messages`) and a node that reads it. Assert on the response
    *content*, not on the dict itself (`x in {"content": ...}` checks keys).
    """
    config = {"configurable": {"thread_id": "test-1"}}

    test_graph_with_memory.invoke({"input": "My name is Alice"}, config)
    result2 = test_graph_with_memory.invoke({"input": "What's my name?"}, config)

    # Checkpointed state for this thread is retrievable:
    snapshot = test_graph_with_memory.get_state(config)
    assert snapshot is not None
    # And (with a real recall node) the content — not the dict — mentions Alice:
    assert "Alice" in result2["response"]["content"]
```

---

## Step-by-Step Guide

### Scenario: Test an Agent with Database

**Step 1: Define Test Dependencies**
```python
@pytest.fixture
async def mock_memory():
    class Mock:
        async def recall(self, query: str):
            if query == "test":
                return ["memory1", "memory2"]
            return []
    return Mock()

@pytest.fixture
async def mock_kb():
    class Mock:
        async def search(self, query: str):
            return [{"title": "Doc1", "content": "Content"}]
    return Mock()

@pytest.fixture
async def test_agent(mock_memory, mock_kb):
    return MyAgent(memory=mock_memory, kb=mock_kb)
```

**Step 2: Test Happy Path**
```python
@pytest.mark.asyncio
async def test_agent_processes_message(test_agent):
    result = await test_agent.process("test input")
    
    assert result is not None
    assert "memory1" in result  # From mock
    assert "Doc1" in result     # From mock KB
```

**Step 3: Test Error Cases**
```python
@pytest.fixture
async def mock_memory_error():
    class Mock:
        async def recall(self, query: str):
            raise ConnectionError("Memory unavailable")
    return Mock()

@pytest.mark.asyncio
async def test_agent_handles_memory_error(mock_memory_error, mock_kb):
    agent = MyAgent(memory=mock_memory_error, kb=mock_kb)
    
    # Should handle gracefully
    result = await agent.process("test")
    assert result is not None  # Fallback behavior
    assert "error" in result.lower()  # Or explicit error message
```

**Step 4: Verify Calls**
```python
@pytest.mark.asyncio
async def test_agent_calls_memory(test_agent, mock_memory):
    # Use a real mock to track calls
    mock_memory.recall = AsyncMock(return_value=["test"])
    
    await test_agent.process("test query")
    
    # Verify memory was called with right query
    mock_memory.recall.assert_called_once_with("test query")
```

**Step 5: Integration Test (with real DB)**
```python
@pytest.mark.asyncio
@pytest.mark.integration
async def test_agent_with_real_db(postgres_db):
    """Run against real database (slower, more realistic)."""
    real_memory = Mem0Backend()
    real_kb = KBBackend(db=postgres_db)
    
    agent = MyAgent(memory=real_memory, kb=real_kb)
    result = await agent.process("test query")
    
    # Verify database was actually queried
    assert len(result) > 0
```

---

## Anti-Patterns to Avoid

### ❌ 1. Over-Mocking
```python
# BAD: Mock everything, no real logic tested
def test_agent():
    mock_memory = MagicMock()
    mock_kb = MagicMock()
    mock_llm = MagicMock()
    agent = Agent(mock_memory, mock_kb, mock_llm)
    
    result = agent.process("test")
    # You've tested mocks, not the agent
```

**Better:** Test real business logic, mock only externals.
```python
def test_agent():
    # Real logic
    agent = Agent(
        memory=FakeMemory(),  # Simplified but real
        kb=MockKB(),          # External only
        llm=MockLLM()         # External only
    )
    result = agent.process("test")
    assert result is expected
```

### ❌ 2. Shared Test State
```python
# BAD: Tests interfere with each other
class TestAgent:
    agent = Agent()  # Shared across all tests
    
    def test_one(self):
        self.agent.state["count"] = 5
    
    def test_two(self):
        # test_one may have run first, state corrupted
        assert self.agent.state["count"] == 0
```

**Better:** Use fixtures for isolation.
```python
@pytest.fixture
def agent():
    return Agent()  # Fresh for each test

def test_one(agent):
    agent.state["count"] = 5
    assert agent.state["count"] == 5

def test_two(agent):
    assert agent.state["count"] == 0  # Fresh state
```

### ❌ 3. Testing Implementation, Not Behavior
```python
# BAD: Test implementation details
def test_agent():
    agent = Agent()
    # Testing internal method
    assert agent._internal_counter == 0
    agent._set_state_directly({"x": 1})
    assert agent._internal_counter == 1
```

**Better:** Test public contracts.
```python
def test_agent():
    agent = Agent()
    result = agent.process("input")
    assert "expected_output" in result
```

### ❌ 4. Brittle Mocks
```python
# BAD: Mock is too specific
mock = MagicMock()
mock.method.return_value.another_method.return_value = "exact_value"

# One change to the chain, test breaks
```

**Better:** Mock only what's needed.
```python
mock = MagicMock(return_value={"status": "ok"})
# Only care about the final output
```

---

## Key Takeaways

1. **Choose right double:** Stub for returns, Mock for behavior verification, Fake for logic
2. **Inject dependencies** to make testing possible
3. **Use fixtures** for setup/teardown and isolation
4. **Mock externals only** (DB, API, LLM) — test real logic
5. **Test behavior, not implementation** — public API contracts matter
6. **Keep mocks simple** — if mock is complex, real code is too complex

---

## References

- **Post #31:** Mocks, Stubs, Patches
- **Post #56:** Dependency Injection
- **Post #49:** Alembic Nuances
- **Post #14:** FastAPI & DI
- **pytest docs:** https://docs.pytest.org
- **unittest.mock:** https://docs.python.org/3/library/unittest.mock.html

---

## Next Skills to Pair With

- `python-architecture-patterns` — Design for testability
- `tdd` — Test-first development
- `python-debugging-and-observability` — Logging in tests
