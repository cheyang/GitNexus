# docker-pack.sh — 基于 Docker 的 npm Tarball 构建工具

完全在 Docker 内构建 GitNexus npm 安装包（`.tgz`）— 本机无需安装 Node.js、Python 或 C++ 编译器。

---

## 前置条件

- Docker 20.10+
- Git（用于克隆仓库）

就这些。不需要 Node.js，不需要 npm，不需要任何构建工具链。

---

## 快速开始

```bash
git clone https://github.com/cheyang/GitNexus.git
cd GitNexus

./docker-pack.sh
```

输出：

```
dist-pack/
├── gitnexus-1.6.8.tgz    # 安装命令: npm install -g ./dist-pack/gitnexus-1.6.8.tgz
└── manifest.json          # 构建元信息（名称、版本、大小、时间戳）
```

---

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--skip-grammars` | 跳过可选的 tree-sitter 语法（Dart/Proto/Swift/Kotlin） | 构建全部 |
| `--skip-web` | 跳过 Web UI 构建（更小的包，`gitnexus serve` 无浏览器界面） | 包含 Web UI |
| `--platform PLATFORM` | Docker 构建平台（如 `linux/amd64`、`linux/arm64`） | 宿主机平台 |
| `--output, -o DIR` | tarball 输出目录 | `./dist-pack` |
| `--version, -v VER` | 覆盖包版本号 | package.json 中的当前版本 |
| `--name, -n NAME` | 覆盖包名（如 `@cheyang/gitnexus`） | `gitnexus` |
| `--node VERSION` | 使用的 Node.js 主版本号 | `22` |
| `--no-cache` | 不使用 Docker 构建缓存 | 使用缓存 |
| `-h, --help` | 显示帮助 | — |

---

## 使用示例

### 默认构建（完整包）

```bash
./docker-pack.sh
```

构建所有内容：全部 16 种语言语法 + Web UI。最大的 tarball，完整功能。

### 最小化构建（仅 CLI + MCP）

```bash
./docker-pack.sh --skip-grammars --skip-web
```

跳过可选语法和 Web UI。最快构建、最小体积。仍然包含完整的 CLI + MCP，支持 TypeScript、JavaScript、Python、Java、C#、Go、Rust、PHP、Ruby、C、C++。

### 自定义版本和包名

```bash
./docker-pack.sh --name @myorg/gitnexus --version 2.0.0
```

适用于将 fork 发布到私有 Registry。

### 跨平台构建

```bash
# 在 Mac 上构建 Linux ARM64 版本（部署到 ARM 服务器）
./docker-pack.sh --platform linux/arm64

# 构建 Linux AMD64 版本
./docker-pack.sh --platform linux/amd64
```

### 自定义输出目录

```bash
./docker-pack.sh --output /tmp/release
# → /tmp/release/gitnexus-1.6.8.tgz
```

### 全新构建（不用 Docker 缓存）

```bash
./docker-pack.sh --no-cache
```

排查构建问题或确保完全可复现时使用。

### 组合使用

```bash
./docker-pack.sh \
    --name @cheyang/gitnexus \
    --version 2.0.0 \
    --skip-grammars \
    --skip-web \
    --output ./release \
    --no-cache
```

---

## 安装 Tarball

在任何安装了 Node.js 22+ 的机器上：

```bash
npm install -g ./dist-pack/gitnexus-1.6.8.tgz

# 验证
gitnexus --version
gitnexus --help
```

### 离线/气隙环境安装

```bash
# 1. 在有 Docker + 网络的机器上构建
./docker-pack.sh

# 2. 传输 tarball（U 盘、scp、共享盘）
scp dist-pack/gitnexus-1.6.8.tgz user@target:/tmp/

# 3. 在目标机器上安装（仅需 Node.js 22+）
ssh user@target
npm install -g /tmp/gitnexus-1.6.8.tgz
```

---

## 构建产物

### Tarball 内容

`.tgz` 仅包含 `package.json` 中 `files` 字段声明的文件：

```
package/
├── dist/          # 编译后的 JavaScript（CLI、MCP 服务器、核心逻辑）
├── hooks/         # Claude Code / Cursor hooks
├── scripts/       # 安装时脚本（tree-sitter 语法构建）
├── skills/        # AI agent 技能模板
├── vendor/        # 预编译的 tree-sitter 语法（平台二进制文件）
└── web/           # Web UI 静态文件（如果未跳过）
```

### manifest.json

```json
{
  "name": "gitnexus",
  "version": "1.6.8",
  "file": "gitnexus-1.6.8.tgz",
  "size": 52428800,
  "sizeHuman": "50.00 MB",
  "node": "v22.x.x",
  "platform": "linux",
  "arch": "x64",
  "builtAt": "2026-06-25T12:00:00.000Z"
}
```

---

## 工作原理

脚本动态生成并运行一个多阶段 Dockerfile：

```
┌─────────────────────────────────────────────────────┐
│  阶段 1: builder (node:22-bookworm-slim)            │
│                                                     │
│  1. 安装工具链 (python3, make, g++, git, jq)        │
│  2. 复制源代码                                       │
│  3. 构建 gitnexus-shared (TypeScript → JS)          │
│  4. 构建 gitnexus-web (Vite, 如未跳过)              │
│  5. 构建 gitnexus (TypeScript → JS + 原生依赖)      │
│  6. 覆盖版本号/包名 (如有指定)                       │
│  7. npm pack → .tgz                                 │
│  8. 生成 manifest.json                              │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  阶段 2: scratch (空镜像)                            │
│                                                     │
│  仅包含: .tgz + manifest.json                       │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  宿主机: docker cp → ./dist-pack/                   │
│                                                     │
│  从 scratch 容器中提取产物                           │
└─────────────────────────────────────────────────────┘
```

最终阶段使用 `FROM scratch`（空镜像），构建器镜像可安全丢弃。不会留下悬挂的 Docker 镜像。

---

## CI/CD 集成

### GitHub Actions

```yaml
name: Build Tarball
on:
  push:
    tags: ['v*']

jobs:
  pack:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build tarball
        run: ./docker-pack.sh --output ./artifacts

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: gitnexus-tarball
          path: artifacts/*.tgz
```

### GitLab CI

```yaml
build-tarball:
  image: docker:latest
  services:
    - docker:dind
  script:
    - ./docker-pack.sh --output ./artifacts
  artifacts:
    paths:
      - artifacts/*.tgz
```

---

## 常见问题

### 构建失败："COPY failed: file not found"

确保从仓库根目录运行脚本（即 `gitnexus/`、`gitnexus-shared/`、`gitnexus-web/` 目录所在位置）：

```bash
cd /path/to/GitNexus
./docker-pack.sh
```

### 构建很慢

- 不需要浏览器 UI 时用 `--skip-web`
- 不需要 Dart/Proto/Swift/Kotlin 时用 `--skip-grammars`
- 后续构建因为 Docker 层缓存会更快
- 只有排查问题时才用 `--no-cache`

### 脚本报 "Permission denied"

```bash
chmod +x docker-pack.sh
```

### Docker daemon 未运行

```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker
```

### 平台不匹配警告

如果看到 "WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64)"，使用 `--platform` 显式指定目标平台：

```bash
./docker-pack.sh --platform linux/arm64
```
