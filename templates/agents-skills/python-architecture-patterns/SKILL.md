---
name: python-architecture-patterns
description: "Design and review Python service/agent architecture — use cases & interactors, layered architecture, Active Record vs Data Mapper, SQLAlchemy Core vs ORM, Unit of Work, Dependency Injection vs Dependency Inversion. Use when structuring a new module/agent, choosing ORM patterns, applying DI/DIP, or reviewing architectural decisions in Python code."
---

# Python Architecture Patterns

**Source:** @advice17 Channel — posts actually used here: #77 (use cases), #16 (SQL layers), #72 (state in DB), #66 (DB patterns), #74 (SQLAlchemy Core/ORM), #60 (Unit of Work), #56 (DI), #68 (DIP), #52 (generic-repo anti-pattern), #54 (two-phase init).

## When to Use

**Triggers:**
- "Design the architecture for this service"
- "How should I structure this Python module"
- "Which ORM pattern fits best here"
- "How to implement Dependency Injection"
- "What's the difference between this and that pattern"
- "Need to refactor this data layer"
- Planning a new LangGraph agent
- Reviewing architectural decisions in Python code

## Core Concepts

### 1. Use Cases & Interactors

A **use case** is a text description of how an actor (user, system, bot) interacts with your system to achieve a goal.

```
┌─────────────────┐
│ Use Cases       │  Theoretical requirements
│ (Actors goals)  │  Black-box perspective
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Scenarios       │  Sequence of steps
│ (Main + extend) │  How interaction flows
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Interactors     │  Code implementation
│ (Controllers,   │  API calls, handlers
│  Services)      │
└─────────────────┘
```

**Example Use Case: "Book a delivery"**

Main scenario:
1. User enters address
2. System shows delivery options
3. User picks one option

Extensions:
- 3.a User not satisfied → retry input

**Corresponding code:**
- Controller: `POST /delivery/address`
- Service/Interactor: `SelectDeliveryOption`
- Data layer: Repository with async DB calls

**Key insight:** Each logical action (pick address) maps to API calls, clicks, database operations. Use cases guide the structure.

---

### 2. Layered Architecture

Typical Python service:

```
HTTP Request
    ↓
┌──────────────────┐
│ Controller       │  FastAPI route handler
│ (Adapter)        │  Parse request, validate input
└──────────────────┘
    ↓
┌──────────────────┐
│ Interactor/      │  Business logic
│ Service          │  Orchestrate repos & external calls
└──────────────────┘
    ↓
┌──────────────────┐
│ Repository/      │  Data access
│ Entity           │  Models, DB queries
└──────────────────┘
    ↓
┌──────────────────┐
│ Database         │  Persistence
└──────────────────┘
```

**In a typical LangGraph agent:**
- Controller ≈ Agent entrypoint
- Service ≈ Agent router/orchestrator
- Repository ≈ Tools (memory, KB search, external APIs)
- Entity ≈ State, message types

---

### 3. State Management Patterns

#### Option A: ActiveRecord
- Entity knows how to save/load itself
- Fewer classes, more logic in models
- ✅ Fast for small projects
- ❌ Hard to test, tight coupling

```python
# Conceptual Active Record (Django/Peewee-style; NOT SQLAlchemy — SQLAlchemy is Data Mapper).
class User(Model):
    id: int
    name: str

    def save(self) -> None:
        db.add(self); db.commit()

    @classmethod
    def find_by_id(cls, id: int) -> "User":
        return db.query(cls).filter(cls.id == id).first()
```
> If you write this as a real SQLAlchemy 2.0 mapped class, bare `id: int` raises `MappedAnnotationError` — you must use `Mapped[int] = mapped_column(primary_key=True)`. And note SQLAlchemy is a **Data Mapper**, so a `.save()`-on-entity API is not its idiom.

#### Option B: Data Mapper
- Separate entities from persistence logic
- Repository handles all DB operations
- ✅ Testable, flexible, clean code
- ❌ More classes to manage

```python
# Entity (pure business logic, no DB knowledge)
@dataclass
class User:
    id: int
    name: str

# Repository (all DB operations)
class UserRepository:
    def save(self, user: User):
        stmt = insert(users_table).values(id=user.id, name=user.name)
        db.execute(stmt)
    
    def find_by_id(self, id: int) -> User:
        stmt = select(users_table).where(users_table.c.id == id)
        row = db.execute(stmt).first()
        return User(row.id, row.name)
```

