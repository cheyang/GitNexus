# Building and Distributing GitNexus npm Package

This document explains how to build the GitNexus npm package from source and distribute/install it through various methods.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Building from Source](#building-from-source)
- [Distribution Methods](#distribution-methods)
  - [Method 1: Local Tarball Install](#method-1-local-tarball-install)
  - [Method 2: Publish to a Private npm Registry](#method-2-publish-to-a-private-npm-registry)
  - [Method 3: Install Directly from Git](#method-3-install-directly-from-git)
  - [Method 4: Publish to the Public npm Registry](#method-4-publish-to-the-public-npm-registry)
- [Custom Builds](#custom-builds)
  - [Changing the Package Name and Version](#changing-the-package-name-and-version)
  - [Skipping the Web UI Build](#skipping-the-web-ui-build)
  - [Skipping Optional Grammars](#skipping-optional-grammars)
- [Docker Image Build](#docker-image-build)
- [CI/CD Automated Publishing](#cicd-automated-publishing)
- [Verifying the Installation](#verifying-the-installation)
- [FAQ](#faq)

---

## Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Node.js | 22.0.0 | Runtime |
| npm | 10.x+ | Package management |
| Git | 2.x | Source code checkout |
| Python 3 | 3.8+ | Native compilation for some tree-sitter grammars (optional) |
| C++ compiler | gcc/clang/MSVC | Native dependency compilation (optional) |

> Python and a C++ compiler can be skipped if you don't need Dart/Proto/Swift/Kotlin language support.

---

## Building from Source

### 1. Clone the Repository

```bash
git clone https://github.com/cheyang/GitNexus.git
cd GitNexus
```

### 2. Install Root Dependencies

```bash
npm install
```

### 3. Build gitnexus-shared (Shared Type Library)

```bash
cd gitnexus-shared
npm install
npm run build
cd ..
```

### 4. Build gitnexus (Main CLI Package)

```bash
cd gitnexus
npm install
npm run build
cd ..
```

`npm run build` (i.e. `node scripts/build.js`) automatically performs the following steps:

1. Compiles `gitnexus-shared` (TypeScript → JavaScript)
2. Compiles `gitnexus` (TypeScript → JavaScript)
3. Copies `gitnexus-shared/dist` into `gitnexus/dist/_shared`
4. Rewrites all `gitnexus-shared` import paths to relative paths
5. Sets the CLI entry file as executable
6. Builds the Web UI and copies it to `gitnexus/web/` (if `gitnexus-web` exists)

Build output structure:

```
gitnexus/
├── dist/                  # Compiled JavaScript
│   ├── cli/index.js       # CLI entry (bin points here)
│   ├── _shared/           # Inlined shared types
│   ├── core/              # Core logic
│   ├── mcp/               # MCP server
│   └── ...
├── hooks/                 # Claude Code / Cursor hooks
├── scripts/               # Build and install scripts
├── skills/                # AI agent skill files
├── vendor/                # Prebuilt tree-sitter grammars
│   ├── tree-sitter-c/
│   ├── tree-sitter-dart/
│   ├── tree-sitter-kotlin/
│   ├── tree-sitter-proto/
│   └── tree-sitter-swift/
└── web/                   # Web UI static files (generated at build time)
```

### 5. Build the Web UI (Optional)

If you need the Web UI (`gitnexus serve` feature), also build the frontend:

```bash
cd gitnexus-web
npm install
npm run build
cd ..
```

> Note: `gitnexus/scripts/build.js` automatically detects and builds `gitnexus-web`, so you can skip this step if you already ran `npm run build` in step 4.

---

## Distribution Methods

### Method 1: Local Tarball Install

The simplest distribution method — pack into a `.tgz` file, copy to target machines and install.

**Pack:**

```bash
cd gitnexus
npm pack
```

This generates: `gitnexus-1.6.8.tgz` (version depends on `package.json`).

`npm pack` only includes contents declared in the `files` field of `package.json`:

```json
"files": ["dist", "hooks", "scripts", "skills", "vendor", "web"]
```

**Install (on target machine):**

```bash
# Global install
npm install -g ./gitnexus-1.6.8.tgz

# Verify
gitnexus --version
```

**Full steps for offline scenarios:**

```bash
# Build machine: pack the tarball
cd gitnexus && npm pack

# Transfer to target machine (USB, scp, etc.)
scp gitnexus-1.6.8.tgz user@target:/tmp/

# Target machine: install
ssh user@target
npm install -g /tmp/gitnexus-1.6.8.tgz
```

---

### Method 2: Publish to a Private npm Registry

Ideal for internal enterprise distribution.

**Using Verdaccio (local private registry):**

```bash
# Install Verdaccio
npm install -g verdaccio
verdaccio &  # Runs on http://localhost:4873 by default

# Point npm to the private registry
npm set registry http://localhost:4873

# Create a user (first time)
npm adduser --registry http://localhost:4873

# Publish
cd gitnexus
npm publish --registry http://localhost:4873

# Install from other machines
npm install -g gitnexus --registry http://localhost:4873
```

**Using GitHub Packages:**

```bash
# 1. Add a scope to the package name (in package.json)
#    "name": "@cheyang/gitnexus"

# 2. Add publishConfig
#    "publishConfig": { "registry": "https://npm.pkg.github.com" }

# 3. Log in to GitHub Packages
npm login --registry https://npm.pkg.github.com
# Username: cheyang
# Password: <your GitHub Personal Access Token>

# 4. Publish
cd gitnexus
npm publish

# 5. Install from other machines
echo "@cheyang:registry=https://npm.pkg.github.com" >> .npmrc
npm install -g @cheyang/gitnexus
```

**Using other private registries (Artifactory, cnpm, etc.):**

```bash
# Publish
cd gitnexus
npm publish --registry https://your-registry.example.com

# Install
npm install -g gitnexus --registry https://your-registry.example.com
```

---

### Method 3: Install Directly from Git

No registry needed — install directly from a Git repository.

```bash
# Install from GitHub (requires build toolchain on target)
npm install -g git+https://github.com/cheyang/GitNexus.git#main

# Or use the shorthand (npm 7.24+)
npm install -g "github:cheyang/GitNexus#main"
```

> **Note:** This requires a full build toolchain (Node.js, C++ compiler, etc.) on the target machine because the `postinstall` script triggers native dependency compilation. For monorepo projects, this can be inconvenient. Building locally first and distributing via tarball is recommended instead.

---

### Method 4: Publish to the Public npm Registry

If you've forked the project and want to publish under your own package name:

```bash
# 1. Edit package.json
cd gitnexus
```

Modify the following fields:

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
# 2. Log in to npm
npm login

# 3. Build
npm run build

# 4. Publish
npm publish --access public

# 5. Install
npm install -g @cheyang/gitnexus
```

> **License note:** GitNexus uses the **PolyForm Noncommercial** license. Commercial use requires authorization from the original author.

---

## Custom Builds

### Changing the Package Name and Version

```bash
cd gitnexus

# Change the version
npm version 2.0.0 --no-git-tag-version

# Or edit package.json directly
```

Key fields to modify in `package.json`:

```json
{
  "name": "@your-scope/gitnexus",
  "version": "2.0.0",
  "bin": {
    "gitnexus": "dist/cli/index.js"
  }
}
```

To change the CLI command name (e.g. from `gitnexus` to `mycodegraph`):

```json
{
  "bin": {
    "mycodegraph": "dist/cli/index.js"
  }
}
```

After installation, you can run `mycodegraph analyze`.

### Skipping the Web UI Build

If you only need CLI + MCP without the Web UI, move or remove the `gitnexus-web` directory before building:

```bash
# The build script auto-skips the Web UI
mv gitnexus-web gitnexus-web.bak
cd gitnexus && npm run build
```

The build log will show `[build] skipping web UI (gitnexus-web not found)`.

### Skipping Optional Grammars

Reduce package size by skipping Dart/Proto/Swift/Kotlin grammars:

```bash
GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm run build
```

Or skip at install time:

```bash
GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm install -g ./gitnexus-1.6.8.tgz
```

### Controlling Build Timeout

TypeScript compilation for large projects may be slow:

```bash
GITNEXUS_BUILD_TIMEOUT_MS=600000 npm run build  # 10 minutes
```

---

## Docker Image Build

### Build CLI/Server Image

```bash
# From the repository root
docker build -f Dockerfile.cli -t my-gitnexus:latest .
```

### Build Web UI Image

```bash
docker build -f Dockerfile.web -t my-gitnexus-web:latest .
```

### Run with Custom Images

```bash
# Create a .env file
cat > .env << 'EOF'
CLI_IMAGE=my-gitnexus:latest
WEB_IMAGE=my-gitnexus-web:latest
EOF

# Start
docker compose --env-file .env up -d
```

### Push to a Private Container Registry

```bash
# Push to a private registry
docker tag my-gitnexus:latest registry.example.com/gitnexus:latest
docker push registry.example.com/gitnexus:latest

# Push to a cloud registry (e.g. AWS ECR, GCR, ACR)
docker tag my-gitnexus:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/gitnexus:latest
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/gitnexus:latest
```

---

## CI/CD Automated Publishing

### GitHub Actions — Build and Publish to npm

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

      # Build shared
      - name: Build shared
        run: |
          cd gitnexus-shared
          npm install
          npm run build

      # Build main package
      - name: Build CLI
        run: |
          cd gitnexus
          npm install
          npm run build

      # Publish
      - name: Publish
        run: |
          cd gitnexus
          npm publish --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Publish to GitHub Packages

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

## Verifying the Installation

After installation, run these commands to verify:

```bash
# Check version
gitnexus --version

# Check CLI help
gitnexus --help

# Test indexing (in any Git repository)
cd /path/to/any/repo
gitnexus analyze

# Check index status
gitnexus status

# Test MCP server
gitnexus mcp  # Starts MCP in stdio mode (Ctrl+C to exit)

# Test HTTP server
gitnexus serve  # Then visit http://localhost:4747
```

---

## FAQ

### Q: `npm run build` fails with `gitnexus-shared not found`

Make sure you built `gitnexus-shared` first from the repo root:

```bash
cd gitnexus-shared && npm install && npm run build && cd ..
cd gitnexus && npm install && npm run build
```

### Q: Native compilation fails during `postinstall`

This is usually a tree-sitter grammar native binding compilation issue. Skip optional grammars:

```bash
GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm install
```

Or make sure you have a C++ build toolchain installed:

```bash
# macOS
xcode-select --install

# Ubuntu/Debian
sudo apt install build-essential python3

# CentOS/RHEL
sudo yum groupinstall "Development Tools"
```

### Q: `gitnexus` command not found after tarball install

Check that npm's global bin directory is in your `PATH`:

```bash
npm config get prefix
# Add <prefix>/bin to your PATH
export PATH="$(npm config get prefix)/bin:$PATH"
```

### Q: How can I verify the tarball contains all necessary files?

```bash
# List tarball contents (dry run, no extraction)
npm pack --dry-run
```

This lists all files that will be included. Confirm `dist/`, `vendor/`, `hooks/`, `skills/`, etc. are present.

### Q: How do I handle native dependencies on an offline target machine?

1. Build fully on a networked machine with the same architecture
2. Run `npm pack` to create the tarball
3. Transfer to the offline machine
4. Install with `GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm install -g ./gitnexus-x.y.z.tgz`

The `vendor/` directory contains prebuilt platform binaries (prebuilds), so most platforms don't need recompilation.

### Q: How do I rebuild after modifying the source?

```bash
cd gitnexus
npm run build  # Recompiles TypeScript and bundles everything
```

If you modified `gitnexus-shared`, rebuild it first:

```bash
cd gitnexus-shared && npm run build && cd ../gitnexus && npm run build
```
