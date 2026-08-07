#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions for colored output
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}→${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}===${NC} $1 ${BLUE}===${NC}"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Platform detection
check_platform() {
    print_header "Platform Detection"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_success "Running on macOS"
        return 0
    else
        print_warning "This script is designed for macOS but will attempt to continue"
        print_warning "Detected platform: $OSTYPE"
        return 0
    fi
}

# Check required dependencies
check_dependencies() {
    print_header "Dependency Checks"
    local missing_deps=()

    # Check for Ghostty
    if command_exists ghostty || [ -d "/Applications/Ghostty.app" ]; then
        print_success "Ghostty is installed"
    else
        print_error "Ghostty is not installed"
        missing_deps+=("Ghostty")
    fi

    # Check for Neovim
    if command_exists nvim; then
        local nvim_version
        nvim_version=$(nvim --version | head -n1)
        print_success "Neovim is installed ($nvim_version)"
    else
        print_error "Neovim is not installed"
        missing_deps+=("Neovim")
    fi

    # Check for Git (required for LazyVim, and by the Claude Code statusline)
    if command_exists git; then
        print_success "Git is installed"
    else
        print_error "Git is not installed (required for LazyVim plugin manager)"
        missing_deps+=("Git")
    fi

    # Check for jq - the Claude Code statusline parses its payload with it on
    # every repaint, so without jq the statusline renders broken continuously
    # rather than failing once and visibly.
    if command_exists jq; then
        print_success "jq is installed"
    else
        print_error "jq is not installed (required by the Claude Code statusline)"
        missing_deps+=("jq")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install missing dependencies before continuing"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "Installation suggestions:"
            for dep in "${missing_deps[@]}"; do
                case "$dep" in
                    "Ghostty")
                        print_info "  Ghostty: Download from https://ghostty.org"
                        ;;
                    "Neovim")
                        print_info "  Neovim: brew install neovim"
                        ;;
                    "Git")
                        print_info "  Git: brew install git"
                        ;;
                    "jq")
                        print_info "  jq: brew install jq"
                        ;;
                esac
            done
        fi
        return 1
    fi

    return 0
}

