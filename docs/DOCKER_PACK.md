# docker-pack.sh — Docker-Based npm Tarball Builder

Build a GitNexus npm tarball (`.tgz`) entirely inside Docker — no Node.js, Python, or C++ compiler needed on your host machine.

---

## Prerequisites

- Docker 20.10+
- Git (to clone the repo)

That's it. No Node.js, no npm, no build toolchain required.

---

## Quick Start

```bash
git clone https://github.com/cheyang/GitNexus.git
cd GitNexus

./docker-pack.sh
```

Output:

```
dist-pack/
├── gitnexus-1.6.8.tgz    # Install with: npm install -g ./dist-pack/gitnexus-1.6.8.tgz
└── manifest.json          # Build metadata (name, version, size, timestamp)
```

---

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--skip-grammars` | Skip optional tree-sitter grammars (Dart/Proto/Swift/Kotlin) | Build all |
| `--skip-web` | Skip Web UI build (smaller package, no browser UI for `gitnexus serve`) | Build with Web UI |
| `--platform PLATFORM` | Docker build platform (e.g. `linux/amd64`, `linux/arm64`) | Host platform |
| `--output, -o DIR` | Output directory for the tarball | `./dist-pack` |
| `--version, -v VER` | Override the package version | Current version in package.json |
| `--name, -n NAME` | Override the package name (e.g. `@cheyang/gitnexus`) | `gitnexus` |
| `--node VERSION` | Node.js major version to use | `22` |
| `--no-cache` | Build without Docker layer cache | Use cache |
| `-h, --help` | Show help | — |

---

## Usage Examples

### Default Build (Full Package)

```bash
./docker-pack.sh
```

Builds everything: all 16 language grammars + Web UI. Largest tarball, full functionality.

### Minimal Build (CLI + MCP Only)

```bash
./docker-pack.sh --skip-grammars --skip-web
```

Skips optional grammars and Web UI. Fastest build, smallest package. You still get full CLI + MCP with support for TypeScript, JavaScript, Python, Java, C#, Go, Rust, PHP, Ruby, C, C++.

### Custom Version and Package Name

```bash
./docker-pack.sh --name @myorg/gitnexus --version 2.0.0
```

Useful when publishing a fork to a private registry under your own scope.

### Cross-Platform Build

```bash
# Build for Linux ARM64 (e.g. on a Mac for deployment to ARM servers)
./docker-pack.sh --platform linux/arm64

# Build for Linux AMD64
./docker-pack.sh --platform linux/amd64
```

### Custom Output Directory

```bash
./docker-pack.sh --output /tmp/release
# → /tmp/release/gitnexus-1.6.8.tgz
```

### Clean Build (No Docker Cache)

```bash
./docker-pack.sh --no-cache
```

Useful when troubleshooting build issues or ensuring a fully reproducible build.

### Combined Options

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

## Installing the Tarball

On any machine with Node.js 22+:

```bash
npm install -g ./dist-pack/gitnexus-1.6.8.tgz

# Verify
gitnexus --version
gitnexus --help
```

### Offline / Air-Gapped Installation

```bash
# 1. Build on a machine with Docker + internet
./docker-pack.sh

# 2. Transfer the tarball (USB, scp, shared drive)
scp dist-pack/gitnexus-1.6.8.tgz user@target:/tmp/

# 3. Install on target (only Node.js 22+ required)
ssh user@target
npm install -g /tmp/gitnexus-1.6.8.tgz
```

---

## Build Output

### Tarball Contents

The `.tgz` includes only the files declared in `package.json`'s `files` field:

```
package/
├── dist/          # Compiled JavaScript (CLI, MCP server, core logic)
├── hooks/         # Claude Code / Cursor hooks
├── scripts/       # Install-time scripts (tree-sitter grammar build)
├── skills/        # AI agent skill templates
├── vendor/        # Prebuilt tree-sitter grammars (platform binaries)
└── web/           # Web UI static files (if not skipped)
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

## How It Works

The script generates and runs a multi-stage Dockerfile on the fly:

```
┌─────────────────────────────────────────────────────┐
│  Stage 1: builder (node:22-bookworm-slim)           │
│                                                     │
│  1. Install toolchain (python3, make, g++, git, jq) │
│  2. Copy source code                                │
│  3. Build gitnexus-shared (TypeScript → JS)         │
│  4. Build gitnexus-web (Vite, if not skipped)       │
│  5. Build gitnexus (TypeScript → JS + native deps)  │
│  6. Override version/name (if requested)            │
│  7. npm pack → .tgz                                 │
│  8. Generate manifest.json                          │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  Stage 2: scratch (empty image)                     │
│                                                     │
│  Only contains: .tgz + manifest.json                │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  Host: docker cp → ./dist-pack/                     │
│                                                     │
│  Extract artifacts from the scratch container       │
└─────────────────────────────────────────────────────┘
```

The final stage uses `FROM scratch` (an empty image) so the builder image can be safely discarded after extraction. No dangling images are left behind.

---

## CI/CD Integration

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

## Troubleshooting

### Build fails with "COPY failed: file not found"

Make sure you run the script from the repository root (where `gitnexus/`, `gitnexus-shared/`, and `gitnexus-web/` directories exist):

```bash
cd /path/to/GitNexus
./docker-pack.sh
```

### Build is slow

- Use `--skip-web` if you don't need the browser UI
- Use `--skip-grammars` if you don't need Dart/Proto/Swift/Kotlin
- Subsequent builds are faster thanks to Docker layer caching
- Use `--no-cache` only when debugging build issues

### "Permission denied" on the script

```bash
chmod +x docker-pack.sh
```

### Docker daemon not running

```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker
```

### Platform mismatch warnings

If you see "WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64)", use `--platform` to explicitly target your host:

```bash
./docker-pack.sh --platform linux/arm64
```
