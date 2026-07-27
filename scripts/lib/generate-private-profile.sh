#!/usr/bin/env bash
set -euo pipefail

_SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$_SELF_DIR/../.." && pwd -P)}"
TEMPLATE_ROOT="${DOTFILES_TEMPLATE_ROOT:-$DOTFILES_ROOT/templates/private-profile}"

ROOT=""
HOST_NAME=""
USER_NAME=""
FRAMEWORK_REF="github:ucod3/dotfiles"
SYSTEM="aarch64-darwin"

usage() {
  cat <<'EOF'
Usage: generate-private-profile.sh --root PATH --host NAME --user NAME [OPTIONS]

Writes a new, readable private-profile layout. It does not initialize Git, create
flake.lock, rebuild the machine, or modify an existing profile.

Options:
  --root PATH          Destination directory
  --host NAME          Short hostname used for hosts/<name>.nix
  --user NAME          macOS username
  --framework REF      Framework flake ref (default: github:ucod3/dotfiles)
  --system SYSTEM      Nix system (default: aarch64-darwin)
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --host) HOST_NAME="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --framework) FRAMEWORK_REF="$2"; shift 2 ;;
    --framework=*) FRAMEWORK_REF="${1#*=}"; shift ;;
    --system) SYSTEM="$2"; shift 2 ;;
    --system=*) SYSTEM="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -n "$ROOT" ]] || { echo "--root is required" >&2; exit 1; }
[[ -n "$HOST_NAME" ]] || { echo "--host is required" >&2; exit 1; }
[[ -n "$USER_NAME" ]] || { echo "--user is required" >&2; exit 1; }

if [[ ! "$HOST_NAME" =~ ^[A-Za-z0-9_-]+$ || ! "$USER_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "Unsupported hostname or username for generated Nix configuration." >&2
  exit 1
fi

if [[ "$FRAMEWORK_REF" == *[[:cntrl:]\"]* || "$SYSTEM" == *[[:cntrl:]\"]* ]]; then
  echo "Framework ref and system must be safe single-line Nix strings." >&2
  exit 1
fi

[[ -d "$TEMPLATE_ROOT" ]] || {
  echo "Private-profile templates not found at $TEMPLATE_ROOT" >&2
  exit 1
}

if [[ -e "$ROOT/flake.nix" ]] || { [[ -d "$ROOT" ]] && [[ -n "$(find "$ROOT" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; }; then
  echo "Refusing to overwrite non-empty private profile: $ROOT" >&2
  exit 1
fi

render() {
  local relative="$1" destination="$2" content
  content="$(cat "$TEMPLATE_ROOT/$relative")"
  content="${content//@DOTFILES_REF@/$FRAMEWORK_REF}"
  content="${content//@HOSTNAME@/$HOST_NAME}"
  content="${content//@USER@/$USER_NAME}"
  content="${content//@SYSTEM@/$SYSTEM}"

  mkdir -p "$(dirname "$ROOT/$destination")"
  printf '%s\n' "$content" > "$ROOT/$destination"
}

render README.md README.md
render flake.nix flake.nix
render identity.nix identity.nix
render apps/default.nix apps/default.nix
render apps/homebrew-casks.nix apps/homebrew-casks.nix
render apps/nix-packages.nix apps/nix-packages.nix
render apps/mac-app-store.nix apps/mac-app-store.nix
render macos/default.nix macos/default.nix
render home.nix home.nix
render home/default.nix home/default.nix
render hosts/host.nix "hosts/$HOST_NAME.nix"

mkdir -p "$ROOT/home/files"
cat > "$ROOT/.gitignore" <<'EOF'
result
result-*
.DS_Store
EOF

printf 'Private profile template written to %s\n' "$ROOT"
printf '  Host:      hosts/%s.nix\n' "$HOST_NAME"
printf '  Framework: %s\n' "$FRAMEWORK_REF"
printf 'Review README.md and the generated Nix files before creating flake.lock.\n'