**Recommendation:** Data Mapper for pure-logic agents + repositories for KB/memory access.

---

### 4. ORM Patterns (SQLAlchemy)

#### SQLAlchemy has two levels:

**Level 1: Core** (lightweight SQL builder)
```python
stmt = select(users_table).where(users_table.c.age > 25)
result = db.execute(stmt)
```
✅ Full control, explicit, composable
❌ More verbose, no magic

**Level 2: ORM** (object-oriented)
```python
users = db.query(User).filter(User.age > 25).all()
# or
stmt = select(User).where(User.age > 25)
result = db.execute(stmt).scalars().all()
```
✅ Closer to Python objects
❌ Can hide complexity (N+1 queries, lazy loading issues)

**Typical stack:** Use ORM for simple documents + Core for complex queries (reranking, embeddings).

---

### 5. Unit of Work Pattern

Manage a group of related changes as one transaction:

```python
class UnitOfWork:
    def __init__(self, db: Session):
        self.db = db
        self.users = UserRepository(db)
        self.orders = OrderRepository(db)
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is None:
            self.db.commit()  # Atomic: all or nothing
        else:
            self.db.rollback()

# Usage
with UnitOfWork(db) as uow:
    user = uow.users.find_by_id(1)
    user.email = "new@example.com"
    uow.users.save(user)
    order = Order(user_id=user.id)
    uow.orders.save(order)
    # Both saved together, or neither
```

---

### 6. Dependency Injection vs Dependency Inversion

**DI (Dependency Injection):** A technique — passing dependencies as arguments.

```python
class UserService:
    def __init__(self, repo: UserRepository):  # Injected
        self.repo = repo
```

**DIP (Dependency Inversion Principle):** A design principle — high-level code shouldn't depend on low-level code.

```
❌ BAD (High → Low):
┌───────────────────┐
│ UserService       │ knows about
│ (high-level)      │──────────────→ SQLUserRepository
└───────────────────┘           (low-level detail)

✅ GOOD (High → Abstraction ← Low):
┌───────────────────┐         ┌──────────────────┐
│ UserService       │ depends │ UserRepository   │
│ (high-level)      │────────→│ (abstraction)     │
└───────────────────┘         └──────────────────┘
                                       △
                                       │
                                ┌──────┴──────┐
                                │             │
                          ┌─────────────┐  ┌──────────┐
                          │ SQLUserRepo  │  │ MockRepo │
                          │ (impl A)     │  │ (impl B) │
                          └──────────────┘  └──────────┘
```

**Consequence:** You can swap implementations (SQL ↔ Mock for testing).

**In practice:**
```python
# Abstraction (interface)
class MemoryProvider(Protocol):
    def recall(self, query: str) -> list[str]: ...

# High-level (agent logic)
class Agent:
    def __init__(self, memory: MemoryProvider):
        self.memory = memory

# Implementations
class Mem0Provider: ...
class MockProvider: ...
class KBProvider: ...

# Use anywhere
agent = Agent(memory=KBProvider())  # or Mem0Provider, or MockProvider
```

---

## Step-by-Step Guide

### Scenario: Design a new Python service

**Step 1: Define Use Cases**
```
UC1: "User requests a summary"
  Main: 1. Agent receives request
        2. Agent searches memory
        3. Agent generates response
  Extension: 2.a No memory found → use defaults

UC2: "Collect feedback"
  ...
```

**Step 2: Sketch Layers**
```
FastAPI routes (HTTP adapters)
    ↓
{UserAgent, AdminAgent, ...} (business logic)
    ↓
{Memory, KB, Tools} (data/external access)
    ↓
Supabase + OpenAI (external systems)
```

**Step 3: Identify Dependencies**
```
Agent needs:
  - memory_provider: MemoryProvider
  - kb_search: KBSearch
  - llm_client: AsyncLLM

Tool needs:
  - db_connection: AsyncSession
  - api_client: HttpClient
```

