# severity1's Personal Configs

This repository contains my personal configuration files for various tools and applications.

## Structure

```
severity1/
├── ghostty/          # Ghostty terminal emulator configuration
│   └── config
└── nvim/             # Neovim/LazyVim configuration
    ├── init.lua
    ├── .gitignore
    ├── .neoconf.json
    ├── stylua.toml
    ├── lazyvim.json
    └── lua/
        ├── config/   # Core configuration files
        └── plugins/  # Plugin configurations
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

## Installation

To use these configurations:

### Ghostty
```bash
cp ghostty/config ~/.config/ghostty/config
```

### Neovim
```bash
cp -r nvim/* ~/.config/nvim/
```

## Notes

This repository is intended to capture and version control personal configuration files for easy portability across machines and backup purposes.
