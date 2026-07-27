#!/usr/bin/env bash
#
# One-Command Installer for macOS Dotfiles
# Makes setup accessible to both tech and non-tech users
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/install.sh)
#
# Use the process-substitution form above, NOT `curl … | bash`: piping makes the
# script its own stdin, so prompts read lines of source instead of user input.
# `prompt_read` falls back to /dev/tty to survive that, but the form above is
# strictly better and is the only one documented.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
#
# UPSTREAM_URL is where this framework is published. REPO_URL is what actually
# gets cloned, and it is NOT the same thing by default: an adopter should end up
# owning their own fork, because the private flake pins whatever `origin` turns
# out to be and that pin is what their Mac rebuilds from (ADR-010). Resolution
# order: --repo → $DOTFILES_REPO_URL → interactive prompt → upstream.
UPSTREAM_URL="https://github.com/ucod3/dotfiles.git"
REPO_URL="${DOTFILES_REPO_URL:-}"
DOTFILES_DIR="${HOME}/dotfiles"
BACKUP_DIR="${HOME}/dotfiles.backup.$(date +%Y%m%d_%H%M%S)"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This installer is designed for macOS only."
        log_info "Your OS appears to be: $OSTYPE"
        exit 1
    fi
    log_success "Running on macOS"
}

# Read user input, working even under `curl | bash` (stdin is the script).
# Defined up here because the very first prompts (architecture, Xcode) need it —
# it used to live further down, after several raw `read` calls had already
# silently consumed lines of this script as if they were user input.
# Args: <varname> <prompt> [default] [extra read flags...]
prompt_read() {
    local __var="$1" __prompt="$2" __default="${3:-}" __reply=""
    shift 3 2>/dev/null || shift $#
    if [ -t 0 ]; then
        read -r "$@" -p "$__prompt" __reply
    elif { : < /dev/tty; } 2>/dev/null; then
        # curl | bash: stdin is the script, but a controlling TTY exists
        read -r "$@" -p "$__prompt" __reply < /dev/tty || true
    else
        log_warning "No TTY available; using default: ${__default:-<none>}"
    fi
    eval "$__var=\"\${__reply:-\$__default}\""
}

