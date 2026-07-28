#!/usr/bin/env bash
#
# setup.sh — choose a new private profile or restore an existing one.
#
# This is the public clean-machine entry point. It owns discovery and
# prerequisites only; profile generation remains framework-owned and restore
# behavior remains profile-owned through ./bootstrap.
set -euo pipefail

UPSTREAM_URL="${DOTFILES_UPSTREAM_URL:-https://github.com/ucod3/dotfiles.git}"
FRAMEWORK_REPO="${DOTFILES_FRAMEWORK_REPO:-$UPSTREAM_URL}"
PRIVATE_REPO="${DOTFILES_PRIVATE_REPO:-}"
FRAMEWORK_DIR="${DOTFILES_FRAMEWORK_DIR:-$HOME/dotfiles}"
PROFILE_DIR="${DOTFILES_PROFILE_DIR:-$HOME/dotfiles-private}"
HOST_NAME="${DOTFILES_INSTALL_HOST:-$(hostname -s)}"
USER_NAME="${DOTFILES_INSTALL_USER:-$(id -un)}"
MODE=""
ACTIVATE=false
ASSUME_YES=false

log_info() { printf '[INFO] %s\n' "$*"; }
log_success() { printf '[SUCCESS] %s\n' "$*"; }
log_warning() { printf '[WARNING] %s\n' "$*" >&2; }
fail() { printf 'setup error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: setup.sh [MODE] [OPTIONS]

Choose one profile journey:
  --new                 Create a new readable private profile
  --restore REPOSITORY  Restore an existing private profile repository

Without a mode, an interactive terminal is asked to choose. Restore clones only
that private profile and invokes its own ./bootstrap contract. It never regenerates
settings or updates the committed flake.lock.

Options:
      --framework REPO      Framework repository for --new
      --framework-dir PATH  Framework checkout (default: ~/dotfiles)
      --profile-dir PATH    Private profile checkout (default: ~/dotfiles-private)
      --host NAME           Host configuration (default: hostname -s)
      --user NAME           macOS user for --new (default: id -un)
      --activate            Explicitly request activation after preflight
      --yes                 Confirm --activate non-interactively
  -h, --help                Show this help

Examples:
  bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh)
  bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- --new
  bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- --restore git@github.com:you/dotfiles-private.git
USAGE
}

has_tty() {
  [[ -t 0 ]] || { : < /dev/tty; } 2>/dev/null
}

prompt_read() {
  local var_name="$1" prompt="$2" default_value="${3:-}" reply=""
  if [[ -t 0 ]]; then
    IFS= read -r -p "$prompt" reply || true
  elif { : < /dev/tty; } 2>/dev/null; then
    IFS= read -r -p "$prompt" reply < /dev/tty || true
  else
    fail "an interactive choice is required; pass --new or --restore REPOSITORY"
  fi
  [[ -n "$reply" ]] || reply="$default_value"
  printf -v "$var_name" '%s' "$reply"
}

set_mode() {
  local requested="$1"
  if [[ -n "$MODE" && "$MODE" != "$requested" ]]; then
    fail "choose exactly one journey: --new or --restore"
  fi
  MODE="$requested"
}

