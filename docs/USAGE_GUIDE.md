# GitNexus Usage Guide

## Table of Contents

- [Introduction](#introduction)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Editor Integration](#editor-integration)
- [CLI Commands](#cli-commands)
- [MCP Tools](#mcp-tools)
- [Web UI](#web-ui)
- [Multi-Repo Management](#multi-repo-management)
- [Advanced Features](#advanced-features)
- [Practical Scenarios](#practical-scenarios)
- [FAQ](#faq)

---

## Introduction

GitNexus indexes any codebase into a knowledge graph — capturing every dependency, call chain, functional cluster, and execution flow — then exposes it through MCP tools so AI coding agents (Cursor, Claude Code, Codex, etc.) gain true structural awareness instead of editing blind.

**Core value:** AI agents can see the full blast radius before modifying code, preventing breaking changes.

---

## Installation

### Global Install (Recommended)

```bash
npm install -g gitnexus
```

### Using npx (No Install Required)

```bash
npx gitnexus@latest analyze
```

### Skip Optional Grammars (No C++ Toolchain Needed)

```bash
GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm install -g gitnexus
```

> This skips native grammar builds for Dart, Proto, Swift, and Kotlin. All other languages remain unaffected.

### npm 11.x Workaround

If `npx` crashes on npm 11, use pnpm:

```bash
pnpm --allow-build=@ladybugdb/core --allow-build=gitnexus --allow-build=tree-sitter dlx gitnexus@latest analyze
```

---

## Quick Start

### Step 1: Index Your Repository

```bash
cd /path/to/your/project
gitnexus analyze
```

This single command does everything:
- Parses code structure (functions, classes, methods, interfaces)
- Resolves import/call/inheritance relationships
- Detects functional clusters
- Traces execution flows
- Installs AI agent skill files
- Registers Claude Code hooks
- Generates `AGENTS.md` / `CLAUDE.md` context files

### Step 2: Configure Editor MCP

```bash
gitnexus setup
```

Auto-detects installed editors and writes the correct MCP config. Run once only.

### Step 3: Start Using

Open your AI editor (Cursor, Claude Code, etc.) — it can now query your code knowledge graph through MCP tools.

---

## Editor Integration

### Claude Code (Full Support: MCP + Skills + Hooks)

```bash
# Auto-configure
gitnexus setup

# Manual setup (macOS / Linux)
claude mcp add gitnexus -- npx -y gitnexus@latest mcp

# Manual setup (Windows)
claude mcp add gitnexus -- cmd /c npx -y gitnexus@latest mcp
```

Claude Code gets the deepest integration:
- MCP tools (query / impact analysis / rename, etc.)
- Agent skill files
- PreToolUse hooks (auto-inject graph context during searches)
- PostToolUse hooks (detect stale index after commits)

### Cursor

Global config at `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "gitnexus": {
      "command": "npx",
      "args": ["-y", "gitnexus@latest", "mcp"]
    }
  }
}
```

### Codex

```bash
codex mcp add gitnexus -- npx -y gitnexus@latest mcp
```

### Windsurf

Add to Windsurf MCP config:

```json
{
  "mcpServers": {
    "gitnexus": {
      "command": "npx",
      "args": ["-y", "gitnexus@latest", "mcp"]
    }
  }
}
```

### Configure Specific Editors Only

```bash
gitnexus setup -c cursor,codex
```

---

## CLI Commands

### `gitnexus analyze` — Index a Repository

```bash
# Basic index
gitnexus analyze

# Force full rebuild
gitnexus analyze --force

# With embeddings (better semantic search, slower)
gitnexus analyze --embeddings

# Generate module skill files
gitnexus analyze --skills

# Skip embeddings (faster)
gitnexus analyze --skip-embeddings

# Preserve custom AGENTS.md/CLAUDE.md
gitnexus analyze --skip-agents-md

# Repair FTS indexes only
gitnexus analyze --repair-fts

# Index non-Git folders
gitnexus analyze --skip-git

# Increase worker timeout (large repos)
gitnexus analyze --worker-timeout 60

# Set worker count
gitnexus analyze --workers 8

# Verbose logging
gitnexus analyze --verbose
```

### `gitnexus status` — Check Index Status

```bash
gitnexus status
```

Shows index info for the current repo: last indexed commit, symbol count, relationship count, etc.

### `gitnexus list` — List All Indexed Repositories

```bash
gitnexus list
```

### `gitnexus serve` — Start HTTP Server

```bash
gitnexus serve
```

Starts a local HTTP server (port 4747) that the Web UI auto-connects to.

### `gitnexus clean` — Delete Index

```bash
# Delete index for current repo
gitnexus clean

# Delete all indexes
gitnexus clean --all --force
```

### `gitnexus wiki` — Generate Documentation

```bash
# Requires an LLM API key (OPENAI_API_KEY, etc.)
gitnexus wiki

# Specify model
gitnexus wiki --model gpt-4o

# Specify language
gitnexus wiki --lang chinese
```

### `gitnexus uninstall` — Remove Integrations

```bash
# Preview what will be removed
gitnexus uninstall

# Apply removal
gitnexus uninstall --force
```

---

## MCP Tools

After indexing, AI agents can query the knowledge graph through these tools:

### `query` — Smart Search

Process-grouped hybrid search (BM25 + semantic + RRF):

```
query({search_query: "user authentication"})
query({search_query: "database connection", repo: "my-app"})
```

Results are grouped by execution flow, with priority, symbol count, and step count.

### `context` — 360-Degree Symbol View

See the full context of any symbol (who calls it, what it calls, which processes it participates in):

```
context({name: "validateUser"})
```

Returns:
- Symbol info (file path, line number, type)
- Incoming relationships (callers / importers)
- Outgoing relationships (callees / imports)
- Participating execution flows

### `impact` — Blast Radius Analysis

Before modifying code, see what will be affected:

```
impact({target: "UserService", direction: "upstream"})
impact({target: "handleLogin", direction: "downstream", minConfidence: 0.8})
```

Parameters:
- `direction`: `upstream` (who depends on me) / `downstream` (what I depend on)
- `minConfidence`: minimum confidence threshold (0–1)
- `maxDepth`: maximum traversal depth
- `includeTests`: whether to include test files

### `detect_changes` — Git Change Impact Detection

Check which symbols and processes are affected before committing:

```
detect_changes({scope: "all"})
detect_changes({scope: "staged"})
```

### `rename` — Graph-Aware Rename

Multi-file rename powered by the call graph (far safer than find-and-replace):

```
rename({symbol_name: "validateUser", new_name: "verifyUser", dry_run: true})
```

Preview with `dry_run: true` first, then execute:

```
rename({symbol_name: "validateUser", new_name: "verifyUser", dry_run: false})
```

### `cypher` — Raw Graph Queries

Query the knowledge graph directly with Cypher:

```cypher
-- Find all symbols that call authentication functions
MATCH (c:Community {heuristicLabel: 'Authentication'})<-[:CodeRelation {type: 'MEMBER_OF'}]-(fn)
MATCH (caller)-[r:CodeRelation {type: 'CALLS'}]->(fn)
WHERE r.confidence > 0.8
RETURN caller.name, fn.name, r.confidence
ORDER BY r.confidence DESC
```

### `trace` — Path Trace Between Symbols

Find the shortest call path between two symbols:

```
trace({from: "handleRequest", to: "saveToDatabase"})
```

---

## Web UI

### Online Use

Visit [gitnexus.vercel.app](https://gitnexus.vercel.app) and connect to a local backend:

```bash
gitnexus serve
```

The browser auto-detects the local server and connects.

### Run Frontend Locally

```bash
git clone https://github.com/abhigyanpatwari/gitnexus.git
cd gitnexus/gitnexus-shared && npm install && npm run build
cd ../gitnexus-web && npm install
npm run dev
```

Start the backend in another terminal:

```bash
gitnexus serve
```

### Docker Deployment

```bash
docker compose up -d
```

- Server: `http://localhost:4747`
- Web UI: `http://localhost:4173`

Mount a local code directory:

```bash
WORKSPACE_DIR=$HOME/code docker compose up -d
docker compose exec gitnexus-server gitnexus index /workspace/my-repo
```

---

## Multi-Repo Management

GitNexus supports grouping multiple repositories for cross-repo contract matching and impact analysis.

### Create a Repository Group

```bash
gitnexus group create my-platform
```

### Add Repositories to a Group

```bash
gitnexus group add my-platform backend/auth auth-service
gitnexus group add my-platform backend/user user-service
gitnexus group add my-platform frontend/web web-app
```

### Sync Contracts

Extract HTTP endpoints from each repo and match consumer/provider relationships:

```bash
gitnexus group sync my-platform
```

### Cross-Repo Queries

```bash
gitnexus group query my-platform "user authentication flow"
```

### Using Groups in MCP

```
# Cross-repo search
query({search_query: "login", repo: "@my-platform"})

# Cross-repo impact analysis
impact({target: "UserService", repo: "@my-platform"})

# Cross-repo path trace
trace({from: "LoginButton", to: "saveSession", repo: "@my-platform"})
```

---

## Advanced Features

### Project Config File `.gitnexusrc`

Create a `.gitnexusrc` file at the repo root to persist common settings:

```json
{
  "defaultBranch": "develop",
  "embeddings": true,
  "workerTimeout": 60,
  "skipSkills": false
}
```

### Embedding Configuration

```bash
# Default 50,000-node safety cap
gitnexus analyze --embeddings

# Disable the cap
gitnexus analyze --embeddings 0

# Custom cap
gitnexus analyze --embeddings 100000
```

### PDG Analysis (Program Dependence Graph)

Enable control-flow / data-flow analysis (experimental):

```bash
gitnexus analyze --pdg
```

Once enabled, additional tools become available:
- `pdg_query` — control dependence and data-flow queries
- `explain` — taint analysis (source → sink data-flow tracking)

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GITNEXUS_WORKER_POOL_SIZE` | cores−1 | Worker thread count |
| `GITNEXUS_MAX_FILE_SIZE` | 512 KB | Max file size threshold |
| `GITNEXUS_VERBOSE` | unset | Verbose logging |
| `GITNEXUS_NO_GITIGNORE` | unset | Ignore .gitignore |

### Recommended Workflows

#### Before Modifying Code

```
1. impact({target: "symbol to modify", direction: "upstream"})
2. Review blast radius and risk level
3. If HIGH or CRITICAL, inform the user
4. Make changes
5. detect_changes({scope: "all"}) — verify impact matches expectations
```

#### Exploring Unfamiliar Code

```
1. query({search_query: "concept you want to learn"})  — find related execution flows
2. context({name: "key symbol"})  — view full context
3. Read gitnexus://repo/{name}/processes  — browse all flows
```

#### Safe Refactoring

```
1. Run impact analysis on all symbols to modify
2. Use the rename tool (not global find-and-replace)
3. Run detect_changes to verify scope
4. Commit
```

---

## Practical Scenarios

### Scenario 1: Onboarding to an Unfamiliar Project — "How does this project actually work?"

You've just joined a team and face a backend service with tens of thousands of lines of code. You need to understand the architecture quickly.

**Step 1: Index the project**

```bash
cd ~/projects/order-service
gitnexus analyze --embeddings --skills
```

**Step 2: Browse the architecture**

Ask your AI agent to read the global context:

```
# In Claude Code / Cursor
> Read gitnexus://repo/order-service/context and give me an overview
```

Returns: project stats (symbol count, relationship count), functional clusters, main execution flows.

**Step 3: Understand core execution flows**

```
query({search_query: "order creation flow"})
```

Returns process-grouped results, e.g.:

```
processes:
  - summary: "CreateOrderFlow"
    step_count: 12
    process_type: cross_community

process_symbols:
  - name: createOrder         (step 1, src/api/orders.ts)
  - name: validateInventory   (step 2, src/services/inventory.ts)
  - name: calculatePrice      (step 3, src/services/pricing.ts)
  - name: chargePayment       (step 4, src/services/payment.ts)
  - name: sendConfirmation    (step 5, src/services/notification.ts)
```

**Step 4: Dive into a specific module**

```
context({name: "chargePayment"})
```

Returns:
```
incoming calls: [createOrder, retryPayment, refundOrder]
outgoing calls: [stripeClient.charge, saveTransaction, emitPaymentEvent]
processes: CreateOrderFlow (step 4/12), RefundFlow (step 2/5)
```

**Takeaway:** In 10 minutes you know the core flows, module responsibilities, and dependency relationships — without reading files one by one.

---

### Scenario 2: Safely Modifying a Core Function — "Will this change break anything?"

You need to change the return type of `UserService.validate()`, but aren't sure how many places it will affect.

**Step 1: Impact analysis**

```
impact({target: "validate", direction: "upstream", minConfidence: 0.8})
```

Returns:
```
TARGET: Method UserService.validate (src/services/user.ts:45)

UPSTREAM (what depends on this):
  Depth 1 (WILL BREAK - confidence ≥ 0.9):
    handleLogin        [CALLS] -> src/api/auth.ts:23
    handleRegister     [CALLS] -> src/api/auth.ts:67
    resetPassword      [CALLS] -> src/api/password.ts:12
    UserController     [CALLS] -> src/controllers/user.ts:34

  Depth 2 (LIKELY AFFECTED):
    authRouter         [IMPORTS] -> src/routes/auth.ts
    passwordRouter     [IMPORTS] -> src/routes/password.ts

  Risk: HIGH (4 direct callers, 2 routes affected)
  Affected Processes: LoginFlow, RegistrationFlow, PasswordResetFlow
```

**Step 2: Inspect each caller's usage**

```
context({name: "handleLogin"})
```

Confirm how each caller uses the return value of `validate()`.

**Step 3: Modify and verify**

After making changes, run before committing:

```
detect_changes({scope: "staged"})
```

Returns:
```
summary:
  changed_count: 5
  affected_count: 4
  risk_level: medium  (dropped from HIGH — you handled the callers correctly)

changed_symbols: [validate, handleLogin, handleRegister, resetPassword, UserController]
affected_processes: [LoginFlow, RegistrationFlow, PasswordResetFlow]
```

Confirm the scope matches expectations, then commit safely.

---

### Scenario 3: Safe Rename — "I want to rename `getUserInfo` to `fetchUserProfile`"

Global find-and-replace can accidentally modify strings, comments, or identically-named but unrelated symbols.

**Step 1: Preview the rename**

```
rename({symbol_name: "getUserInfo", new_name: "fetchUserProfile", dry_run: true})
```

Returns:
```
status: success
files_affected: 7
total_edits: 14
graph_edits: 12     (call-graph-based, high confidence)
text_search_edits: 2  (text matches, review manually)

changes:
  - file: src/services/user.ts:23     [graph] function definition
  - file: src/api/profile.ts:45       [graph] call site
  - file: src/api/settings.ts:12      [graph] call site
  - file: src/controllers/admin.ts:78 [graph] call site
  - file: docs/api-reference.md:34    [text]  doc reference ⚠️ please verify
  - file: tests/user.test.ts:56       [text]  test description ⚠️ please verify
  ...
```

**Step 2: Confirm and execute**

Review the `text_search_edits` (items marked ⚠️), then:

```
rename({symbol_name: "getUserInfo", new_name: "fetchUserProfile", dry_run: false})
```

**Takeaway:** More accurate than IDE rename because it understands the cross-file call graph — it won't miss dynamic imports or deep dependencies.

---

### Scenario 4: Tracking Down a Bug — "Login sometimes returns 500, and I don't know where to start"

**Step 1: Search for related flows**

```
query({search_query: "login authentication error handling"})
```

Find the `LoginFlow` execution flow and related symbols.

**Step 2: Trace the full call chain**

```
trace({from: "loginHandler", to: "databaseQuery"})
```

Returns the complete path from entry point to data layer:
```
path:
  loginHandler (src/api/auth.ts:10)
    → validateCredentials (src/services/auth.ts:25)
      → findUserByEmail (src/repositories/user.ts:42)
        → databaseQuery (src/db/connection.ts:15)

hops: 3
```

**Step 3: Examine an intermediate node**

```
context({name: "findUserByEmail"})
```

Discover it's also called by `passwordReset` and `adminLookup`, but only the `loginHandler` path returns 500 — the problem may be in how `validateCredentials` handles the return value.

**Step 4: Zero in on the specific function**

```
context({name: "validateCredentials"})
```

See that it calls `findUserByEmail` and `checkPasswordHash`, and is step 2 of `LoginFlow`. Combined with reading the code, you discover that when the user doesn't exist it returns `null`, but there's no null check, causing a downstream crash.

---

### Scenario 5: Assessing PR Risk — "This PR changes 3 files. Is it risky?"

**Step 1: Detect change impact**

```
detect_changes({scope: "all"})
```

Returns:
```
summary:
  changed_count: 8       (8 symbols modified)
  affected_count: 23     (23 downstream symbols affected)
  changed_files: 3
  risk_level: high

changed_symbols:
  - PaymentService.charge    (src/services/payment.ts)
  - PaymentService.refund    (src/services/payment.ts)
  - TransactionModel.save    (src/models/transaction.ts)

affected_processes:
  - CreateOrderFlow (step 4, 5)
  - RefundFlow (step 2, 3, 4)
  - SubscriptionRenewalFlow (step 3)
```

**Step 2: Drill into the high-risk impact**

```
impact({target: "PaymentService.charge", direction: "upstream"})
```

Discover that `SubscriptionRenewalFlow` also depends on this method — something the PR author may not have considered.

**Takeaway:** During code review you can precisely point out: "You changed the `charge` method, but `SubscriptionRenewalFlow` also uses it — that needs verification."

---

### Scenario 6: Understanding Microservice Relationships — "Which service does this frontend API call ultimately reach?"

**Prerequisite:** Your Group is already configured with multiple repositories.

**Step 1: Cross-repo search**

```
query({search_query: "POST /api/orders", repo: "@my-platform"})
```

Find the route in the API Gateway and the handler in the Order Service.

**Step 2: View contract relationships**

```
group_contracts({name: "my-platform"})
```

Returns:
```
contracts:
  - provider: order-service
    endpoint: POST /api/orders
    handler: OrderController.create (src/controllers/order.ts:12)
    consumers:
      - web-app (src/api/orderClient.ts:34)
      - mobile-app (src/services/orderApi.ts:22)
```

**Step 3: Cross-repo trace**

```
trace({from: "OrderButton.onClick", to: "Order.save", repo: "@my-platform"})
```

Returns the full call path spanning frontend and backend:
```
path:
  OrderButton.onClick (web-app/src/components/Order.tsx:45)
    → orderApi.createOrder (web-app/src/api/orderClient.ts:34)
      ─── CONTRACT_LINK ───
    → OrderController.create (order-service/src/controllers/order.ts:12)
      → OrderService.processOrder (order-service/src/services/order.ts:56)
        → Order.save (order-service/src/models/order.ts:78)

crossings: [CONTRACT_LINK at orderApi → OrderController]
```

---

### Scenario 7: Custom Analysis with Cypher — "Find all exported functions that nobody calls"

```
cypher({
  query: `
    MATCH (f:Function)
    WHERE NOT EXISTS {
      MATCH ()-[r:CodeRelation {type: 'CALLS'}]->(f)
    }
    AND f.exported = true
    RETURN f.name, f.filePath, f.startLine
    ORDER BY f.filePath
    LIMIT 50
  `
})
```

**More Cypher examples:**

```cypher
-- Find the most complex classes (most methods)
MATCH (c:Class)-[r:CodeRelation {type: 'HAS_METHOD'}]->(m:Method)
RETURN c.name, c.filePath, count(m) AS method_count
ORDER BY method_count DESC
LIMIT 10

-- Find functions with the most cross-community callers (high coupling)
MATCH (caller)-[r:CodeRelation {type: 'CALLS'}]->(callee)
MATCH (caller)-[:CodeRelation {type: 'MEMBER_OF'}]->(c1:Community)
MATCH (callee)-[:CodeRelation {type: 'MEMBER_OF'}]->(c2:Community)
WHERE c1 <> c2
RETURN callee.name, callee.filePath, count(DISTINCT c1) AS caller_communities
ORDER BY caller_communities DESC
LIMIT 10

-- Find the deepest inheritance hierarchies
MATCH path = (child:Class)-[:CodeRelation {type: 'EXTENDS'}*1..10]->(ancestor:Class)
RETURN child.name, child.filePath, length(path) AS depth
ORDER BY depth DESC
LIMIT 10

-- Find circular dependencies (file-level)
MATCH (a:File)-[:CodeRelation {type: 'IMPORTS'}]->(b:File)-[:CodeRelation {type: 'IMPORTS'}]->(a)
RETURN a.filePath, b.filePath
```

---

### Scenario 8: New Feature Development — "I need to add email verification. Where do I start?"

**Step 1: Find related existing code**

```
query({search_query: "email verification send code"})
```

If similar functionality already exists, it returns related execution flows and symbols.

**Step 2: Examine the registration flow**

```
# Read process details
> Read gitnexus://repo/my-app/process/RegistrationFlow
```

Returns the full registration steps:
```
steps:
  1. handleRegister (src/api/auth.ts:67)
  2. validateInput (src/services/validation.ts:12)
  3. checkDuplicate (src/services/user.ts:89)
  4. hashPassword (src/services/auth.ts:45)
  5. createUser (src/repositories/user.ts:23)
  6. sendWelcomeEmail (src/services/email.ts:34)  ← here!
```

**Step 3: Examine the email service structure**

```
context({name: "sendWelcomeEmail"})
```

Discover that `src/services/email.ts` already has email-sending infrastructure you can reuse for verification codes.

**Step 4: Confirm your insertion point won't break existing flows**

```
impact({target: "EmailService", direction: "upstream"})
```

Confirm who currently uses the class you plan to extend, so your changes don't break existing functionality.

**Takeaway:** You know where to add code, how to reuse existing infrastructure, and which dependents to be careful about — without reading the entire project.

---

### Scenario 9: Automated Risk Assessment in CI/CD

Integrate GitNexus into your CI pipeline to automatically assess PR risk:

```yaml
# .github/workflows/risk-check.yml
name: Risk Assessment
on: pull_request

jobs:
  check-risk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - run: npm install -g gitnexus

      - name: Index and check
        run: |
          gitnexus analyze
          gitnexus detect-changes --json > risk-report.json

      - name: Comment on PR
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = JSON.parse(fs.readFileSync('risk-report.json'));
            const body = `## Risk Assessment
            - Changed symbols: ${report.changed_count}
            - Affected downstream: ${report.affected_count}
            - Risk level: **${report.risk_level}**
            - Affected processes: ${report.affected_processes.join(', ')}`;
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body
            });
```

---

### Scenario 10: Planning a Large-Scale Refactor — "We need to split this monolith into microservices"

**Step 1: View functional clusters**

```
> Read gitnexus://repo/monolith/clusters
```

Returns automatically detected functional communities:
```
clusters:
  - name: "Authentication" (cohesion: 0.92, 23 symbols)
  - name: "OrderProcessing" (cohesion: 0.88, 45 symbols)
  - name: "Payment" (cohesion: 0.85, 31 symbols)
  - name: "Notification" (cohesion: 0.91, 18 symbols)
  - name: "UserManagement" (cohesion: 0.79, 37 symbols)
  - name: "Inventory" (cohesion: 0.87, 28 symbols)
```

High-cohesion clusters (cohesion > 0.85) are natural microservice candidates.

**Step 2: Analyze cross-cluster coupling**

```cypher
-- Find all cross-boundary calls between two clusters
MATCH (a)-[:CodeRelation {type: 'MEMBER_OF'}]->(c1:Community {heuristicLabel: 'OrderProcessing'})
MATCH (b)-[:CodeRelation {type: 'MEMBER_OF'}]->(c2:Community {heuristicLabel: 'Payment'})
MATCH (a)-[r:CodeRelation {type: 'CALLS'}]->(b)
RETURN a.name, b.name, r.confidence
ORDER BY r.confidence DESC
```

Returns every interface that OrderProcessing calls in Payment — these are your future inter-service API boundaries.

**Step 3: Evaluate split risk**

```
impact({target: "PaymentService", direction: "upstream"})
```

Confirm which modules depend on Payment — after splitting, these direct method calls must become API calls.

**Takeaway:** Data-driven refactoring decisions — not intuition. The knowledge graph tells you where to cut and how big the impact will be.

---

### Scenario 11: Git Hooks Integration in Daily Development

GitNexus automatically registers hooks in Claude Code, providing a seamless safety net:

**PreToolUse Hook (Search Augmentation):**

When the AI agent uses grep/search, the hook automatically injects graph context so search results include execution flow and call relationship information.

**PostToolUse Hook (Staleness Detection):**

After the AI agent runs `git commit`, the hook automatically checks whether the index is stale:

```
⚠️ GitNexus index is stale (3 commits behind HEAD).
   Run `gitnexus analyze` to update.
```

**Recommended pre-commit habit:**

```bash
# In your AI agent
> Run detect_changes before committing to check impact scope

detect_changes({scope: "staged"})
# → Confirm changes match expectations, then commit
```

---

### Scenario 12: Generating Project Documentation — "Generate a Wiki for this project"

```bash
# Set your LLM API key
export OPENAI_API_KEY=sk-xxx

# Generate docs in English
gitnexus wiki

# Use a specific model
gitnexus wiki --model gpt-4o

# Generate in another language
gitnexus wiki --lang chinese

# Increase timeout for large repos
gitnexus wiki --timeout 120 --retries 5
```

The wiki generator:
1. Reads the graph structure from the index
2. Groups files into modules via LLM
3. Generates per-module documentation pages
4. Creates an overview page
5. All content cross-references the knowledge graph

Generated documentation is saved to `.gitnexus/wiki/`.

---

## FAQ

### Q: How long does indexing take?

Depends on repo size. Medium projects (~1,000 files) typically take 10–30 seconds. Large projects may take a few minutes.

### Q: Where is the index stored?

- Per-repo: `<repo>/.gitnexus/` (auto-gitignored)
- Global registry: `~/.gitnexus/registry.json`

### Q: How do I update the index?

```bash
gitnexus analyze
```

If there are no new commits, it auto-skips. Use `--force` to rebuild anyway.

### Q: Which languages are supported?

TypeScript, JavaScript, Python, Java, Kotlin, C#, Go, Rust, PHP, Ruby, Swift, C, C++, Dart, Vue, COBOL (16 total).

### Q: MCP startup times out. What do I do?

Install globally and let setup write an absolute-path config:

```bash
npm install -g gitnexus
gitnexus setup  # writes absolute-path config automatically
```

### Q: Do I need to configure MCP separately for each repo?

No. GitNexus uses a global registry — one MCP server serves all indexed repositories.

### Q: Does the Web UI upload my code?

No. The Web UI runs entirely in the browser (WASM). Your code never leaves your machine.

---

## Editor Support Matrix

| Editor | MCP | Skills | Hooks | Support Level |
|--------|-----|--------|-------|---------------|
| Claude Code | Yes | Yes | Yes | Full |
| Cursor | Yes | Yes | Yes | Full |
| Antigravity (Google) | Yes | Yes | Yes | Full |
| Codex | Yes | Yes | — | MCP + Skills |
| Windsurf | Yes | — | — | MCP |
| OpenCode | Yes | Yes | — | MCP + Skills |