**Step 4: Apply Inversion**
```python
# Define abstractions (what agents expect)
class MemoryProvider(Protocol):
    async def recall(self, query: str) -> list[str]: ...

class KBSearch(Protocol):
    async def search(self, query: str) -> list[Document]: ...

# High-level (agent)
class PsychologistAgent:
    def __init__(self, memory: MemoryProvider, kb: KBSearch):
        self.memory = memory
        self.kb = kb
    
    async def process(self, message: str):
        memories = await self.memory.recall(message)
        docs = await self.kb.search(message)
        # ...

# Low-level implementations
class Mem0Provider:
    async def recall(self, query: str) -> list[str]:
        # Call mem0 API
        ...

class SupabaseKB:
    async def search(self, query: str) -> list[Document]:
        # Call Supabase with pgvector
        ...

# Bootstrap
memory = Mem0Provider()
kb = SupabaseKB()
agent = PsychologistAgent(memory=memory, kb=kb)
```

**Step 5: Testability**
```python
# Mock for testing
class MockMemory:
    async def recall(self, query: str) -> list[str]:
        return ["memory1", "memory2"]

# `await` only works inside async context — use a pytest-asyncio test:
@pytest.mark.asyncio
async def test_agent_uses_memory():
    agent = PsychologistAgent(memory=MockMemory(), kb=MockKB())
    result = await agent.process("test input")
    assert "memory1" in str(result)
```

---

## Anti-Patterns to Avoid

### ❌ 1. Generic Repository
```python
# BAD: One repository for all entities
class GenericRepository(Generic[T]):
    def get(self, id): ...
    def save(self, entity): ...
    def delete(self, id): ...

# Hides domain logic, unclear what's happening
```

**Why:** No domain meaning, no type safety for domain operations.

**Better:** Entity-specific repositories with explicit methods.

### ❌ 2. Service Layer Anti-Pattern
```python
# BAD: Service does everything
class UserService:
    def create_user_and_send_email(self, email, ...):
        user = User(email=email)
        db.save(user)
        send_email(user.email)  # What if email fails?
    
    def get_users_and_filter_and_sort(self, ...):
        users = db.query(User).all()
        return filter_and_sort(users)  # Business logic mixed with data access
```

**Better:** Separate concerns.
```python
class UserService:
    def __init__(self, user_repo: UserRepository, email_svc: EmailService):
        self.user_repo = user_repo
        self.email_svc = email_svc
    
    async def register_user(self, email: str):
        user = await self.user_repo.create(email)
        try:
            await self.email_svc.send_welcome(email)
        except EmailError:
            # Handle explicitly
            logger.error(f"Email failed for {email}")
            # Decide: rollback user creation or not?
```

### ❌ 3. Circular Dependencies
```python
# BAD
class OrderService:
    def __init__(self, user_service: UserService):
        self.user_service = user_service

class UserService:
    def __init__(self, order_service: OrderService):
        self.order_service = order_service
    # Can't instantiate either!
```

**Better:** Introduce abstraction layer or reorganize.

### ❌ 4. Leaky Abstractions
```python
# BAD
class Repository:
    def query_with_sql(self, sql: str):  # Exposes SQL
        return db.execute(sql)

# Client code
results = repo.query_with_sql("SELECT * FROM users WHERE ...")
```

**Better:**
```python
class UserRepository:
    async def find_by_email(self, email: str) -> User:
        # Implementation hidden
        return ...
```

---

## Key Takeaways

1. **Use cases** guide architecture from requirements down to code structure
2. **Choose pattern** (ActiveRecord vs Data Mapper) based on project size
3. **Invert dependencies** to decouple high-level code from low-level details
4. **Use DI** to make dependencies explicit and testable
5. **Avoid leaky abstractions** — hide implementation details behind clear contracts
6. **Identifiable layers:** HTTP adapter → Service/Interactor → Repository → DB

---

## References

- **Post #77:** Use Cases & Interactors
- **Post #72:** State Management in DB
- **Post #66:** Database Patterns
- **Post #68:** Dependency Inversion Principle
- **Post #74:** SQLAlchemy & ORM
- **Post #60:** Unit of Work
- **Martin Fowler:** [DIP in the Wild](https://martinfowler.com/articles/dipInTheWild.html)
- **Robert Martin:** [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2011/11/22/Clean-Architecture.html)

---

## Next Skills to Pair With

- `python-code-quality-fundamentals` — SOLID principles beyond DIP
- `python-database-patterns` — Deep dive into ORM & migrations
- `python-testing-and-mocks` — Testing with dependency injection
