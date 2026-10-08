# LangGraph Runtime Agents (User-Facing)

The agents Stefan's app USERS interact with. Production Python, LangGraph. Load when Stefan builds or designs runtime agent features. Distinct from the build-time dev team - different constraints (user latency, reliability, per-request cost, not Stefan's build budget).

## Pattern selection (don't over-build)

The honest default first: **most "multi-agent" systems should be a single well-prompted agent with good tools.** A supervisor costs ~3x a single mega-agent (every supervisor turn is a full LLM call). Reach for multi-agent only when a single agent's tool count gets large enough that quality collapses.

When multi-agent is justified, LangGraph gives three patterns:
- **Supervisor** (default, most production-common): a router node owns the conversation, dispatches to specialist worker nodes, workers return to supervisor, supervisor synthesizes. Best when subtasks separate cleanly (e.g. retrieve / reason / write / verify)
- **Swarm** (decentralized): peers hand off directly; use only when a central router is a genuine bottleneck
- **Hierarchical**: supervisor-of-supervisors; only when a flat supervisor with 3-4 workers is provably insufficient. Resist until then

Start with one supervisor + two or three workers. Add hierarchy only when the flat version breaks.

## Core principle
LLMs decide WHAT to do; deterministic code decides HOW. Keep routing/reasoning in the LLM nodes and push execution into plain tools/functions - it's cheaper, more reliable, and testable.

## State management (where production actually breaks)
Field data ties a majority of production incidents to state management. So:
- Define an explicit **State schema** (typed) - never an untyped dict growing organically
- Use **reducers** deliberately for how concurrent node writes merge (append vs overwrite) - concurrent writes to one key without a reducer is the classic corruption bug
- **Checkpointing/persistence** (e.g. Redis-backed) for thread state and failure recovery - so a crash mid-run resumes instead of restarting
- Shared state lives in the store, not in every agent's context window - each agent loads only the slice it needs
- **Circuit breaker** on supervisor loops: a max-iterations guard so a mis-routing loop can't run forever (and can't run up an unbounded bill)

## Model routing (runtime)
- Supervisor: frontier model (needs reasoning to route correctly)
- Workers/reflectors/validators: cheaper model (they execute or verify against a spec) - this split cuts runtime cost ~60-70% with negligible routing-quality impact
- Cap concurrency to respect API rate limits

## Observability
Wire tracing (LangSmith or self-hosted equivalent) on day one - not after it breaks. Multi-agent failures are near-impossible to debug blind.

## Cost sanity
Before committing to a supervisor architecture, verify a single agent genuinely can't do it. Teams routinely add supervisors to 2-agent pipelines and triple cost for nothing. For dependent 2-step work, a sequential pipeline with a terminal reviewer beats a supervisor.

## Comment & learning note
Same Stefan rule: heavy pedagogical comments. LangGraph's node/edge/state wiring is exactly where he's learning - annotate the graph construction, the state schema, and every reducer choice with the WHY.

## Interaction with build-time team
The dev team (agent-dev-team.md) BUILDS these runtime agents. When Stefan builds a LangGraph feature via Claude Code, the backend/testing/security dev-team agents produce and validate this runtime code - the two layers meet here but stay conceptually separate.