# Check architecture
check_architecture() {
    local arch
    arch=$(uname -m)
    if [[ "$arch" != "arm64" ]]; then
        log_warning "This dotfiles is optimized for Apple Silicon (arm64)."
        log_warning "Your architecture: $arch"
        log_info "The setup may still work but hasn't been tested on Intel Macs."
        local continue_intel="n"
        prompt_read continue_intel "Continue anyway? (y/N): " "n"
        if [[ ! $continue_intel =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "Apple Silicon detected (arm64)"
    fi
}

# Check and install Xcode Command Line Tools
check_xcode_tools() {
    if ! xcode-select -p &>/dev/null; then
        log_info "Installing Xcode Command Line Tools..."
        log_info "This is required for Git and compilation tools."
        xcode-select --install
        prompt_read _xcode_ack "Complete the Xcode installation, then press Enter to continue..." ""
    else
        log_success "Xcode Command Line Tools installed"
    fi
}

# Check and install Nix package manager
check_nix() {
    if command -v nix &>/dev/null; then
        log_success "Nix package manager already installed"
        log_info "Version: $(nix --version)"
        return 0
    fi

    log_info "Installing Nix package manager..."
    log_info "This is the foundation of your reproducible macOS setup."
    
    # Install Nix using the official installer with safety flags
    curl -fsSL --proto '=https' --tlsv1.2 https://nixos.org/nix/install | sh
    
    # Source nix for current session
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    
    # Verify installation
    if command -v nix &>/dev/null; then
        log_success "Nix installed successfully"
        log_info "Version: $(nix --version)"
    else
        log_error "Nix installation failed. Please try installing manually:"
        log_info "https://nixos.org/download.html"
        exit 1
    fi
}

# Check and configure Git
check_git() {
    if ! command -v git &>/dev/null; then
        log_error "Git is required but not found."
        log_info "Please install Xcode Command Line Tools first."
        exit 1
    fi

    # Check if git is configured
    if [[ -z $(git config --global user.name 2>/dev/null) ]] || [[ -z $(git config --global user.email 2>/dev/null) ]]; then
        log_warning "Git is not fully configured."
        log_info "Let's set up your Git identity (required for commits)..."
        
        prompt_read git_name "Enter your name: " ""
        prompt_read git_email "Enter your email: " ""

        if [[ -z "$git_name" || -z "$git_email" ]]; then
            log_error "Git identity is required for commits. Set it with:"
            log_info "  git config --global user.name  'Your Name'"
            log_info "  git config --global user.email 'you@example.com'"
            exit 1
        fi


        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        
        log_success "Git configured with: $git_name <$git_email>"
    else
        log_success "Git already configured"
    fi
}

# Backup existing dotfiles if they exist
backup_existing() {
    if [[ -d "$DOTFILES_DIR" ]]; then
        log_warning "Existing dotfiles directory found at $DOTFILES_DIR"
        log_info "Creating backup at: $BACKUP_DIR"
        
        mv "$DOTFILES_DIR" "$BACKUP_DIR"
        log_success "Backup created: $BACKUP_DIR"
        
        log_info "You can restore this backup later with:"
        log_info "  mv $BACKUP_DIR $DOTFILES_DIR"
    fi
}

# Decide which repository this machine will track.
#
# Cloning upstream directly is a dead end for anyone who wants to change
# anything: the private flake pins `origin`, so their Mac would rebuild from a
# repository they cannot push to, and their own commits could never be promoted.
# Ask once, up front, where it is cheap to answer.
resolve_repo_url() {
    if [[ -n "$REPO_URL" ]]; then
        log_info "Using repository: $REPO_URL"
        return 0
    fi

    local answer=""
    echo
    log_info "This framework is meant to be forked — your fork is what your Mac"
    log_info "will rebuild from, and it is the only place you can push changes."
    log_info "Fork https://github.com/ucod3/dotfiles first if you have not yet."
    echo
    prompt_read answer "  Your fork (OWNER/REPO or full URL) [upstream]: " ""

    case "$answer" in
        "")
            REPO_URL="$UPSTREAM_URL"
            log_warning "Tracking upstream. You will not be able to push changes;"
            log_warning "fork it later and update 'origin' in $DOTFILES_DIR."
            ;;
        *://* | git@*)
            REPO_URL="$answer"
            ;;
        */*)
            REPO_URL="https://github.com/${answer%.git}.git"
            ;;
        *)
            log_error "Not a repository: '$answer' (expected OWNER/REPO or a URL)"
            exit 1
            ;;
    esac

    log_info "Using repository: $REPO_URL"
}

# Clone the dotfiles repository
clone_dotfiles() {
    log_info "Cloning dotfiles repository..."

    if ! git clone "$REPO_URL" "$DOTFILES_DIR"; then
        log_error "Failed to clone repository"
        log_info "Please check your internet connection and try again."
        exit 1
    fi

    log_success "Dotfiles cloned to $DOTFILES_DIR"
}

# ═══════════════════════════════════════════════════════════════════════════
# Local settings layer (.local/) — modular, gitignored machine configuration
# ═══════════════════════════════════════════════════════════════════════════
#
# PACKAGE_SOURCE lookup table: maps a menu option to its install source.
#   nix:<attr>        → Nixpkgs attribute (preferred when clean/free)
#   brew:cask:<name>  → Homebrew cask (unfree or messy in Nixpkgs on macOS)
# CUSTOMIZE: add options here and to the matching prompt list below.
# NOTE: plain case statement (macOS ships bash 3.2 — no associative arrays).
package_source() {
    case "$1" in
        # Browsers
        brave)     echo "nix:brave" ;;
        firefox)   echo "brew:cask:firefox" ;;          # nixpkgs firefox is not packaged for darwin
        chrome)    echo "brew:cask:google-chrome" ;;    # unfree
        arc)       echo "brew:cask:arc" ;;              # not in nixpkgs
        zen)       echo "brew:cask:zen" ;;              # not in nixpkgs
        # Editors
        vscode)    echo "brew:cask:visual-studio-code" ;; # unfree; cask keeps auto-update
        zed)       echo "brew:cask:zed" ;;                # cask preferred for auto-update
        cursor)    echo "brew:cask:cursor" ;;             # not in nixpkgs
        neovim)    echo "nix:core" ;;                     # already in Home Manager core
        # Terminals
        ghostty)   echo "brew:cask:ghostty" ;;            # nixpkgs ghostty is broken on darwin
        iterm2)    echo "brew:cask:iterm2" ;;
        wezterm)   echo "brew:cask:wezterm" ;;
        warp)      echo "brew:cask:warp" ;;               # not in nixpkgs
        alacritty) echo "brew:cask:alacritty" ;;          # cask keeps auto-update
        kitty)     echo "nix:kitty" ;;
        # Window managers
        amethyst)  echo "brew:cask:amethyst" ;;
        rectangle) echo "brew:cask:rectangle" ;;
        aerospace) echo "brew:cask:nikitabobko/tap/aerospace" ;;
        yabai)     echo "brew:cask:koekeishiya/formulae/yabai" ;;
        *)         echo "" ;;
    esac
}

# Anything the menus do not know about is taken at face value as a Homebrew
# cask. The curated lists are a starting point, not the boundary of what this
# framework will install — an adopter whose editor is not on the list should not
# have to edit the installer to get it.
FREEFORM_CASKS=""
prompt_extra_casks() {
    local label="$1" raw="" name
    prompt_read raw "  Other $label as Homebrew casks (space-separated, optional): " ""
    for name in $raw; do
        case "$name" in
            # Cask tokens, including tap-qualified ones like owner/tap/name.
            *[!A-Za-z0-9@._/-]*)
                log_warning "Ignoring '$name' — not a valid cask name"
                ;;
            "") ;;
            *) FREEFORM_CASKS="$FREEFORM_CASKS \"$name\"" ;;
        esac
    done
}

# Present a numbered menu; sets REPLY_SELECTION to space-separated choices.
# Args: <category label> <options...>
#
# Every category is multi-select. Terminal and window manager used to accept one
# answer each, which is not how people actually work — plenty of setups want
# Ghostty and Warp, or Rectangle alongside Aerospace — and a single-choice menu
# silently discarded the rest.
select_menu() {
    local label="$1"; shift
    local options=("$@") i raw selection=""
    echo "" >&2
    echo "  Choose your $label:" >&2
    i=1
    for opt in "${options[@]}"; do
        echo "    $i) $opt" >&2
        i=$((i + 1))
    done
    echo "    0) none / skip" >&2
    prompt_read raw "  Selection (numbers, comma- or space-separated) [0]: " "0"
    raw="${raw//,/ }"
    for n in $raw; do
        case "$n" in
            0|'') ;;
            *[!0-9]*) log_warning "Ignoring invalid choice: $n" ;;
            *) if [ "$n" -ge 1 ] && [ "$n" -le "${#options[@]}" ]; then
                   selection="$selection ${options[$((n - 1))]}"
               else
                   log_warning "Ignoring out-of-range choice: $n"
               fi ;;
        esac
    done
    REPLY_SELECTION="${selection# }"
}

# Convert selections into Nix list fragments via package_source
LOCAL_CASKS=""
LOCAL_NIXPKGS=""
collect_packages() {
    local name src
    for name in $1; do
        src="$(package_source "$name")"
        case "$src" in
            nix:core) ;; # already provided by the framework core
            nix:*)        LOCAL_NIXPKGS="$LOCAL_NIXPKGS \"${src#nix:}\"" ;;
            brew:cask:*)  LOCAL_CASKS="$LOCAL_CASKS \"${src#brew:cask:}\"" ;;
            *) log_warning "No package source known for '$name'; skipping" ;;
        esac
    done
}

# Create or link the .local settings layer
setup_local_settings() {
    local local_dir="$DOTFILES_DIR/.local"
    local private_dir="${DOTFILES_PRIVATE_FLAKE:-$HOME/dotfiles-private}"

    if [ -e "$local_dir" ] || [ -L "$local_dir" ]; then
        log_success "Local settings layer already present at $local_dir"
        return 0
    fi

    # Existing private repo becomes the backing storage for .local
    if [ -d "$private_dir" ]; then
        ln -s "$private_dir" "$local_dir"
        log_success "Linked .local -> $private_dir"
        return 0
    fi

    log_info "No ~/dotfiles-private found — creating .local/ interactively."
    log_info "(Everything in .local/ is gitignored; move it to ~/dotfiles-private"
    log_info " later and re-link with: ln -s ~/dotfiles-private $local_dir)"
    mkdir -p "$local_dir/hosts"

    # Identity (reuse git config when available)
    local id_name id_email
    id_name="$(git config --global user.name 2>/dev/null || true)"
    id_email="$(git config --global user.email 2>/dev/null || true)"
    [ -n "$id_name" ] || prompt_read id_name "  Git name: " ""
    [ -n "$id_email" ] || prompt_read id_email "  Git email: " ""
    if [ -n "$id_name" ] || [ -n "$id_email" ]; then
        cat > "$local_dir/identity.nix" <<EOF
{
  name = "$id_name";
  email = "$id_email";
}
EOF
    fi

    # Every menu feeds ONE flat list. There is no "example app set" to enable:
    # the framework names no application, so what you pick here is the whole of
    # what gets installed.
    local all_casks="" all_nixpkgs=""

    for category in \
        "browser(s)|brave firefox chrome arc zen" \
        "editor(s)|vscode zed cursor neovim" \
        "terminal(s)|ghostty warp iterm2 wezterm alacritty kitty" \
        "window manager(s)|amethyst rectangle aerospace yabai"
    do
        local label="${category%%|*}" choices="${category#*|}"
        # shellcheck disable=SC2086 # deliberate word-splitting of the choice list
        select_menu "$label" $choices
        LOCAL_CASKS="" LOCAL_NIXPKGS="" FREEFORM_CASKS=""
        collect_packages "$REPLY_SELECTION"
        prompt_extra_casks "${label%(s)}"
        all_casks="$all_casks$LOCAL_CASKS$FREEFORM_CASKS"
        all_nixpkgs="$all_nixpkgs$LOCAL_NIXPKGS"
    done

    local enable_ai="false"
    prompt_read enable_ai "  Enable AI editor config (Windsurf/Devin symlinks)? (y/N): " "n"
    [[ "$enable_ai" =~ ^[Yy]$ ]] && enable_ai="true" || enable_ai="false"

    cat > "$local_dir/settings.nix" <<EOF
# Generated by install.sh — machine-local settings (gitignored).
#
# THIS IS THE ONE FILE THAT DECIDES WHAT IS INSTALLED. Add a cask here and run
# \`dot rebuild\`; remove one and the next rebuild removes the app. The public
# framework names no application of its own.
#
#   casks        GUI apps        https://formulae.brew.sh/cask/
#   nixPackages  CLI tools       https://search.nixos.org/packages
#   masApps      Mac App Store   App Store → Copy Link → trailing number
{
  ai.enable = $enable_ai;

  casks = [$all_casks ];
  nixPackages = [$all_nixpkgs ];
  masApps = { };

  # Left at the safe default. Once the cask list above is complete, set this to
  # "uninstall" to have rebuilds prune anything you installed by hand.
  homebrew.cleanup = "none";
}
EOF

    log_success "Local settings written to $local_dir"
}

# Install Rosetta 2 for Intel compatibility (Apple Silicon only)
install_rosetta() {
    if [[ $(uname -m) == "arm64" ]]; then
        if ! /usr/bin/pgrep oahd &>/dev/null; then
            log_info "Installing Rosetta 2 for Intel app compatibility..."
            softwareupdate --install-rosetta --agree-to-license
            log_success "Rosetta 2 installed"
        else
            log_success "Rosetta 2 already installed"
        fi
    fi
}

# Main installation process
run_installation() {
    log_info "Starting dotfiles installation..."
    log_info "This will set up your entire macOS development environment."
    log_info "Estimated time: 15-30 minutes depending on internet speed."
    echo
    
    prompt_read _start_ack "Press Enter to continue or Ctrl+C to cancel..." ""
    echo
    
    # Step 1: Pre-flight checks
    log_info "Step 1/8: Checking system requirements..."
    check_macos
    check_architecture
    echo
    
    # Step 2: Install Xcode tools
    log_info "Step 2/8: Installing Xcode Command Line Tools..."
    check_xcode_tools
    echo
    
    # Step 3: Check Git
    log_info "Step 3/8: Checking Git configuration..."
    check_git
    echo
    
    # Step 4: Install Nix
    log_info "Step 4/8: Installing Nix package manager..."
    check_nix
    echo
    
    # Step 5: Install Rosetta (Apple Silicon only)
    log_info "Step 5/8: Installing Rosetta 2 (if needed)..."
    install_rosetta
    echo
    
    # Step 6: Backup and clone
    log_info "Step 6/8: Setting up dotfiles repository..."
    resolve_repo_url
    backup_existing
    clone_dotfiles
    # NOTE: git hooks are installed by bootstrap AFTER the first build. The
    # pre-commit hook requires gitleaks, which the build provides — installing
    # it here blocked every commit made before the first successful rebuild.
    echo

    # Step 7: Local settings layer (identity + app selections)
    log_info "Step 7/8: Configuring your local settings (.local/)..."
    setup_local_settings
    echo

    # Step 8: Bootstrap and build
    log_info "Step 8/8: Building your macOS configuration..."
    log_info "This will install all applications and configure your system."
    log_warning "You may be asked for your password (sudo access required)."
    echo

    cd "$DOTFILES_DIR"

    # bootstrap owns the first-run-only concerns: conflicting /etc files,
    # the private host flake, the nix-darwin bootstrap build, and git hooks.
    if ! ./scripts/bin/bootstrap; then
        log_error "Build failed. Common causes:"
        log_info "1. Files nix-darwin refuses to overwrite (/etc/nix/nix.conf, /etc/zshrc)"
        log_info "   — bootstrap prints the exact 'sudo mv' commands to fix this"
        log_info "2. Network issues downloading packages"
        log_info "3. macOS security settings blocking Nix"
        echo
        log_info "Troubleshooting steps:"
        log_info "1. Re-run: cd $DOTFILES_DIR && ./scripts/bin/bootstrap"
        log_info "2. Check your internet connection"
        log_info "3. Review the error messages above for specific issues"
        exit 1
    fi
    
    echo
    log_success "Installation complete! 🎉"
    echo
}

# Post-installation information
show_post_install_info() {
    log_success "Your macOS is now fully configured!"
    echo
    
    log_info "What's been set up:"
    echo "  ✅ Shell: Zsh with Oh My Zsh, autosuggestions, syntax highlighting"
    echo "  ✅ Editor: Neovim with LSP support and modern plugins"
    echo "  ✅ Development: Git, Node.js, Python tools configured"
    echo "  ✅ Apps: the browsers/editors/terminal you selected (.local/)"
    echo "  ✅ macOS: stock behaviour unless you enabled the defaults profile"
    echo
    
    log_info "Quick start commands:"
    echo "  dot rebuild   - Apply configuration changes"
    echo "  dot update    - Update all packages and configuration"
    echo "  dot apps      - Add or remove applications"
    echo "  dot help      - Full command reference"
    echo "  change        - Edit your shell customizations"
    echo
    
    log_info "Next steps:"
    echo "  1. Restart your terminal to load all changes"
    echo "  2. Turn on what you want in .local/settings.nix, then: dot rebuild"
    echo "  3. See GETTING-STARTED.md and docs/OPERATIONS.md"
    echo
    
    log_info "Your dotfiles location: $DOTFILES_DIR"
    if [[ -d "$BACKUP_DIR" ]]; then
        log_info "Backup location: $BACKUP_DIR"
    fi
    echo
    
    log_success "Happy coding! 🚀"
}

# Handle errors gracefully
cleanup_on_error() {
    # Disable trap to prevent recursion
    trap - ERR

    log_error "Installation interrupted."

    if [[ -d "$DOTFILES_DIR" ]] && [[ -d "$BACKUP_DIR" ]]; then
        # Only prompt if stdin is a terminal (not piped)
        if [[ -t 0 ]]; then
            local restore_reply
            prompt_read restore_reply "Would you like to restore the backup? (y/N) " "n"
            if [[ $restore_reply =~ ^[Yy]$ ]]; then
                rm -rf "$DOTFILES_DIR"
                mv "$BACKUP_DIR" "$DOTFILES_DIR"
                log_success "Backup restored."
            fi
        else
            log_info "Backup available at: $BACKUP_DIR"
        fi
    fi
}

# Main execution
trap cleanup_on_error ERR

# Parse command line arguments
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --repo)
            REPO_URL="${2:-}"
            if [[ -z "$REPO_URL" ]]; then
                log_error "--repo needs a repository (OWNER/REPO or a URL)"
                exit 1
            fi
            case "$REPO_URL" in
                *://* | git@*) ;;
                */*) REPO_URL="https://github.com/${REPO_URL%.git}.git" ;;
                *) log_error "Not a repository: '$REPO_URL'"; exit 1 ;;
            esac
            shift 2
            ;;
        --repo=*)
            set -- --repo "${1#*=}" "${@:2}"
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Enable verbose output"
            echo "      --repo REPO  Clone this fork instead of prompting."
            echo "                   OWNER/REPO or a full clone URL. Also settable"
            echo "                   as \$DOTFILES_REPO_URL."
            echo "  -h, --help       Show this help message"
            echo ""
            echo "This installer sets up a complete macOS development environment"
            echo "using Nix, nix-darwin, and Home Manager."
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

if [[ "$VERBOSE" == true ]]; then
    set -x
fi

# Run the installer
run_installation
show_post_install_info

# Final success message
log_success "Setup complete! Your Mac is ready for development."