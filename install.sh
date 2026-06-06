#!/usr/bin/env bash
#
# One-Command Installer for macOS Dotfiles
# Makes setup accessible to both tech and non-tech users
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/usmanbutt/dotfiles/main/install.sh | bash
#   # OR
#   bash <(curl -fsSL https://raw.githubusercontent.com/usmanbutt/dotfiles/main/install.sh)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/usmanbutt/dotfiles.git"
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

# Check architecture
check_architecture() {
    local arch=$(uname -m)
    if [[ "$arch" != "arm64" ]]; then
        log_warning "This dotfiles is optimized for Apple Silicon (arm64)."
        log_warning "Your architecture: $arch"
        log_info "The setup may still work but hasn't been tested on Intel Macs."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
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
        log_warning "Please complete the Xcode installation and press Enter to continue..."
        read -r
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
    
    # Install Nix using the official installer
    curl -L https://nixos.org/nix/install | sh
    
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
        
        read -p "Enter your name: " git_name
        read -p "Enter your email: " git_email
        
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
    
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    echo
    
    # Step 1: Pre-flight checks
    log_info "Step 1/7: Checking system requirements..."
    check_macos
    check_architecture
    echo
    
    # Step 2: Install Xcode tools
    log_info "Step 2/7: Installing Xcode Command Line Tools..."
    check_xcode_tools
    echo
    
    # Step 3: Check Git
    log_info "Step 3/7: Checking Git configuration..."
    check_git
    echo
    
    # Step 4: Install Nix
    log_info "Step 4/7: Installing Nix package manager..."
    check_nix
    echo
    
    # Step 5: Install Rosetta (Apple Silicon only)
    log_info "Step 5/7: Installing Rosetta 2 (if needed)..."
    install_rosetta
    echo
    
    # Step 6: Backup and clone
    log_info "Step 6/7: Setting up dotfiles repository..."
    backup_existing
    clone_dotfiles
    echo
    
    # Step 7: Run the build
    log_info "Step 7/7: Building your macOS configuration..."
    log_info "This will install all applications and configure your system."
    log_warning "You may be asked for your password (sudo access required)."
    echo
    
    cd "$DOTFILES_DIR"
    
    if ! ./scripts/bin/rebuild; then
        log_error "Build failed. This could be due to:"
        log_info "1. Network issues downloading packages"
        log_info "2. Permission problems"
        log_info "3. macOS security settings blocking Nix"
        echo
        log_info "Troubleshooting steps:"
        log_info "1. Check your internet connection"
        log_info "2. Try running the build again: cd $DOTFILES_DIR && ./scripts/bin/rebuild"
        log_info "3. Check the BACKUPS.md file for recovery procedures"
        log_info "4. Review the error messages above for specific issues"
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
    echo "  ✅ Terminal: Ghostty with modern configuration"
    echo "  ✅ Shell: Zsh with Oh My Zsh, autosuggestions, syntax highlighting"
    echo "  ✅ Editor: Neovim with LSP support and modern plugins"
    echo "  ✅ Development: Git, Node.js, Python tools configured"
    echo "  ✅ Apps: Chrome, VS Code, and all your essential applications"
    echo "  ✅ macOS: System preferences optimized for productivity"
    echo
    
    log_info "Quick start commands:"
    echo "  update    - Update all packages and configuration"
    echo "  change    - Edit your dotfiles"
    echo "  nvim      - Launch Neovim editor"
    echo "  code      - Launch VS Code"
    echo
    
    log_info "Next steps:"
    echo "  1. Restart your terminal to load all changes"
    echo "  2. Run 'update' to ensure everything is up to date"
    echo "  3. Review BACKUPS.md in your dotfiles for maintenance info"
    echo
    
    log_info "Your dotfiles location: $DOTFILES_DIR"
    log_info "Backup location: $BACKUP_DIR (if applicable)"
    echo
    
    log_success "Happy coding! 🚀"
}

# Handle errors gracefully
cleanup_on_error() {
    log_error "Installation interrupted."
    
    if [[ -d "$DOTFILES_DIR" ]] && [[ -d "$BACKUP_DIR" ]]; then
        log_info "Would you like to restore the backup? (y/N)"
        read -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$DOTFILES_DIR"
            mv "$BACKUP_DIR" "$DOTFILES_DIR"
            log_success "Backup restored."
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
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Enable verbose output"
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