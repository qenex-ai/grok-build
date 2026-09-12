#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the Grok Build Rust workspace.
#
# Responsibilities:
#   1. Install DotSlash so the hermetic `bin/protoc` wrapper works (proto codegen
#      prerequisite documented in README.md "Building from source").
#   2. Warm cargo dependencies and pre-build the primary `grok` binary so the
#      first agent interaction is fast (full-workspace debug builds are slow).
#
# Safe to run repeatedly: every step checks/tolerates existing state.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DOTSLASH_VERSION="v0.5.9"

log() { printf '\n=== %s ===\n' "$*"; }

install_dotslash() {
  if command -v dotslash >/dev/null 2>&1; then
    log "DotSlash already installed: $(dotslash --version)"
    return 0
  fi
  log "Installing DotSlash ${DOTSLASH_VERSION}"
  local url tmp
  url="https://github.com/facebook/dotslash/releases/download/${DOTSLASH_VERSION}/dotslash-linux-musl.x86_64.tar.gz"
  tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/dotslash.tar.gz" "$url"
  tar xzf "${tmp}/dotslash.tar.gz" -C "$tmp"
  if [ -w /usr/local/bin ]; then
    install -m 0755 "${tmp}/dotslash" /usr/local/bin/dotslash
  else
    sudo install -m 0755 "${tmp}/dotslash" /usr/local/bin/dotslash
  fi
  rm -rf "$tmp"
  dotslash --version
}

install_dotslash

log "Verifying hermetic protoc via bin/protoc"
./bin/protoc --version

log "Warming cargo dependencies (cargo fetch --locked)"
cargo fetch --locked

log "Pre-building the grok binary (cargo build -p xai-grok-pager-bin)"
cargo build -p xai-grok-pager-bin

log "Install complete. Binary: target/debug/xai-grok-pager ($(target/debug/xai-grok-pager --version 2>/dev/null || echo 'run: cargo run -p xai-grok-pager-bin'))"
