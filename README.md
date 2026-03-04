# Fedora COSMIC Atomic - Dev Environment

Infrastructure as code for setting up a complete development environment on Fedora COSMIC Atomic (arm64/aarch64).

One command to go from a fresh install to a fully configured system with terminal, shell, dev containers, and AI coding tools.

## What's included

| Component | Details |
|-----------|---------|
| **Shell** | ZSH + Zinit (syntax-highlighting, completions, autosuggestions, fzf-tab) |
| **Prompt** | Oh My Posh with custom nugget theme |
| **Terminal** | Ghostty with Rose Pine Dawn / iTerm2 Solarized Dark |
| **Tools** | fzf, zoxide, fnm (Node.js) |
| **Dev: Web** | Node.js (LTS), TypeScript, ESLint, Prettier |
| **Dev: Mobile** | Flutter SDK, Dart, Android SDK |
| **AI** | Claude Code, OpenAI Codex CLI |
| **MCPs** | context7, exa, playwright (Firefox) |
| **Dotfiles** | Managed by chezmoi with templates |

## Quick start

### On a fresh Fedora COSMIC Atomic install:

```bash
curl -fsSL https://raw.githubusercontent.com/Aldo-Serrano/fedora-atomic-init/main/bootstrap.sh | bash
```

This will:
1. Install chezmoi
2. Prompt for API keys (Anthropic, OpenAI, Exa) and git identity
3. Layer essential packages via rpm-ostree
4. Install Ghostty, Oh My Posh, Nerd Fonts, fnm
5. Apply all dotfiles (.zshrc, Ghostty config, Oh My Posh theme, Claude MCP config)
6. Create and configure Distrobox dev containers

> **Note:** A reboot is required after rpm-ostree layering. After reboot, run `chezmoi apply` to continue.

### On subsequent machines:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply Aldo-Serrano
```

## Project structure

```
.chezmoi.toml.tmpl                     # Chezmoi config (prompts for API keys)
.chezmoiignore                         # OS-specific file filtering
dot_zshrc.tmpl                         # ZSH configuration
dot_config/
  ohmyposh/nugget.toml                 # Oh My Posh theme
  ghostty/config.tmpl                  # Ghostty terminal config
  claude/mcp.json.tmpl                 # Claude Code MCP servers
run_once_before_01-rpm-ostree.sh.tmpl  # Host package layering
run_once_before_02-install-tools.sh    # External tools installation
run_once_after_01-setup-containers.sh  # Distrobox container creation
run_once_after_02-setup-dev-flutter.sh # Flutter container setup
run_once_after_03-setup-dev-web.sh     # Web container setup
dot_local/bin/
  executable_fedora-update.sh          # System-wide update script
```

## Usage

### Enter dev containers

```bash
dev-web       # alias for: distrobox enter dev-web
dev-flutter   # alias for: distrobox enter dev-flutter
```

### Update everything

```bash
fedora-update.sh
```

Updates rpm-ostree, Flatpak, Distrobox containers, Oh My Posh, Node.js, and chezmoi dotfiles.

### Modify configuration

```bash
chezmoi edit ~/.zshrc         # Edit ZSH config
chezmoi edit ~/.config/ghostty/config  # Edit Ghostty config
chezmoi apply                 # Apply changes
chezmoi cd                    # Go to chezmoi source directory
```

## Known issues

- **Claude Code on ARM64**: There are [known issues](https://github.com/anthropics/claude-code/issues/3569) with ARM64 Linux. Installation may fail; scripts include fallbacks.
- **rpm-ostree reboot**: Package layering requires a reboot. The bootstrap handles this gracefully.
- **Ghostty COPR**: The COPR repo may not always have the latest version. Build from source as alternative.
- **Android emulator on ARM64**: Hardware acceleration may be limited in VM environments (Parallels).

## Requirements

- Fedora COSMIC Atomic (arm64 or x86_64)
- Internet connection
- GitHub account (for chezmoi sync)
