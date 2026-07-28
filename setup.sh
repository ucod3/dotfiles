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
SKIP_APPS=false
SELECTED_CASKS=()
SELECTED_NIX_PACKAGES=()
SELECTED_MAS_APPS=()
GIT_IDENTITY_NAME=""
GIT_IDENTITY_EMAIL=""
GIT_IDENTITY_NEEDS_LOCAL=false

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
      --cask NAME           Add a Homebrew cask to a new profile (repeatable)
      --nix-package ATTR    Add pkgs.ATTR to a new profile (repeatable)
      --mas-app NAME=REF    Add a Mac App Store app by ID or URL (repeatable)
      --skip-apps           Skip interactive application selection for --new
      --activate            Explicitly request activation after preflight
      --yes                 Confirm --activate non-interactively
  -h, --help                Show this help

Examples:
  bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh)
  bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- --new
  bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- --new --cask firefox --nix-package ripgrep
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

resolve_git_identity() {
  local name email
  name="$(git config --global user.name 2>/dev/null || true)"
  email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "$name" && -n "$email" ]]; then
    GIT_IDENTITY_NAME="$name"
    GIT_IDENTITY_EMAIL="$email"
    return 0
  fi

  if [[ -n "${GIT_AUTHOR_NAME:-}" && -n "${GIT_AUTHOR_EMAIL:-}" ]]; then
    GIT_IDENTITY_NAME="$GIT_AUTHOR_NAME"
    GIT_IDENTITY_EMAIL="$GIT_AUTHOR_EMAIL"
    GIT_IDENTITY_NEEDS_LOCAL=true
    return 0
  fi

  has_tty \
    || fail "Git identity is required for local profile commits; run interactively or set GIT_AUTHOR_NAME and GIT_AUTHOR_EMAIL"
  log_info "Git records a name and email on the private profile's local commits."
  log_info "These answers will be saved only in the private profile, not in global Git settings."
  prompt_read name "Name for private-profile commits: " "$name"
  prompt_read email "Email for private-profile commits: " "$email"
  [[ -n "$name" && -n "$email" ]] \
    || fail "both Git name and email are required"
  GIT_IDENTITY_NAME="$name"
  GIT_IDENTITY_EMAIL="$email"
  GIT_IDENTITY_NEEDS_LOCAL=true
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

has_selected_apps() {
  (( ${#SELECTED_CASKS[@]} > 0 ||
     ${#SELECTED_NIX_PACKAGES[@]} > 0 ||
     ${#SELECTED_MAS_APPS[@]} > 0 ))
}

interactive_app_selection() {
  local apps_command="$FRAMEWORK_DIR/scripts/bin/apps"
  local configure choice name app_reference query

  [[ "$SKIP_APPS" == false ]] || return 0
  has_selected_apps && return 0
  if ! has_tty; then
    log_info "No applications selected. Add them later with: dot apps"
    return 0
  fi

  prompt_read configure "Configure applications now? [Y/n]: " "y"
  case "$configure" in
    n|N|no|No|NO)
      log_info "Application selection skipped. Add them later with: dot apps"
      return 0
      ;;
  esac

  while true; do
    printf '\nChoose an application type:\n'
    printf '  1) Mac application (installed with Homebrew)\n'
    printf '  2) Command-line tool (installed with Nix)\n'
    printf '  3) Mac App Store application\n'
    printf '  4) Find a package name (read-only help)\n'
    printf '  5) Finish application selection\n\n'
    prompt_read choice "Selection [5]: " "5"

    case "$choice" in
      1|cask|Cask)
        printf 'Find names at https://formulae.brew.sh/cask/\n'
        prompt_read name "Mac app package name (example: firefox): " ""
        [[ -n "$name" ]] || fail "a Homebrew cask name is required"
        SELECTED_CASKS+=("$name")
        ;;
      2|nix|Nix)
        printf 'Find package names at https://search.nixos.org/packages\n'
        prompt_read name "Command-line package name (example: ripgrep): " ""
        [[ -n "$name" ]] || fail "a Nix package attribute is required"
        SELECTED_NIX_PACKAGES+=("$name")
        ;;
      3|mas|MAS)
        prompt_read name "Mac App Store application name: " ""
        printf 'In the App Store, choose Copy Link. You may paste the full link.\n'
        prompt_read app_reference "App Store link or numeric ID: " ""
        [[ -n "$name" && -n "$app_reference" ]] \
          || fail "an application name and App Store link or ID are required"
        SELECTED_MAS_APPS+=("$name=$app_reference")
        ;;
      4|search|Search)
        prompt_read query "Application or tool to find: " ""
        [[ -n "$query" ]] || {
          log_warning "Enter a search term or choose Finish."
          continue
        }
        [[ -x "$apps_command" ]] \
          || fail "framework checkout has no executable application command: $apps_command"
        DOTFILES_ROOT="$FRAMEWORK_DIR" \
        DOTFILES_PRIVATE_FLAKE="$PROFILE_DIR" \
          "$apps_command" search "$query"
        ;;
      5|done|Done|"")
        break
        ;;
      *)
        log_warning "Unknown application type: $choice"
        ;;
    esac
  done
}

