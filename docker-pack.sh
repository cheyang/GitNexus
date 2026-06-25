#!/usr/bin/env bash
#
# Build a GitNexus npm tarball (.tgz) inside Docker — no local toolchain needed.
#
# Usage:
#   ./docker-pack.sh                     # default build
#   ./docker-pack.sh --skip-grammars     # skip Dart/Proto/Swift/Kotlin grammars
#   ./docker-pack.sh --skip-web          # skip Web UI build
#   ./docker-pack.sh --platform linux/arm64  # cross-platform build
#   ./docker-pack.sh --output /tmp       # custom output directory
#   ./docker-pack.sh --version 2.0.0     # override package version
#   ./docker-pack.sh --name @cheyang/gitnexus  # override package name
#
# Output:
#   ./dist-pack/gitnexus-<version>.tgz   (or custom --output path)

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
OUTPUT_DIR="$REPO_ROOT/dist-pack"
DOCKER_IMAGE="gitnexus-pack-builder"
SKIP_GRAMMARS=""
SKIP_WEB=""
PLATFORM=""
VERSION_OVERRIDE=""
NAME_OVERRIDE=""
NODE_VERSION="22"
NO_CACHE=""

# ── Parse arguments ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-grammars)
            SKIP_GRAMMARS="1"
            shift ;;
        --skip-web)
            SKIP_WEB="1"
            shift ;;
        --platform)
            PLATFORM="$2"
            shift 2 ;;
        --output|-o)
            OUTPUT_DIR="$2"
            shift 2 ;;
        --version|-v)
            VERSION_OVERRIDE="$2"
            shift 2 ;;
        --name|-n)
            NAME_OVERRIDE="$2"
            shift 2 ;;
        --node)
            NODE_VERSION="$2"
            shift 2 ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift ;;
        --help|-h)
            cat <<'HELP'
Build a GitNexus npm tarball inside Docker.

Options:
  --skip-grammars       Skip optional tree-sitter grammars (Dart/Proto/Swift/Kotlin)
  --skip-web            Skip building the Web UI (smaller package, no `gitnexus serve` UI)
  --platform PLATFORM   Docker build platform (e.g. linux/amd64, linux/arm64)
  --output, -o DIR      Output directory for the tarball (default: ./dist-pack)
  --version, -v VER     Override the package version (e.g. 2.0.0)
  --name, -n NAME       Override the package name (e.g. @cheyang/gitnexus)
  --node VERSION        Node.js major version (default: 22)
  --no-cache            Build without Docker cache
  -h, --help            Show this help
HELP
            exit 0 ;;
        *)
            echo "Unknown option: $1 (use --help for usage)" >&2
            exit 1 ;;
    esac
done

# ── Validate ─────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo "Error: docker is not installed or not in PATH." >&2
    exit 1
fi

if [[ ! -f "$REPO_ROOT/gitnexus/package.json" ]]; then
    echo "Error: gitnexus/package.json not found. Run this script from the GitNexus repo root." >&2
    exit 1
fi

# ── Build arguments ──────────────────────────────────────────────────────
BUILD_ARGS=()
if [[ -n "$PLATFORM" ]]; then
    BUILD_ARGS+=(--platform "$PLATFORM")
fi
if [[ -n "$NO_CACHE" ]]; then
    BUILD_ARGS+=($NO_CACHE)
fi

# Read current version from package.json
CURRENT_VERSION=$(node -p "require('./gitnexus/package.json').version" 2>/dev/null \
    || python3 -c "import json; print(json.load(open('./gitnexus/package.json'))['version'])" 2>/dev/null \
    || grep -o '"version": *"[^"]*"' gitnexus/package.json | head -1 | grep -o '[0-9][0-9.a-z-]*')

FINAL_VERSION="${VERSION_OVERRIDE:-$CURRENT_VERSION}"
FINAL_NAME="${NAME_OVERRIDE:-}"

echo "============================================"
echo "  GitNexus Docker Pack Builder"
echo "============================================"
echo "  Version:        ${FINAL_VERSION}"
[[ -n "$FINAL_NAME" ]] && echo "  Package name:   ${FINAL_NAME}"
echo "  Node.js:        ${NODE_VERSION}"
echo "  Skip grammars:  ${SKIP_GRAMMARS:-no}"
echo "  Skip Web UI:    ${SKIP_WEB:-no}"
[[ -n "$PLATFORM" ]] && echo "  Platform:       ${PLATFORM}"
echo "  Output:         ${OUTPUT_DIR}"
echo "============================================"
echo ""

