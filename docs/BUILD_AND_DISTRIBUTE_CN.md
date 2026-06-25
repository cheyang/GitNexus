# 自构建与分发 GitNexus npm 包

本文档详细说明如何从源码构建 GitNexus npm 包，并通过多种方式分发和安装。

---

## 目录

- [前置条件](#前置条件)
- [从源码构建](#从源码构建)
  - [方式 A：本地构建](#方式-a本地构建)
  - [方式 B：通过 Docker 构建](#方式-b通过-docker-构建)
- [分发方式](#分发方式)
  - [方式一：本地 tarball 安装](#方式一本地-tarball-安装)
  - [方式二：发布到私有 npm Registry](#方式二发布到私有-npm-registry)
  - [方式三：直接从 Git 仓库安装](#方式三直接从-git-仓库安装)
  - [方式四：发布到公共 npm Registry](#方式四发布到公共-npm-registry)
- [自定义构建](#自定义构建)
  - [修改包名和版本号](#修改包名和版本号)
  - [跳过 Web UI 构建](#跳过-web-ui-构建)
  - [跳过可选语法](#跳过可选语法)
- [Docker 镜像构建](#docker-镜像构建)
- [CI/CD 自动发布](#cicd-自动发布)
- [验证安装](#验证安装)
- [常见问题](#常见问题)

---

## 前置条件

| 工具 | 最低版本 | 用途 |
|------|---------|------|
| Node.js | 22.0.0 | 运行时 |
| npm | 10.x+ | 包管理 |
| Git | 2.x | 源码获取 |
| Python 3 | 3.8+ | 部分 tree-sitter 语法的原生编译（可选） |
| C++ 编译器 | gcc/clang/MSVC | 原生依赖编译（可选） |

> 如果不需要 Dart/Proto/Swift/Kotlin 语言支持，可以跳过 Python 和 C++ 编译器。

---

## 从源码构建

提供两种构建方式：**本地构建**（需要 Node.js 和工具链）和 **Docker 构建**（只需要 Docker，无需安装任何其他依赖）。

### 方式 A：本地构建

#### 1. 克隆仓库

```bash
git clone https://github.com/cheyang/GitNexus.git
cd GitNexus
```

#### 2. 安装根依赖

```bash
npm install
```

#### 3. 构建 gitnexus-shared（共享类型库）

```bash
cd gitnexus-shared
npm install
npm run build
cd ..
```

#### 4. 构建 gitnexus（CLI 主包）

```bash
cd gitnexus
npm install
npm run build
cd ..
```

`npm run build`（即 `node scripts/build.js`）会自动完成以下步骤：

1. 编译 `gitnexus-shared`（TypeScript → JavaScript）
2. 编译 `gitnexus`（TypeScript → JavaScript）
3. 将 `gitnexus-shared/dist` 复制到 `gitnexus/dist/_shared`
4. 重写所有 `gitnexus-shared` 导入路径为相对路径
5. 设置 CLI 入口文件可执行权限
6. 构建 Web UI 并复制到 `gitnexus/web/`（如果 `gitnexus-web` 存在）

构建产物结构：

```
gitnexus/
├── dist/                  # 编译后的 JavaScript
│   ├── cli/index.js       # CLI 入口（bin 指向这里）
│   ├── _shared/           # 内联的共享类型
│   ├── core/              # 核心逻辑
│   ├── mcp/               # MCP 服务器
│   └── ...
├── hooks/                 # Claude Code / Cursor hooks
├── scripts/               # 构建和安装脚本
├── skills/                # AI agent 技能文件
├── vendor/                # 预编译的 tree-sitter 语法
│   ├── tree-sitter-c/
│   ├── tree-sitter-dart/
│   ├── tree-sitter-kotlin/
│   ├── tree-sitter-proto/
│   └── tree-sitter-swift/
└── web/                   # Web UI 静态文件（构建时生成）
```

#### 5. 构建 Web UI（可选）

如果需要 Web UI（`gitnexus serve` 功能），还需构建前端：

```bash
cd gitnexus-web
npm install
npm run build
cd ..
```

> 注意：`gitnexus/scripts/build.js` 会自动检测 `gitnexus-web` 并构建，如果你已在步骤 4 中运行过 `npm run build`，这一步可以跳过。

---

### 方式 B：通过 Docker 构建

如果你不想在本地安装 Node.js、Python、C++ 编译器等工具链，可以完全通过 Docker 完成构建。只需安装 Docker 即可。

#### 快速开始：一键构建 Docker 镜像

项目已提供多阶段 Dockerfile，直接构建即可：

```bash
git clone https://github.com/cheyang/GitNexus.git
cd GitNexus

# 构建 CLI/Server 镜像（包含完整 CLI + MCP + HTTP 服务）
docker build -f Dockerfile.cli -t gitnexus:latest .

# 构建 Web UI 镜像
docker build -f Dockerfile.web -t gitnexus-web:latest .
```

构建过程自动完成所有事情：安装依赖、编译 TypeScript、构建原生 tree-sitter 语法、裁剪开发依赖。

#### 使用 docker compose 一键启动

```bash
# 使用本地构建的镜像
cat > .env << 'EOF'
SERVER_IMAGE=gitnexus:latest
WEB_IMAGE=gitnexus-web:latest
WORKSPACE_DIR=/path/to/your/repos
EOF

docker compose up -d
```

- Server：`http://localhost:4747`
- Web UI：`http://localhost:4173`

#### 在 Docker 中索引仓库

```bash
# 索引容器内挂载的仓库
docker compose exec gitnexus-server gitnexus analyze /workspace/my-repo

# 列出已索引仓库
docker compose exec gitnexus-server gitnexus list

# 查看状态
docker compose exec gitnexus-server gitnexus status
```

#### 用 Docker 构建 npm tarball（不安装本地工具链）

如果你需要的不是 Docker 镜像，而是 npm tarball（`.tgz`），可以用 Docker 作为构建环境：

```bash
# 创建一个构建专用 Dockerfile
cat > Dockerfile.pack << 'DOCKERFILE'
FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ git && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# 构建 shared
RUN cd gitnexus-shared && npm install && npm run build

# 构建 CLI
RUN cd gitnexus && npm install && npm run build

# 打包 tarball
RUN cd gitnexus && npm pack && mv *.tgz /tmp/

CMD ["cp", "-r", "/tmp/", "/output/"]
DOCKERFILE

# 构建并提取 tarball
docker build -f Dockerfile.pack -t gitnexus-builder .
docker run --rm -v "$(pwd)/output:/output" gitnexus-builder \
    sh -c "cp /tmp/*.tgz /output/"

# tarball 在 ./output/ 目录下
ls output/*.tgz
```

提取到的 `.tgz` 文件可以在任何有 Node.js 22+ 的机器上安装：

```bash
npm install -g ./output/gitnexus-1.6.8.tgz
```

#### 多架构构建

为不同平台构建镜像（比如在 Mac 上构建 Linux amd64/arm64）：

```bash
# 创建 buildx builder（首次）
docker buildx create --name gitnexus-builder --use

# 多架构构建并推送到 Registry
docker buildx build -f Dockerfile.cli \
    --platform linux/amd64,linux/arm64 \
    -t registry.example.com/gitnexus:latest \
    --push .

# 多架构构建 Web UI
docker buildx build -f Dockerfile.web \
    --platform linux/amd64,linux/arm64 \
    -t registry.example.com/gitnexus-web:latest \
    --push .
```

#### Docker 构建方式对比

| 场景 | 推荐方式 | 说明 |
|------|---------|------|
| 部署为服务（Server + Web UI） | `docker build -f Dockerfile.cli` | 直接构建官方 Dockerfile |
| 只需要 npm tarball 分发 | `Dockerfile.pack` + 提取 tgz | Docker 当构建环境用 |
| 生产环境 Kubernetes 部署 | `docker buildx` 多架构 | 推送到私有 Registry |
| 开发测试 | `docker compose up -d` | 本地快速启动全栈 |

#### Docker 镜像推送到私有仓库

```bash
# 推送到 Harbor / 私有 Registry
docker tag gitnexus:latest harbor.example.com/devtools/gitnexus:latest
docker push harbor.example.com/devtools/gitnexus:latest

# 推送到阿里云 ACR
docker tag gitnexus:latest registry.cn-hangzhou.aliyuncs.com/your-ns/gitnexus:latest
docker push registry.cn-hangzhou.aliyuncs.com/your-ns/gitnexus:latest

# 推送到 AWS ECR
docker tag gitnexus:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/gitnexus:latest
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/gitnexus:latest
```

#### Dockerfile 详解

项目提供两个官方 Dockerfile：

**`Dockerfile.cli`** — CLI/Server 镜像（多阶段构建）：

```
阶段 1 (builder):
  基础镜像: node:22-bookworm-slim
  安装工具链: python3 + make + g++ + git
  构建 gitnexus-shared → 构建 gitnexus → 裁剪 devDependencies
  重建 vendored tree-sitter 语法（prune 后需要恢复）

阶段 2 (runtime):
  基础镜像: node:22-bookworm-slim（无构建工具链，更小）
  仅复制: dist/ + node_modules/ + vendor/ + hooks/ + skills/
  安装 LadybugDB FTS 扩展（BM25 关键词搜索）
  以 node 用户运行（非 root）
  暴露端口 4747
```

**`Dockerfile.web`** — Web UI 镜像（多阶段构建）：

```
阶段 1 (builder):
  基础镜像: node:22-bookworm-slim
  构建 gitnexus-shared → 构建 gitnexus-web（Vite 前端）

阶段 2 (runtime):
  基础镜像: node:22-bookworm-slim
  仅复制: 构建产物的静态文件
  以 node 用户运行
  暴露端口 4173
```

---

## 分发方式

### 方式一：本地 tarball 安装

最简单的分发方式 — 打包成 `.tgz` 文件，拷贝到目标机器安装。

**打包：**

```bash
cd gitnexus
npm pack
```

生成文件：`gitnexus-1.6.8.tgz`（版本号取决于 `package.json`）。

`npm pack` 只会包含 `package.json` 中 `files` 字段声明的内容：

```json
"files": ["dist", "hooks", "scripts", "skills", "vendor", "web"]
```

**安装（目标机器）：**

```bash
# 全局安装
npm install -g ./gitnexus-1.6.8.tgz

# 验证
gitnexus --version
```

**离线场景的完整步骤：**

```bash
# 构建机器：打包 tarball
cd gitnexus && npm pack

# 传输到目标机器（U 盘、scp 等）
scp gitnexus-1.6.8.tgz user@target:/tmp/

# 目标机器：安装
ssh user@target
npm install -g /tmp/gitnexus-1.6.8.tgz
```

---

### 方式二：发布到私有 npm Registry

适用于企业内部分发。

**使用 Verdaccio（本地私有 Registry）：**

```bash
# 安装 Verdaccio
npm install -g verdaccio
verdaccio &  # 默认在 http://localhost:4873

# 配置 npm 指向私有 Registry
npm set registry http://localhost:4873

# 创建用户（首次）
npm adduser --registry http://localhost:4873

# 发布
cd gitnexus
npm publish --registry http://localhost:4873

# 其他机器安装
npm install -g gitnexus --registry http://localhost:4873
```

**使用 GitHub Packages：**

```bash
# 1. 修改包名加 scope（package.json）
#    "name": "@cheyang/gitnexus"

# 2. 添加 publishConfig
#    "publishConfig": { "registry": "https://npm.pkg.github.com" }

# 3. 登录 GitHub Packages
npm login --registry https://npm.pkg.github.com
# Username: cheyang
# Password: <你的 GitHub Personal Access Token>

# 4. 发布
cd gitnexus
npm publish

# 5. 其他机器安装
echo "@cheyang:registry=https://npm.pkg.github.com" >> .npmrc
npm install -g @cheyang/gitnexus
```

**使用阿里云 cnpm / 其他私有 Registry：**

```bash
# 发布
cd gitnexus
npm publish --registry https://your-registry.example.com

# 安装
npm install -g gitnexus --registry https://your-registry.example.com
```

---

### 方式三：直接从 Git 仓库安装

无需发布到 Registry，直接从 Git 仓库安装。

```bash
# 从 GitHub 安装（需要 postinstall 有构建步骤）
npm install -g git+https://github.com/cheyang/GitNexus.git#main

# 或使用子目录安装（npm 7.24+）
npm install -g "github:cheyang/GitNexus#main"
```

> **注意：** 这种方式要求目标机器有完整的构建工具链（Node.js、C++ 编译器等），因为 `postinstall` 脚本会在安装时触发原生依赖编译。对于 monorepo 结构的项目，这种方式可能不太方便。推荐先本地构建再用 tarball 分发。

---

### 方式四：发布到公共 npm Registry

如果你 fork 了项目并希望以自己的包名发布：

```bash
# 1. 修改 package.json
cd gitnexus
```

修改以下字段：

```json
{
  "name": "@cheyang/gitnexus",
  "version": "1.0.0",
  "repository": {
    "url": "git+https://github.com/cheyang/GitNexus.git"
  }
}
```

```bash
# 2. 登录 npm
npm login

# 3. 构建
npm run build

# 4. 发布
npm publish --access public

# 5. 安装
npm install -g @cheyang/gitnexus
```

> **许可证注意：** GitNexus 使用 **PolyForm Noncommercial** 许可证，商业使用需联系原作者获取授权。

---

## 自定义构建

### 修改包名和版本号

```bash
cd gitnexus

# 修改版本号
npm version 2.0.0 --no-git-tag-version

# 或直接编辑 package.json
```

修改 `package.json` 中的关键字段：

```json
{
  "name": "@your-scope/gitnexus",
  "version": "2.0.0",
  "bin": {
    "gitnexus": "dist/cli/index.js"
  }
}
```

如果你想修改 CLI 命令名（比如从 `gitnexus` 改为 `mycodegraph`）：

```json
{
  "bin": {
    "mycodegraph": "dist/cli/index.js"
  }
}
```

安装后就可以用 `mycodegraph analyze` 来运行了。

### 跳过 Web UI 构建

如果你只需要 CLI + MCP，不需要 Web UI，可以在构建前删除或移走 `gitnexus-web` 目录：

```bash
# 构建脚本会自动跳过 Web UI
mv gitnexus-web gitnexus-web.bak
cd gitnexus && npm run build
```

构建日志会显示 `[build] skipping web UI (gitnexus-web not found)`。

### 跳过可选语法

减少包体积，跳过 Dart/Proto/Swift/Kotlin 语法：

```bash
GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm run build
```

或者在安装时跳过：

```bash
GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm install -g ./gitnexus-1.6.8.tgz
```

### 控制构建超时

大型项目的 TypeScript 编译可能较慢：

```bash
GITNEXUS_BUILD_TIMEOUT_MS=600000 npm run build  # 10 分钟
```

---

## Docker 镜像构建

### 构建 CLI/Server 镜像

```bash
# 从仓库根目录
docker build -f Dockerfile.cli -t my-gitnexus:latest .
```

### 构建 Web UI 镜像

```bash
docker build -f Dockerfile.web -t my-gitnexus-web:latest .
```

### 使用自定义镜像运行

```bash
# 创建 .env 文件
cat > .env << 'EOF'
CLI_IMAGE=my-gitnexus:latest
WEB_IMAGE=my-gitnexus-web:latest
EOF

# 启动
docker compose --env-file .env up -d
```

### 推送到私有镜像仓库

```bash
# 推送到私有 Registry
docker tag my-gitnexus:latest registry.example.com/gitnexus:latest
docker push registry.example.com/gitnexus:latest

# 推送到阿里云 ACR
docker tag my-gitnexus:latest registry.cn-hangzhou.aliyuncs.com/your-ns/gitnexus:latest
docker push registry.cn-hangzhou.aliyuncs.com/your-ns/gitnexus:latest
```

---

## CI/CD 自动发布

### GitHub Actions 自动构建并发布

```yaml
# .github/workflows/build-and-publish.yml
name: Build and Publish

on:
  push:
    tags: ['v*']

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 22
          registry-url: 'https://registry.npmjs.org'

      # 构建 shared
      - name: Build shared
        run: |
          cd gitnexus-shared
          npm install
          npm run build

      # 构建主包
      - name: Build CLI
        run: |
          cd gitnexus
          npm install
          npm run build

      # 发布
      - name: Publish
        run: |
          cd gitnexus
          npm publish --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### 发布到 GitHub Packages

```yaml
# .github/workflows/publish-ghpkg.yml
name: Publish to GitHub Packages

on:
  push:
    tags: ['v*']

permissions:
  packages: write
  contents: read

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 22
          registry-url: 'https://npm.pkg.github.com'
          scope: '@cheyang'

      - name: Build
        run: |
          cd gitnexus-shared && npm install && npm run build && cd ..
          cd gitnexus && npm install && npm run build

      - name: Publish
        run: |
          cd gitnexus
          npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 验证安装

安装完成后，运行以下命令验证：

```bash
# 检查版本
gitnexus --version

# 检查 CLI 是否正常
gitnexus --help

# 测试索引功能（在任意 Git 仓库中）
cd /path/to/any/repo
gitnexus analyze

# 检查索引状态
gitnexus status

# 测试 MCP 服务器
gitnexus mcp  # 启动 MCP（stdio 模式，Ctrl+C 退出）

# 测试 HTTP 服务器
gitnexus serve  # 启动后访问 http://localhost:4747
```

---

## 常见问题

### Q: `npm run build` 报错 `gitnexus-shared not found`

确保你在仓库根目录下先构建了 `gitnexus-shared`：

```bash
cd gitnexus-shared && npm install && npm run build && cd ..
cd gitnexus && npm install && npm run build
```

### Q: `postinstall` 阶段原生编译失败

这通常是 tree-sitter 语法的原生绑定编译问题。跳过可选语法：

```bash
GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm install
```

或者确保安装了 C++ 编译工具链：

```bash
# macOS
xcode-select --install

# Ubuntu/Debian
sudo apt install build-essential python3

# CentOS/RHEL
sudo yum groupinstall "Development Tools"
```

### Q: tarball 安装后 `gitnexus` 命令找不到

检查 npm 全局 bin 路径是否在 `PATH` 中：

```bash
npm config get prefix
# 将 <prefix>/bin 添加到 PATH
export PATH="$(npm config get prefix)/bin:$PATH"
```

### Q: 如何确认 tarball 包含了所有必要文件？

```bash
# 列出 tarball 内容（不实际解压）
npm pack --dry-run
```

会列出所有将被包含的文件，确认 `dist/`、`vendor/`、`hooks/`、`skills/` 等都在其中。

### Q: 目标机器没有网络，如何处理原生依赖？

1. 在有网络的同架构机器上完整构建
2. `npm pack` 打包 tarball
3. 传输到离线机器
4. 用 `GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm install -g ./gitnexus-x.y.z.tgz` 安装

`vendor/` 目录中已包含预编译的平台二进制文件（prebuilds），大多数平台无需重新编译。

### Q: 我修改了源码后怎么重新构建？

```bash
cd gitnexus
npm run build  # 重新编译 TypeScript 并打包
```

如果修改了 `gitnexus-shared`，需要先重新构建它：

```bash
cd gitnexus-shared && npm run build && cd ../gitnexus && npm run build
```