apply_selected_apps() {
  local apps_command="$FRAMEWORK_DIR/scripts/bin/apps"
  local name spec app_reference

  has_selected_apps || return 0
  [[ -x "$apps_command" ]] \
    || fail "framework checkout has no executable application command: $apps_command"

  log_info "Writing application choices to the private profile"
  if ! (
    for name in ${SELECTED_CASKS[@]+"${SELECTED_CASKS[@]}"}; do
      DOTFILES_ROOT="$FRAMEWORK_DIR" \
      DOTFILES_PRIVATE_FLAKE="$PROFILE_DIR" \
        "$apps_command" add --cask "$name" || exit 1
    done
    for name in ${SELECTED_NIX_PACKAGES[@]+"${SELECTED_NIX_PACKAGES[@]}"}; do
      DOTFILES_ROOT="$FRAMEWORK_DIR" \
      DOTFILES_PRIVATE_FLAKE="$PROFILE_DIR" \
        "$apps_command" add --nix "$name" || exit 1
    done
    for spec in ${SELECTED_MAS_APPS[@]+"${SELECTED_MAS_APPS[@]}"}; do
      name="${spec%%=*}"
      app_reference="${spec#*=}"
      DOTFILES_ROOT="$FRAMEWORK_DIR" \
      DOTFILES_PRIVATE_FLAKE="$PROFILE_DIR" \
        "$apps_command" add --mas "$name" "$app_reference" || exit 1
    done
  ); then
    git -C "$PROFILE_DIR" restore --worktree -- apps/ >/dev/null 2>&1 || true
    fail "application selection failed; the generated apps/ files were restored"
  fi

  if [[ -z "$(git -C "$PROFILE_DIR" status --short -- apps/)" ]]; then
    log_info "Application choices already match the generated profile"
    return 0
  fi

  log_info "Reviewing application changes before saving them locally"
  git --no-pager -C "$PROFILE_DIR" diff -- apps/
  git -C "$PROFILE_DIR" add apps/
  git -C "$PROFILE_DIR" commit -m "Choose applications" >/dev/null
  log_success "Saved application choices in the private profile"
  log_info "Native operations: git diff -- apps/; git add apps/; git commit"
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
  resolve_git_identity
  clone_into_absent "$framework_url" "$FRAMEWORK_DIR" "framework"

  [[ -f "$FRAMEWORK_DIR/scripts/bin/setup-private-host" ]] \
    || fail "framework checkout has no setup-private-host command"

  log_info "Creating a readable private profile for $HOST_NAME"
  GIT_AUTHOR_NAME="$GIT_IDENTITY_NAME" \
  GIT_AUTHOR_EMAIL="$GIT_IDENTITY_EMAIL" \
  GIT_COMMITTER_NAME="$GIT_IDENTITY_NAME" \
  GIT_COMMITTER_EMAIL="$GIT_IDENTITY_EMAIL" \
  DOTFILES_ROOT="$FRAMEWORK_DIR" \
  DOTFILES_PRIVATE_FLAKE="$PROFILE_DIR" \
    bash "$FRAMEWORK_DIR/scripts/bin/setup-private-host" \
      --host "$HOST_NAME" \
      --user "$USER_NAME" \
      --fork "$framework_url"

  if [[ "$GIT_IDENTITY_NEEDS_LOCAL" == true ]]; then
    git -C "$PROFILE_DIR" config --local user.name "$GIT_IDENTITY_NAME"
    git -C "$PROFILE_DIR" config --local user.email "$GIT_IDENTITY_EMAIL"
    log_info "Saved Git identity only in the private profile's local repository settings."
  fi

  interactive_app_selection
  apply_selected_apps
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
    --cask)
      SELECTED_CASKS+=("${2:-}")
      [[ -n "${SELECTED_CASKS[${#SELECTED_CASKS[@]}-1]}" ]] \
        || fail "--cask requires a name"
      shift 2
      ;;
    --cask=*)
      SELECTED_CASKS+=("${1#*=}")
      [[ -n "${SELECTED_CASKS[${#SELECTED_CASKS[@]}-1]}" ]] \
        || fail "--cask requires a name"
      shift
      ;;
    --nix-package)
      SELECTED_NIX_PACKAGES+=("${2:-}")
      [[ -n "${SELECTED_NIX_PACKAGES[${#SELECTED_NIX_PACKAGES[@]}-1]}" ]] \
        || fail "--nix-package requires an attribute"
      shift 2
      ;;
    --nix-package=*)
      SELECTED_NIX_PACKAGES+=("${1#*=}")
      [[ -n "${SELECTED_NIX_PACKAGES[${#SELECTED_NIX_PACKAGES[@]}-1]}" ]] \
        || fail "--nix-package requires an attribute"
      shift
      ;;
    --mas-app)
      SELECTED_MAS_APPS+=("${2:-}")
      [[ -n "${SELECTED_MAS_APPS[${#SELECTED_MAS_APPS[@]}-1]}" ]] \
        || fail "--mas-app requires NAME=REF"
      shift 2
      ;;
    --mas-app=*)
      SELECTED_MAS_APPS+=("${1#*=}")
      [[ -n "${SELECTED_MAS_APPS[${#SELECTED_MAS_APPS[@]}-1]}" ]] \
        || fail "--mas-app requires NAME=REF"
      shift
      ;;
    --skip-apps) SKIP_APPS=true; shift ;;
    --activate) ACTIVATE=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

if [[ "$ASSUME_YES" == true && "$ACTIVATE" != true ]]; then
  fail "--yes is only valid with --activate"
fi

if [[ "$SKIP_APPS" == true ]] && has_selected_apps; then
  fail "--skip-apps cannot be combined with application selections"
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

if [[ "$MODE" == "restore" ]] && { [[ "$SKIP_APPS" == true ]] || has_selected_apps; }; then
  fail "application selection is only valid with --new; restore preserves the profile unchanged"
fi

require_macos_and_git

case "$MODE" in
  new) create_new_profile ;;
  restore) restore_existing_profile ;;
  *) fail "internal error: unsupported mode $MODE" ;;
esac

log_success "Profile journey completed"