# Check language toolchains (optional but recommended for LSPs)
check_toolchains() {
    print_header "Language Toolchain Validation"
    local warnings=()

    # Check Node.js (for TypeScript/JavaScript LSP)
    if command_exists node; then
        local node_version
        node_version=$(node --version)
        print_success "Node.js is installed ($node_version)"
    else
        print_warning "Node.js is not installed (needed for TypeScript/JavaScript LSP)"
        warnings+=("Node.js")
    fi

    # Check Python (for Python LSP)
    if command_exists python3; then
        local python_version
        python_version=$(python3 --version)
        print_success "Python 3 is installed ($python_version)"
    else
        print_warning "Python 3 is not installed (needed for Python LSP)"
        warnings+=("Python 3")
    fi

    # Check Go (for Go LSP)
    if command_exists go; then
        local go_version
        go_version=$(go version | awk '{print $3}')
        print_success "Go is installed ($go_version)"
    else
        print_warning "Go is not installed (needed for Go LSP)"
        warnings+=("Go")
    fi

    # Check Rust (for Rust LSP)
    if command_exists rustc; then
        local rust_version
        rust_version=$(rustc --version | awk '{print $2}')
        print_success "Rust is installed ($rust_version)"
    else
        print_warning "Rust is not installed (needed for Rust LSP)"
        warnings+=("Rust")
    fi

    # Check Terraform (for Terraform LSP)
    if command_exists terraform; then
        local tf_version
        tf_version=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || echo "version unknown")
        print_success "Terraform is installed ($tf_version)"
    else
        print_warning "Terraform is not installed (needed for Terraform LSP)"
        warnings+=("Terraform")
    fi

    if [ ${#warnings[@]} -gt 0 ]; then
        echo ""
        print_info "Missing optional language toolchains: ${warnings[*]}"
        print_info "Neovim will work, but LSP features will be limited for these languages"
        print_info "Install toolchains later if needed for development"
    fi
}

# Backup existing configs
backup_configs() {
    print_header "Backup Existing Configs"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="$HOME/.config-backup-$timestamp"
    local backed_up=0

    # Check if any configs exist
    local ghostty_config="$HOME/.config/ghostty/config"
    local nvim_dir="$HOME/.config/nvim"
    local claude_dir="$HOME/.claude"
    local codex_dir="$HOME/.codex"

    if [ -f "$ghostty_config" ] || [ -d "$nvim_dir" ] || [ -d "$claude_dir" ] || [ -d "$codex_dir" ]; then
        print_info "Creating backup at: $backup_dir"
        mkdir -p "$backup_dir"

        # Backup Ghostty config
        if [ -f "$ghostty_config" ]; then
            mkdir -p "$backup_dir/ghostty"
            cp "$ghostty_config" "$backup_dir/ghostty/config"
            print_success "Backed up Ghostty config"
            backed_up=1
        fi

        # Backup Neovim config
        if [ -d "$nvim_dir" ]; then
            cp -r "$nvim_dir" "$backup_dir/nvim"
            print_success "Backed up Neovim config"
            backed_up=1
        fi

        # Backup Claude Code config
        if [ -d "$claude_dir" ]; then
            cp -r "$claude_dir" "$backup_dir/claude"
            print_success "Backed up Claude Code config"
            backed_up=1
        fi

        # Backup Codex config. install_configs overwrites config.toml, which may
        # already hold model, proxy, or MCP settings that are not tracked here.
        if [ -d "$codex_dir" ]; then
            cp -r "$codex_dir" "$backup_dir/codex"
            print_success "Backed up Codex config"
            backed_up=1
        fi

        if [ $backed_up -eq 1 ]; then
            print_success "Backup completed successfully"
        fi
    else
        print_info "No existing configs found, skipping backup"
    fi
}

# Install configs
install_configs() {
    print_header "Installing Configurations"

    # Create necessary directories
    print_info "Creating config directories"
    mkdir -p "$HOME/.config/ghostty"
    mkdir -p "$HOME/.config/nvim"
    mkdir -p "$HOME/.claude"
    mkdir -p "$HOME/.codex"
    mkdir -p "$HOME/.local/bin"

    # Copy Ghostty config
    print_info "Installing Ghostty config"
    cp "$SCRIPT_DIR/ghostty/config" "$HOME/.config/ghostty/config"
    print_success "Ghostty config installed"

    # Copy Neovim config
    print_info "Installing Neovim config"
    cp -r "$SCRIPT_DIR/nvim"/* "$HOME/.config/nvim/"
    print_success "Neovim config installed"

    # Copy Claude Code config
    print_info "Installing Claude Code config"
    cp "$SCRIPT_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    cp "$SCRIPT_DIR/claude/settings.json" "$HOME/.claude/settings.json"
    cp "$SCRIPT_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
    chmod +x "$HOME/.claude/statusline-command.sh"
    print_success "Claude Code config installed"

    # Copy the shared writing-rules hook. Claude Code and Codex both run it on
    # UserPromptSubmit, so it lives outside either tool's config directory.
    print_info "Installing the STE writing-rules hook"
    cp "$SCRIPT_DIR/bin/ste-reminder" "$HOME/.local/bin/ste-reminder"
    chmod +x "$HOME/.local/bin/ste-reminder"
    print_success "STE hook installed"

    # Copy Codex config
    print_info "Installing Codex config"
    cp "$SCRIPT_DIR/codex/config.toml" "$HOME/.codex/config.toml"
    print_success "Codex config installed"
}

# Display post-install instructions
post_install_instructions() {
    print_header "Installation Complete"
    echo ""
    print_success "Configuration files have been installed successfully"
    echo ""
    print_info "Next steps:"
    echo "  1. Launch Neovim by running: nvim"
    echo "  2. LazyVim will automatically install plugins on first launch"
    echo "  3. Mason will automatically install LSP servers and tools"
    echo "  4. This may take a few minutes depending on your internet connection"
    echo ""
    print_info "Useful Neovim commands:"
    echo "  :Lazy         - Manage plugins"
    echo "  :Mason        - Manage LSP servers and tools"
    echo "  :checkhealth  - Verify installation health"
    echo "  Ctrl+\\        - Toggle integrated terminal"
    echo ""
    print_info "Claude Code configurations:"
    echo "  Global instructions and settings installed to ~/.claude/"
    echo "  Restart Claude Code to pick up new configurations"
    echo ""

    # Check for Nerd Font
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "Note: Nerd Font is recommended for icon support"
        print_info "Install via: brew install --cask font-jetbrains-mono-nerd-font"
    fi
}

# Main installation flow
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Severity1 Dotfiles Installation      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

    # Run all checks and installation steps
    check_platform

    if ! check_dependencies; then
        exit 1
    fi

    check_toolchains
    backup_configs
    install_configs
    post_install_instructions

    echo ""
    print_success "Installation completed successfully"
    echo ""
}

# Run main function
main "$@"
