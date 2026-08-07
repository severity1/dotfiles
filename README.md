# severity1's Personal Configs

This repository contains my personal configuration files for various tools and applications.

## Structure

```text
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
├── claude/                    # Claude Code configuration
│   ├── CLAUDE.md              # Global instructions
│   ├── settings.json          # Global settings
│   └── statusline-command.sh  # Custom statusline script
├── codex/                     # Codex CLI configuration
│   └── config.toml            # Global settings, includes the STE hook
├── bin/                       # Scripts shared by more than one tool
│   └── ste-reminder           # Writing-rules hook (Claude Code + Codex)
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
- Custom settings with LSP tools, plugins, and permissions
- Statusline script (see below)
- Location: `~/.claude/`

### Simplified Technical English hook

`bin/ste-reminder` prints the writing rules. Claude Code and Codex both run it on the `UserPromptSubmit` event, so the rules arrive next to the newest turn instead of fading with the system prompt. The script lives in `~/.local/bin/` because two tools share it.

The rules come in two parts, and the file says which is which:

- **Part 1 is ASD-STE100**, checked against the specification (Issue 9, 15 January 2025, free at <https://www.asd-ste100.org>). It applies the 53 writing rules. It does not apply the dictionary of about 900 approved words, because that dictionary rejects normal technical vocabulary.
- **Part 2 is house style.** No em dashes, no emojis, no marketing tone, and no success claim without proof. These are not in the specification, and the file says so.

`claude/CLAUDE.md` carries the same split for the sessions that read it directly.

The same rules ship as the `slalom-ste` plugin in `slalom-agent-kit`, which adds a Kiro path. Kiro has no prompt-submit event, so Kiro reads a steering file instead of running a hook.

#### Statusline

Three lines, rendered by `claude/statusline-command.sh` and wired through the
`statusLine` setting. Requires `jq` and `git`. Colors follow the oh-my-bash
Mairan theme.

```text
[opus @ 3b8ed793][~/Workspace/acme/api-gateway][±][main S:1 +2/-0 ✗]
[7% of 1M · 5.3M↑ 11k↓ · 97% cached (+1k w) · 48 tools/5 · 3 skills · 6 turns]
[34% 5h ↻3h 14m · 12% 7d · $13.23 · 1h 16m (37% wait) · +342/-517]
```

- Line 1 is identity: model, session id, path, git state. Always renders.
- Line 2 is the session: context used, cumulative tokens, prompt-cache hit
  rate, and tool / skill / MCP / subagent / turn counts.
- Line 3 is what that consumed: rate-limit windows, cost, elapsed time with
  the share spent waiting on the model, and lines changed.

Every field is independently conditional, so a new session shows one or two
short lines and fills out as it goes. The budget field adapts to the account
rather than being configured for it: a subscription reports 5h / 7d rate-limit
windows, API billing reports dollars, and whichever the payload carries is
what renders.

Cumulative token and tool counts are summed from the session transcript, since
the payload reports only the latest message. That scan is cached per session
in `$TMPDIR` and keyed on transcript size, so repaints stay cheap as a session
grows. Widths target 120 columns; the script cannot read the real terminal
width, so that is a design constraint rather than a runtime check.

Written for bash 3.2 to suit the `/bin/bash` that ships with macOS.

## Installation

### Automated Installation (Recommended)

Run the installation script from the repository directory:

```bash
./install.sh
```

The script will:

- Check for required dependencies (Ghostty, Neovim, Git, jq)

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

#### Claude Code Configuration

```bash
mkdir -p ~/.claude
cp claude/CLAUDE.md ~/.claude/CLAUDE.md
cp claude/settings.json ~/.claude/settings.json
cp claude/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

#### Writing-rules hook (Claude Code + Codex)

```bash
mkdir -p ~/.local/bin ~/.codex
cp bin/ste-reminder ~/.local/bin/ste-reminder
chmod +x ~/.local/bin/ste-reminder
cp codex/config.toml ~/.codex/config.toml
```

The Codex copy overwrites `~/.codex/config.toml`. Back up your own file first if it holds model, proxy, or MCP settings.

## Notes

This repository is intended to capture and version control personal
configuration files for easy portability across machines and backup
purposes.
