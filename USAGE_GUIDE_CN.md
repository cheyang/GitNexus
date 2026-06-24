# GitNexus 使用指南

## 目录

- [简介](#简介)
- [安装](#安装)
- [快速开始](#快速开始)
- [编辑器集成](#编辑器集成)
- [CLI 命令详解](#cli-命令详解)
- [MCP 工具使用](#mcp-工具使用)
- [Web UI](#web-ui)
- [多仓库管理](#多仓库管理)
- [高级功能](#高级功能)
- [实战场景示例](#实战场景示例)
- [常见问题](#常见问题)

---

## 简介

GitNexus 将任何代码仓库索引为知识图谱，捕获每个依赖关系、调用链、功能聚类和执行流程，然后通过 MCP 工具暴露给 AI 编程助手（Cursor、Claude Code、Codex 等），使它们能真正理解代码结构而不是盲目编辑。

**核心价值：** AI 助手在修改代码前能看到完整的影响范围（blast radius），避免破坏性变更。

---

## 安装

### 全局安装（推荐）

```bash
npm install -g gitnexus
```

### 使用 npx（无需安装）

```bash
npx gitnexus@latest analyze
```

### 跳过可选语法（无需 C++ 工具链）

```bash
GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm install -g gitnexus
```

> 这会跳过 Dart、Proto、Swift、Kotlin 的原生语法构建，其他语言不受影响。

### npm 11.x 问题解决

如果 `npx` 在 npm 11 下崩溃，使用 pnpm：

```bash
pnpm --allow-build=@ladybugdb/core --allow-build=gitnexus --allow-build=tree-sitter dlx gitnexus@latest analyze
```

---

## 快速开始

### 第一步：索引你的仓库

```bash
cd /path/to/your/project
gitnexus analyze
```

这一条命令完成以下所有操作：
- 解析代码结构（函数、类、方法、接口）
- 解析导入/调用/继承关系
- 检测功能聚类
- 追踪执行流程
- 安装 AI agent 技能文件
- 注册 Claude Code hooks
- 生成 `AGENTS.md` / `CLAUDE.md` 上下文文件

### 第二步：配置编辑器 MCP

```bash
gitnexus setup
```

自动检测已安装的编辑器并写入 MCP 配置。只需运行一次。

### 第三步：开始使用

打开你的 AI 编辑器（Cursor、Claude Code 等），它现在可以通过 MCP 工具查询你的代码知识图谱了。

---

## 编辑器集成

### Claude Code（完整支持：MCP + Skills + Hooks）

```bash
# 自动配置
gitnexus setup

# 手动配置（macOS / Linux）
claude mcp add gitnexus -- npx -y gitnexus@latest mcp

# 手动配置（Windows）
claude mcp add gitnexus -- cmd /c npx -y gitnexus@latest mcp
```

Claude Code 获得最深度集成：
- MCP 工具（查询/影响分析/重命名等）
- Agent 技能文件
- PreToolUse hooks（搜索时自动注入图谱上下文）
- PostToolUse hooks（commit 后检测索引是否过期）

### Cursor

全局配置 `~/.cursor/mcp.json`：

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

在 Windsurf MCP 配置中添加：

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

### 仅配置特定编辑器

```bash
gitnexus setup -c cursor,codex
```

---

## CLI 命令详解

### `gitnexus analyze` — 索引仓库

```bash
# 基本索引
gitnexus analyze

# 强制完整重建
gitnexus analyze --force

# 带嵌入向量（更好的语义搜索，较慢）
gitnexus analyze --embeddings

# 生成模块技能文件
gitnexus analyze --skills

# 跳过嵌入（更快）
gitnexus analyze --skip-embeddings

# 保留自定义的 AGENTS.md/CLAUDE.md
gitnexus analyze --skip-agents-md

# 仅修复 FTS 索引
gitnexus analyze --repair-fts

# 非 Git 仓库也能索引
gitnexus analyze --skip-git

# 增加 worker 超时（大型仓库）
gitnexus analyze --worker-timeout 60

# 指定 worker 数量
gitnexus analyze --workers 8

# 详细日志
gitnexus analyze --verbose
```

### `gitnexus status` — 查看索引状态

```bash
gitnexus status
```

显示当前仓库的索引信息：最后索引的 commit、符号数量、关系数量等。

### `gitnexus list` — 列出所有已索引仓库

```bash
gitnexus list
```

### `gitnexus serve` — 启动 HTTP 服务

```bash
gitnexus serve
```

启动本地 HTTP 服务器（端口 4747），Web UI 可自动连接。

### `gitnexus clean` — 删除索引

```bash
# 删除当前仓库索引
gitnexus clean

# 删除所有索引
gitnexus clean --all --force
```

### `gitnexus wiki` — 生成文档

```bash
# 需要 LLM API Key（OPENAI_API_KEY 等）
gitnexus wiki

# 指定模型
gitnexus wiki --model gpt-4o

# 指定语言
gitnexus wiki --lang chinese
```

### `gitnexus uninstall` — 卸载集成

```bash
# 预览要移除的内容
gitnexus uninstall

# 执行移除
gitnexus uninstall --force
```

---

## MCP 工具使用

索引完成后，AI 助手可通过以下工具查询知识图谱：

### `query` — 智能搜索

按执行流程分组的混合搜索（BM25 + 语义 + RRF）：

```
query({search_query: "用户认证"})
query({search_query: "database connection", repo: "my-app"})
```

返回结果按执行流程分组，包含优先级、符号数量、步骤数等。

### `context` — 360 度符号视图

查看某个符号的完整上下文（谁调用它、它调用谁、参与哪些流程）：

```
context({name: "validateUser"})
```

返回：
- 符号基本信息（文件路径、行号、类型）
- 入向关系（谁调用/导入了它）
- 出向关系（它调用/导入了谁）
- 参与的执行流程

### `impact` — 影响范围分析

修改代码前，先看看会影响什么：

```
impact({target: "UserService", direction: "upstream"})
impact({target: "handleLogin", direction: "downstream", minConfidence: 0.8})
```

参数说明：
- `direction`: `upstream`（谁依赖我）/ `downstream`（我依赖谁）
- `minConfidence`: 最低置信度（0-1）
- `maxDepth`: 最大追踪深度
- `includeTests`: 是否包含测试文件

### `detect_changes` — Git 变更影响检测

提交前检查变更影响了哪些符号和流程：

```
detect_changes({scope: "all"})
detect_changes({scope: "staged"})
```

### `rename` — 图谱感知的重命名

基于调用图的多文件重命名（比 find-and-replace 安全得多）：

```
rename({symbol_name: "validateUser", new_name: "verifyUser", dry_run: true})
```

先用 `dry_run: true` 预览，确认后再执行：

```
rename({symbol_name: "validateUser", new_name: "verifyUser", dry_run: false})
```

### `cypher` — 原始图查询

直接用 Cypher 查询知识图谱：

```cypher
-- 查找所有调用认证函数的符号
MATCH (c:Community {heuristicLabel: 'Authentication'})<-[:CodeRelation {type: 'MEMBER_OF'}]-(fn)
MATCH (caller)-[r:CodeRelation {type: 'CALLS'}]->(fn)
WHERE r.confidence > 0.8
RETURN caller.name, fn.name, r.confidence
ORDER BY r.confidence DESC
```

### `trace` — 符号间路径追踪

查找两个符号之间的最短调用路径：

```
trace({from: "handleRequest", to: "saveToDatabase"})
```

---

## Web UI

### 在线使用

访问 [gitnexus.vercel.app](https://gitnexus.vercel.app)，配合本地后端使用：

```bash
gitnexus serve
```

浏览器会自动检测本地服务器并连接。

### 本地运行前端

```bash
git clone https://github.com/abhigyanpatwari/gitnexus.git
cd gitnexus/gitnexus-shared && npm install && npm run build
cd ../gitnexus-web && npm install
npm run dev
```

另一个终端启动后端：

```bash
gitnexus serve
```

### Docker 部署

```bash
docker compose up -d
```

- 服务端：`http://localhost:4747`
- Web UI：`http://localhost:4173`

挂载本地代码目录：

```bash
WORKSPACE_DIR=$HOME/code docker compose up -d
docker compose exec gitnexus-server gitnexus index /workspace/my-repo
```

---

## 多仓库管理

GitNexus 支持将多个仓库组成一个 Group，实现跨仓库的合约匹配和影响分析。

### 创建仓库组

```bash
gitnexus group create my-platform
```

### 添加仓库到组

```bash
gitnexus group add my-platform backend/auth auth-service
gitnexus group add my-platform backend/user user-service
gitnexus group add my-platform frontend/web web-app
```

### 同步合约

提取各仓库的 HTTP 接口并匹配消费者/生产者关系：

```bash
gitnexus group sync my-platform
```

### 跨仓库查询

```bash
gitnexus group query my-platform "user authentication flow"
```

### 在 MCP 中使用 Group

```
# 跨仓库搜索
query({search_query: "login", repo: "@my-platform"})

# 跨仓库影响分析
impact({target: "UserService", repo: "@my-platform"})

# 跨仓库路径追踪
trace({from: "LoginButton", to: "saveSession", repo: "@my-platform"})
```

---

## 高级功能

### 项目配置文件 `.gitnexusrc`

在仓库根目录创建 `.gitnexusrc` 文件，持久化常用配置：

```json
{
  "defaultBranch": "develop",
  "embeddings": true,
  "workerTimeout": 60,
  "skipSkills": false
}
```

### 嵌入向量配置

```bash
# 默认 50000 节点安全上限
gitnexus analyze --embeddings

# 取消上限
gitnexus analyze --embeddings 0

# 自定义上限
gitnexus analyze --embeddings 100000
```

### PDG 分析（程序依赖图）

启用控制流/数据流分析（实验性）：

```bash
gitnexus analyze --pdg
```

启用后可使用：
- `pdg_query` — 控制依赖和数据流查询
- `explain` — 污点分析（source→sink 数据流追踪）

### 环境变量

| 变量 | 默认值 | 用途 |
|------|--------|------|
| `GITNEXUS_WORKER_POOL_SIZE` | cores-1 | Worker 线程数 |
| `GITNEXUS_MAX_FILE_SIZE` | 512 KB | 文件大小上限 |
| `GITNEXUS_VERBOSE` | unset | 详细日志 |
| `GITNEXUS_NO_GITIGNORE` | unset | 忽略 .gitignore |

### 推荐工作流

#### 修改代码前

```
1. impact({target: "要修改的符号", direction: "upstream"})
2. 检查影响范围和风险等级
3. 如果是 HIGH/CRITICAL，告知用户
4. 进行修改
5. detect_changes({scope: "all"}) 验证影响符合预期
```

#### 探索陌生代码

```
1. query({search_query: "你想了解的概念"})  — 找到相关执行流程
2. context({name: "关键符号"})  — 查看完整上下文
3. 阅读 gitnexus://repo/{name}/processes  — 浏览所有流程
```

#### 安全重构

```
1. impact 分析所有要修改的符号
2. 使用 rename 工具进行重命名（而非全局替换）
3. detect_changes 验证变更范围
4. 提交代码
```

---

## 实战场景示例

### 场景 1：接手陌生项目 — "这个项目是怎么跑起来的？"

你刚加入团队，面对一个几万行代码的后端服务，需要快速理解整体架构。

**第一步：索引项目**

```bash
cd ~/projects/order-service
gitnexus analyze --embeddings --skills
```

**第二步：浏览整体架构**

让 AI 助手读取全局上下文：

```
# 在 Claude Code / Cursor 中询问
> 读取 gitnexus://repo/order-service/context 告诉我这个项目概况
```

返回：项目统计（符号数量、关系数量）、功能聚类、主要执行流程。

**第三步：了解核心执行流程**

```
query({search_query: "order creation flow"})
```

返回按流程分组的结果，例如：

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

**第四步：深入某个模块**

```
context({name: "chargePayment"})
```

返回：
```
incoming calls: [createOrder, retryPayment, refundOrder]
outgoing calls: [stripeClient.charge, saveTransaction, emitPaymentEvent]
processes: CreateOrderFlow (step 4/12), RefundFlow (step 2/5)
```

**收获：** 10 分钟内你就知道了这个服务的核心流程、各模块职责和依赖关系，而不用逐文件阅读代码。

---

### 场景 2：安全修改核心函数 — "改了它会不会炸？"

你需要修改 `UserService.validate()` 的返回类型，但不确定会影响多少地方。

**第一步：影响分析**

```
impact({target: "validate", direction: "upstream", minConfidence: 0.8})
```

返回：
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

**第二步：逐个检查调用方式**

```
context({name: "handleLogin"})
```

确认每个调用者如何使用 `validate()` 的返回值。

**第三步：修改并验证**

修改完成后，提交前运行：

```
detect_changes({scope: "staged"})
```

返回：
```
summary:
  changed_count: 5
  affected_count: 4
  risk_level: medium  (从 HIGH 降到 medium，说明你正确处理了)

changed_symbols: [validate, handleLogin, handleRegister, resetPassword, UserController]
affected_processes: [LoginFlow, RegistrationFlow, PasswordResetFlow]
```

确认影响范围符合预期，安全提交。

---

### 场景 3：安全重命名 — "我想把 `getUserInfo` 改成 `fetchUserProfile`"

全局 find-and-replace 容易误改字符串、注释、或同名不同义的符号。

**第一步：预览重命名**

```
rename({symbol_name: "getUserInfo", new_name: "fetchUserProfile", dry_run: true})
```

返回：
```
status: success
files_affected: 7
total_edits: 14
graph_edits: 12     (基于调用图，高置信度)
text_search_edits: 2  (文本匹配，需人工确认)

changes:
  - file: src/services/user.ts:23     [graph] 函数定义
  - file: src/api/profile.ts:45       [graph] 调用处
  - file: src/api/settings.ts:12      [graph] 调用处
  - file: src/controllers/admin.ts:78 [graph] 调用处
  - file: docs/api-reference.md:34    [text]  文档引用 ⚠️ 请确认
  - file: tests/user.test.ts:56       [text]  测试描述 ⚠️ 请确认
  ...
```

**第二步：确认并执行**

检查 `text_search_edits`（标 ⚠️ 的项），确认无误后：

```
rename({symbol_name: "getUserInfo", new_name: "fetchUserProfile", dry_run: false})
```

**收获：** 比 IDE 的重命名更准确，因为它理解跨文件的调用图，不会漏改动态导入或深层依赖。

---

### 场景 4：定位 Bug — "用户登录有时返回 500，但我不知道从哪查起"

**第一步：搜索相关流程**

```
query({search_query: "login authentication error handling"})
```

找到 `LoginFlow` 执行流程及相关符号。

**第二步：追踪完整调用链**

```
trace({from: "loginHandler", to: "databaseQuery"})
```

返回从入口到数据层的完整路径：
```
path:
  loginHandler (src/api/auth.ts:10)
    → validateCredentials (src/services/auth.ts:25)
      → findUserByEmail (src/repositories/user.ts:42)
        → databaseQuery (src/db/connection.ts:15)

hops: 3
```

**第三步：查看中间节点的完整上下文**

```
context({name: "findUserByEmail"})
```

发现它还被 `passwordReset` 和 `adminLookup` 调用，但只有 `loginHandler` 路径报 500 — 问题可能在 `validateCredentials` 对返回值的处理上。

**第四步：定位到具体函数**

```
context({name: "validateCredentials"})
```

看到它调用了 `findUserByEmail` 和 `checkPasswordHash`，并且参与 `LoginFlow` 的第 2 步。结合代码，发现当用户不存在时返回 `null`，但没有 null check 导致后续调用报错。

---

### 场景 5：评估 PR 风险 — "这个 PR 改了 3 个文件，风险大吗？"

**第一步：检测变更影响**

```
detect_changes({scope: "all"})
```

返回：
```
summary:
  changed_count: 8       (修改了 8 个符号)
  affected_count: 23     (影响了 23 个下游符号)
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

**第二步：重点检查高风险影响**

```
impact({target: "PaymentService.charge", direction: "upstream"})
```

发现 `SubscriptionRenewalFlow` 也依赖这个方法 — PR 作者可能没考虑到。

**收获：** 在 Code Review 时能精确指出"你改了 `charge` 方法，但 `SubscriptionRenewalFlow` 也在用它，需要验证"。

---

### 场景 6：理解微服务间关系 — "前端调的这个 API 最终走到了哪个服务？"

**前提：** 你的 Group 已配置好多个仓库。

**第一步：跨仓库搜索**

```
query({search_query: "POST /api/orders", repo: "@my-platform"})
```

找到 API Gateway 中的路由和 Order Service 中的 handler。

**第二步：查看合约关系**

```
group_contracts({name: "my-platform"})
```

返回：
```
contracts:
  - provider: order-service
    endpoint: POST /api/orders
    handler: OrderController.create (src/controllers/order.ts:12)
    consumers:
      - web-app (src/api/orderClient.ts:34)
      - mobile-app (src/services/orderApi.ts:22)
```

**第三步：跨仓库追踪**

```
trace({from: "OrderButton.onClick", to: "Order.save", repo: "@my-platform"})
```

返回跨越前端和后端的完整调用路径：
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

### 场景 7：用 Cypher 做自定义分析 — "找出所有没被任何人调用的公共函数"

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

**更多 Cypher 示例：**

```cypher
-- 找出最复杂的类（方法最多）
MATCH (c:Class)-[r:CodeRelation {type: 'HAS_METHOD'}]->(m:Method)
RETURN c.name, c.filePath, count(m) AS method_count
ORDER BY method_count DESC
LIMIT 10

-- 找出跨社区调用最多的函数（耦合度高）
MATCH (caller)-[r:CodeRelation {type: 'CALLS'}]->(callee)
MATCH (caller)-[:CodeRelation {type: 'MEMBER_OF'}]->(c1:Community)
MATCH (callee)-[:CodeRelation {type: 'MEMBER_OF'}]->(c2:Community)
WHERE c1 <> c2
RETURN callee.name, callee.filePath, count(DISTINCT c1) AS caller_communities
ORDER BY caller_communities DESC
LIMIT 10

-- 找出继承层次最深的类
MATCH path = (child:Class)-[:CodeRelation {type: 'EXTENDS'}*1..10]->(ancestor:Class)
RETURN child.name, child.filePath, length(path) AS depth
ORDER BY depth DESC
LIMIT 10

-- 找出循环依赖（文件级）
MATCH (a:File)-[:CodeRelation {type: 'IMPORTS'}]->(b:File)-[:CodeRelation {type: 'IMPORTS'}]->(a)
RETURN a.filePath, b.filePath
```

---

### 场景 8：新功能开发 — "我要加一个邮件验证功能，从哪里入手？"

**第一步：找到相关现有代码**

```
query({search_query: "email verification send code"})
```

如果已有类似功能，会返回相关执行流程和符号。

**第二步：查看注册流程**

```
# 读取流程详情
> 读取 gitnexus://repo/my-app/process/RegistrationFlow
```

返回完整的注册步骤：
```
steps:
  1. handleRegister (src/api/auth.ts:67)
  2. validateInput (src/services/validation.ts:12)
  3. checkDuplicate (src/services/user.ts:89)
  4. hashPassword (src/services/auth.ts:45)
  5. createUser (src/repositories/user.ts:23)
  6. sendWelcomeEmail (src/services/email.ts:34)  ← 这里！
```

**第三步：查看邮件服务的结构**

```
context({name: "sendWelcomeEmail"})
```

发现 `src/services/email.ts` 已有邮件发送基础设施，你可以复用它来实现验证码发送。

**第四步：确认添加代码的位置不会破坏现有流程**

```
impact({target: "EmailService", direction: "upstream"})
```

确认你要扩展的类目前的使用者，避免修改影响已有功能。

**收获：** 不用读遍整个项目就知道在哪加代码、如何复用现有基础设施，以及需要注意哪些现有的依赖者。

---

### 场景 9：CI/CD 中自动风险评估

在 CI pipeline 中集成 GitNexus，自动评估 PR 风险：

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
          # 检测本次 PR 的变更影响
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

### 场景 10：大规模重构规划 — "我们要把单体拆成微服务"

**第一步：查看功能聚类**

```
> 读取 gitnexus://repo/monolith/clusters
```

返回自动检测到的功能社区：
```
clusters:
  - name: "Authentication" (cohesion: 0.92, 23 symbols)
  - name: "OrderProcessing" (cohesion: 0.88, 45 symbols)
  - name: "Payment" (cohesion: 0.85, 31 symbols)
  - name: "Notification" (cohesion: 0.91, 18 symbols)
  - name: "UserManagement" (cohesion: 0.79, 37 symbols)
  - name: "Inventory" (cohesion: 0.87, 28 symbols)
```

高内聚度（cohesion > 0.85）的聚类是天然的微服务候选。

**第二步：分析聚类间耦合**

```cypher
-- 找出两个聚类之间的跨边界调用
MATCH (a)-[:CodeRelation {type: 'MEMBER_OF'}]->(c1:Community {heuristicLabel: 'OrderProcessing'})
MATCH (b)-[:CodeRelation {type: 'MEMBER_OF'}]->(c2:Community {heuristicLabel: 'Payment'})
MATCH (a)-[r:CodeRelation {type: 'CALLS'}]->(b)
RETURN a.name, b.name, r.confidence
ORDER BY r.confidence DESC
```

返回 OrderProcessing 调用 Payment 的所有接口 — 这些是未来微服务间的 API 边界。

**第三步：评估拆分风险**

```
impact({target: "PaymentService", direction: "upstream"})
```

确认哪些模块依赖 Payment，拆分后需要通过 API 调用替代直接方法调用。

**收获：** 数据驱动的重构决策 — 不靠直觉，靠知识图谱告诉你哪里该切、切完影响多大。

---

### 场景 11：每日开发中的 Git Hooks 集成

GitNexus 在 Claude Code 中自动注册 hooks，提供无感知的安全网：

**PreToolUse Hook（搜索增强）：**

当 AI 助手使用 grep/search 时，hook 自动注入图谱上下文，让搜索结果带有执行流程和调用关系信息。

**PostToolUse Hook（过期检测）：**

当 AI 助手执行 `git commit` 后，hook 自动检查索引是否过期，提示重新索引：

```
⚠️ GitNexus index is stale (3 commits behind HEAD).
   Run `gitnexus analyze` to update.
```

**推荐的 commit 前检查习惯：**

```bash
# 在 AI 助手中
> 提交前帮我运行 detect_changes 检查影响范围

detect_changes({scope: "staged"})
# → 确认变更符合预期后再 commit
```

---

### 场景 12：生成项目文档 — "给这个项目生成一份 Wiki"

```bash
# 设置 LLM API Key
export OPENAI_API_KEY=sk-xxx

# 生成中文文档
gitnexus wiki --lang chinese

# 或指定模型
gitnexus wiki --model gpt-4o --lang chinese

# 大型仓库可增加超时
gitnexus wiki --timeout 120 --retries 5
```

Wiki 生成器会：
1. 读取索引中的图结构
2. 通过 LLM 将文件分组为模块
3. 为每个模块生成文档页面
4. 创建总览页面
5. 所有内容带有知识图谱的交叉引用

生成的文档在 `.gitnexus/wiki/` 目录下。

---

## 常见问题

### Q: 索引需要多长时间？

取决于仓库大小。中型项目（~1000 文件）通常 10-30 秒。大型项目可能需要几分钟。

### Q: 索引存在哪里？

- 仓库级：`<repo>/.gitnexus/`（已自动 gitignore）
- 全局注册表：`~/.gitnexus/registry.json`

### Q: 如何更新索引？

```bash
gitnexus analyze
```

如果代码没有新 commit，会自动跳过。用 `--force` 强制重建。

### Q: 支持哪些语言？

TypeScript, JavaScript, Python, Java, Kotlin, C#, Go, Rust, PHP, Ruby, Swift, C, C++, Dart, Vue, COBOL（共 16 种）。

### Q: MCP 启动超时怎么办？

推荐全局安装后使用绝对路径配置：

```bash
npm install -g gitnexus
gitnexus setup  # 自动写入绝对路径配置
```

### Q: 多仓库需要配置多次 MCP 吗？

不需要。GitNexus 使用全局注册表，一个 MCP 服务器可以服务所有已索引仓库。

### Q: Web UI 是否上传代码？

不会。Web UI 完全在浏览器中运行（WASM），代码不离开本地。

---

## 支持的编辑器对照表

| 编辑器 | MCP | Skills | Hooks | 支持程度 |
|--------|-----|--------|-------|----------|
| Claude Code | Yes | Yes | Yes | 完整 |
| Cursor | Yes | Yes | Yes | 完整 |
| Antigravity (Google) | Yes | Yes | Yes | 完整 |
| Codex | Yes | Yes | — | MCP + Skills |
| Windsurf | Yes | — | — | MCP |
| OpenCode | Yes | Yes | — | MCP + Skills |