# ── Generate Dockerfile ──────────────────────────────────────────────────
DOCKERFILE_CONTENT=$(cat <<'DOCKERFILE_TEMPLATE'
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-bookworm-slim AS builder

ARG SKIP_GRAMMARS=""
ARG SKIP_WEB=""
ARG VERSION_OVERRIDE=""
ARG NAME_OVERRIDE=""

# Install build toolchain
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ git jq && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# ── Copy source ──────────────────────────────────────────────────────
COPY gitnexus-shared/ ./gitnexus-shared/
COPY gitnexus/ ./gitnexus/

# ── Build gitnexus-shared ────────────────────────────────────────────
RUN cd gitnexus-shared && npm install && npm run build

# ── Optionally skip Web UI ───────────────────────────────────────────
# The build script detects gitnexus-web; removing it skips the UI build.
COPY gitnexus-web/ ./gitnexus-web/
RUN if [ "$SKIP_WEB" = "1" ]; then \
        echo "[pack] Skipping Web UI build (--skip-web)"; \
        rm -rf gitnexus-web; \
    fi

# ── Build gitnexus ──────────────────────────────────────────────────
RUN cd gitnexus \
    && if [ "$SKIP_GRAMMARS" = "1" ]; then \
        export GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1; \
        echo "[pack] Skipping optional grammars"; \
    fi \
    && npm install \
    && npm run build

# ── Override version/name if requested ───────────────────────────────
RUN cd gitnexus \
    && if [ -n "$VERSION_OVERRIDE" ]; then \
        npm version "$VERSION_OVERRIDE" --no-git-tag-version --allow-same-version; \
        echo "[pack] Version set to $VERSION_OVERRIDE"; \
    fi \
    && if [ -n "$NAME_OVERRIDE" ]; then \
        jq --arg name "$NAME_OVERRIDE" '.name = $name' package.json > tmp.json \
        && mv tmp.json package.json; \
        echo "[pack] Package name set to $NAME_OVERRIDE"; \
    fi

# ── Pack ─────────────────────────────────────────────────────────────
RUN cd gitnexus && npm pack && mkdir -p /output && mv *.tgz /output/

# ── Manifest ─────────────────────────────────────────────────────────
RUN cd gitnexus && node -e " \
    const pkg = require('./package.json'); \
    const fs = require('fs'); \
    const tgz = fs.readdirSync('/output').find(f => f.endsWith('.tgz')); \
    const stats = fs.statSync('/output/' + tgz); \
    const manifest = { \
        name: pkg.name, \
        version: pkg.version, \
        file: tgz, \
        size: stats.size, \
        sizeHuman: (stats.size / 1024 / 1024).toFixed(2) + ' MB', \
        node: process.version, \
        platform: process.platform, \
        arch: process.arch, \
        builtAt: new Date().toISOString() \
    }; \
    fs.writeFileSync('/output/manifest.json', JSON.stringify(manifest, null, 2)); \
    console.log(JSON.stringify(manifest, null, 2)); \
"

# ── Final stage: just the artifacts ──────────────────────────────────
FROM scratch
COPY --from=builder /output/ /
DOCKERFILE_TEMPLATE
)

# ── Build ────────────────────────────────────────────────────────────────
echo "[1/3] Building tarball inside Docker..."

echo "$DOCKERFILE_CONTENT" | docker build \
    "${BUILD_ARGS[@]}" \
    --build-arg NODE_VERSION="$NODE_VERSION" \
    --build-arg SKIP_GRAMMARS="$SKIP_GRAMMARS" \
    --build-arg SKIP_WEB="$SKIP_WEB" \
    --build-arg VERSION_OVERRIDE="$VERSION_OVERRIDE" \
    --build-arg NAME_OVERRIDE="$NAME_OVERRIDE" \
    -t "$DOCKER_IMAGE" \
    -f - "$REPO_ROOT"

# ── Extract ──────────────────────────────────────────────────────────────
echo ""
echo "[2/3] Extracting tarball..."

mkdir -p "$OUTPUT_DIR"

# Create a temporary container from the scratch image and copy artifacts out.
CONTAINER_ID=$(docker create "$DOCKER_IMAGE")
docker cp "$CONTAINER_ID":/ - | tar -x -C "$OUTPUT_DIR" --strip-components=0 2>/dev/null || true
docker rm "$CONTAINER_ID" > /dev/null

# ── Report ───────────────────────────────────────────────────────────────
echo ""
echo "[3/3] Done!"
echo ""

TGZ_FILE=$(find "$OUTPUT_DIR" -name "*.tgz" -type f | head -1)
if [[ -n "$TGZ_FILE" ]]; then
    TGZ_SIZE=$(du -h "$TGZ_FILE" | cut -f1)
    echo "============================================"
    echo "  Tarball:  $TGZ_FILE"
    echo "  Size:     $TGZ_SIZE"
    echo "============================================"
    echo ""
    echo "Install with:"
    echo "  npm install -g $TGZ_FILE"
    echo ""

    if [[ -f "$OUTPUT_DIR/manifest.json" ]]; then
        echo "Manifest:"
        cat "$OUTPUT_DIR/manifest.json"
        echo ""
    fi
else
    echo "Error: no .tgz file found in $OUTPUT_DIR" >&2
    exit 1
fi

# ── Cleanup builder image ────────────────────────────────────────────────
docker rmi "$DOCKER_IMAGE" > /dev/null 2>&1 || true
