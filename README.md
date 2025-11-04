# severity1's Personal Configs

This repository contains my personal configuration files for various tools and applications.

## Structure

```
severity1/
├── ghostty/          # Ghostty terminal emulator configuration
│   └── config
├── nvim/             # Neovim/LazyVim configuration
│   ├── init.lua
│   ├── .gitignore
│   ├── .neoconf.json
│   ├── stylua.toml
│   ├── lazyvim.json
│   └── lua/
│       ├── config/   # Core configuration files
│       └── plugins/  # Plugin configurations
├── claude/           # Claude Code configuration
│   ├── CLAUDE.md     # Global instructions
│   └── settings.json # Global settings
└── install.sh        # Automated installation script
```

## Configurations

### Ghostty Terminal
- Font size: 12
- Theme: Catppuccin Mocha
- Shell integration: zsh with sudo and cursor features
- Location: `~/.config/ghostty/config`

### Neovim/LazyVim
- Based on LazyVim starter configuration
- Language support: TypeScript/JavaScript, Python, Go, Rust, Terraform
- Custom terminal integration with toggleterm.nvim (height: 20 lines)
- Location: `~/.config/nvim/`

### Claude Code
- Global instructions with tool preferences and code standards
- Custom settings for hooks and environment
- Location: `~/.claude/`

## Installation

### Automated Installation (Recommended)

Run the installation script from the repository directory:

```bash
./install.sh
```

The script will:
- Check for required dependencies (Ghostty, Neovim, Git)
- Validate optional language toolchains (Node.js, Python, Go, Rust, Terraform)
- Back up existing configurations to `~/.config-backup-TIMESTAMP/`
- Install all configurations to their respective locations
- Display post-installation instructions

### Manual Installation

If you prefer to install configurations manually:

#### Ghostty
```bash
mkdir -p ~/.config/ghostty
cp ghostty/config ~/.config/ghostty/config
```

#### Neovim
```bash
mkdir -p ~/.config/nvim
cp -r nvim/* ~/.config/nvim/
```

#### Claude Code
```bash
mkdir -p ~/.claude
cp claude/CLAUDE.md ~/.claude/CLAUDE.md
cp claude/settings.json ~/.claude/settings.json
```

## Notes

This repository is intended to capture and version control personal configuration files for easy portability across machines and backup purposes.