normalize_repo() {
  local value="$1"
  case "$value" in
    *://*|git@*|/*|./*|../*) printf '%s\n' "$value" ;;
    */*) printf 'https://github.com/%s.git\n' "${value%.git}" ;;
    *) return 1 ;;
  esac
}

require_macos_and_git() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "this installer supports macOS only"

  command -v xcode-select >/dev/null 2>&1 \
    || fail "xcode-select is unavailable; install the Xcode Command Line Tools"
  if ! xcode-select -p >/dev/null 2>&1; then
    log_info "Starting the Xcode Command Line Tools installer..."
    xcode-select --install >/dev/null 2>&1 || true
    fail "finish the Apple installer, then run setup.sh again"
  fi

  command -v git >/dev/null 2>&1 \
    || fail "Git is unavailable after installing the Xcode Command Line Tools"
}

ensure_nix() {
  if command -v nix >/dev/null 2>&1; then
    return 0
  fi

  command -v curl >/dev/null 2>&1 || fail "curl is required to install Nix"
  log_info "Installing Nix with the official multi-user installer..."
  curl --proto '=https' --tlsv1.2 -fsSL https://nixos.org/nix/install \
    | sh -s -- --daemon

  if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi

  command -v nix >/dev/null 2>&1 \
    || fail "Nix was installed but is not available; open a new terminal and rerun setup.sh"
}

ensure_git_identity() {
  local name email
  name="$(git config --global user.name 2>/dev/null || true)"
  email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "$name" && -n "$email" ]]; then
    return 0
  fi

  has_tty || fail "Git identity is required for a new profile; configure user.name and user.email"
  prompt_read name "Git name: " "$name"
  prompt_read email "Git email: " "$email"
  [[ -n "$name" && -n "$email" ]] \
    || fail "both Git name and email are required"
  git config --global user.name "$name"
  git config --global user.email "$email"
}

clone_into_absent() {
  local repo="$1" destination="$2" label="$3"
  [[ ! -e "$destination" && ! -L "$destination" ]] \
    || fail "$label destination already exists: $destination (nothing was moved or replaced)"
  mkdir -p "$(dirname "$destination")"
  log_info "Cloning $label repository into $destination"
  git clone "$repo" "$destination" \
    || fail "failed to clone $label repository: $repo"
}

profile_bootstrap_args() {
  PROFILE_ARGS=(--host "$HOST_NAME")
  if [[ "$ACTIVATE" == true ]]; then
    PROFILE_ARGS+=(--activate)
  fi
  if [[ "$ASSUME_YES" == true ]]; then
    PROFILE_ARGS+=(--yes)
  fi
}

run_profile_contract() {
  [[ -f "$PROFILE_DIR/flake.nix" ]] \
    || fail "private profile is missing flake.nix: $PROFILE_DIR"
  [[ -f "$PROFILE_DIR/flake.lock" ]] \
    || fail "private profile is missing committed flake.lock: $PROFILE_DIR"
  [[ -f "$PROFILE_DIR/bootstrap" ]] \
    || fail "private profile has no bootstrap entry point: $PROFILE_DIR"

  profile_bootstrap_args
  log_info "Invoking the profile-owned restore contract"
  (
    cd "$PROFILE_DIR"
    exec bash ./bootstrap "${PROFILE_ARGS[@]}"
  )
}

create_new_profile() {
  local framework_url
  framework_url="$(normalize_repo "$FRAMEWORK_REPO")" \
    || fail "invalid framework repository: $FRAMEWORK_REPO"

  [[ ! -e "$FRAMEWORK_DIR" && ! -L "$FRAMEWORK_DIR" ]] \
    || fail "framework destination already exists: $FRAMEWORK_DIR (nothing was moved or replaced)"
  [[ ! -e "$PROFILE_DIR" && ! -L "$PROFILE_DIR" ]] \
    || fail "private profile destination already exists: $PROFILE_DIR (nothing was moved or replaced)"

  ensure_nix
  ensure_git_identity
  clone_into_absent "$framework_url" "$FRAMEWORK_DIR" "framework"

  [[ -f "$FRAMEWORK_DIR/scripts/bin/setup-private-host" ]] \
    || fail "framework checkout has no setup-private-host command"

  log_info "Creating a readable private profile for $HOST_NAME"
  DOTFILES_ROOT="$FRAMEWORK_DIR" \
  DOTFILES_PRIVATE_FLAKE="$PROFILE_DIR" \
    bash "$FRAMEWORK_DIR/scripts/bin/setup-private-host" \
      --host "$HOST_NAME" \
      --user "$USER_NAME" \
      --fork "$framework_url"

  log_warning "The new private profile exists only on this Mac until you add and push a private remote."
  run_profile_contract
}

restore_existing_profile() {
  local private_url
  [[ -n "$PRIVATE_REPO" ]] || fail "--restore requires a repository"
  private_url="$(normalize_repo "$PRIVATE_REPO")" \
    || fail "invalid private profile repository: $PRIVATE_REPO"

  clone_into_absent "$private_url" "$PROFILE_DIR" "private profile"
  run_profile_contract
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --) shift ;;
    --new)
      set_mode new
      shift
      ;;
    --restore)
      set_mode restore
      PRIVATE_REPO="${2:-}"
      [[ -n "$PRIVATE_REPO" ]] || fail "--restore requires a repository"
      shift 2
      ;;
    --restore=*)
      set_mode restore
      PRIVATE_REPO="${1#*=}"
      [[ -n "$PRIVATE_REPO" ]] || fail "--restore requires a repository"
      shift
      ;;
    --framework)
      FRAMEWORK_REPO="${2:-}"
      [[ -n "$FRAMEWORK_REPO" ]] || fail "--framework requires a repository"
      shift 2
      ;;
    --framework=*) FRAMEWORK_REPO="${1#*=}"; shift ;;
    --framework-dir)
      FRAMEWORK_DIR="${2:-}"
      [[ -n "$FRAMEWORK_DIR" ]] || fail "--framework-dir requires a path"
      shift 2
      ;;
    --framework-dir=*) FRAMEWORK_DIR="${1#*=}"; shift ;;
    --profile-dir)
      PROFILE_DIR="${2:-}"
      [[ -n "$PROFILE_DIR" ]] || fail "--profile-dir requires a path"
      shift 2
      ;;
    --profile-dir=*) PROFILE_DIR="${1#*=}"; shift ;;
    --host)
      HOST_NAME="${2:-}"
      [[ -n "$HOST_NAME" ]] || fail "--host requires a name"
      shift 2
      ;;
    --host=*) HOST_NAME="${1#*=}"; shift ;;
    --user)
      USER_NAME="${2:-}"
      [[ -n "$USER_NAME" ]] || fail "--user requires a name"
      shift 2
      ;;
    --user=*) USER_NAME="${1#*=}"; shift ;;
    --activate) ACTIVATE=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

if [[ "$ASSUME_YES" == true && "$ACTIVATE" != true ]]; then
  fail "--yes is only valid with --activate"
fi

if [[ -z "$MODE" ]]; then
  has_tty || fail "no profile journey selected; pass --new or --restore REPOSITORY"
  printf 'Choose your setup journey:\n  1) Create a new private profile\n  2) Restore an existing private profile\n\n'
  choice=""
  prompt_read choice "Selection [1]: " "1"
  case "$choice" in
    1|new|New) MODE=new ;;
    2|restore|Restore)
      MODE=restore
      prompt_read PRIVATE_REPO "Private profile repository: " ""
      [[ -n "$PRIVATE_REPO" ]] || fail "a private profile repository is required"
      ;;
    *) fail "unknown setup journey: $choice" ;;
  esac
fi

require_macos_and_git

case "$MODE" in
  new) create_new_profile ;;
  restore) restore_existing_profile ;;
  *) fail "internal error: unsupported mode $MODE" ;;
esac

log_success "Profile journey completed"
