# Fedora COSMIC Atomic - Dev Environment

Infrastructure as code for setting up a complete development environment on Fedora COSMIC Atomic (arm64/aarch64).

One command to go from a fresh install to a fully configured system with terminal, shell, dev containers, and AI coding tools.

## What's included

| Component | Details |
|-----------|---------|
| **Shell** | ZSH + Zinit (syntax-highlighting, completions, autosuggestions, fzf-tab) |
| **Prompt** | Oh My Posh with custom nugget theme |
| **Terminal** | Ghostty with Rose Pine Dawn / iTerm2 Solarized Dark |
| **Tools** | fzf, zoxide, tmux, fnm (Node.js) |
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
3. Layer essential packages via rpm-ostree (zsh, fzf, zoxide, tmux, etc.)
4. Install Ghostty, Oh My Posh, Nerd Fonts, fnm
5. Apply all dotfiles (.zshrc, Ghostty config, Oh My Posh theme, Claude MCP config)

After reboot (required for rpm-ostree), run the bootstrap again to set up containers:

```bash
~/.local/bin/bootstrap-fedora.sh
```

This creates and configures the Toolbx dev containers with the full terminal environment.

### On subsequent machines:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply Aldo-Serrano
```

## Project structure

```
.chezmoi.toml.tmpl                     # Chezmoi config (prompts for API keys)
.chezmoiignore                         # OS-specific file filtering
dot_zshrc.tmpl                         # ZSH configuration (cross-platform)
dot_config/
  ohmyposh/nugget.toml                 # Oh My Posh theme
  ghostty/config.tmpl                  # Ghostty terminal config
  claude/mcp.json.tmpl                 # Claude Code MCP servers
run_once_before_01-rpm-ostree.sh.tmpl  # Host package layering
run_once_before_02-install-tools.sh    # External tools installation
dot_local/bin/
  executable_setup-dev-containers.sh   # Toolbx container setup (idempotent)
  executable_fedora-update.sh          # System-wide update script
```

## Dev containers

Uses **Toolbx** (Fedora's default container tool). Containers share your home directory, so all dotfiles, oh-my-posh, zinit, fnm, and tools are automatically available inside containers.

Each container also has system-level tools installed: zsh, fzf, zoxide, tmux, with ZSH as the default shell.

### Enter dev containers

```bash
dev-web       # alias for: toolbox enter dev-web
dev-flutter   # alias for: toolbox enter dev-flutter
```

### Re-run container setup

```bash
setup-dev-containers.sh
```

The script is idempotent, so it's safe to run multiple times.

## Syncing from macOS

The `.zshrc` template is cross-platform. To keep Fedora in sync with your Mac config:

### On macOS (push changes):

```bash
chezmoi cd                    # Go to chezmoi source directory
git add -A && git commit -m "Update config"
git push
```

### On Fedora (pull changes):

```bash
chezmoi update
```

Or use `fedora-update.sh` which includes `chezmoi update` along with all other updates.

## Update everything

```bash
fedora-update.sh
```

Updates rpm-ostree, Flatpak, Toolbx containers, Oh My Posh, Node.js, and chezmoi dotfiles.

## Modify configuration

```bash
chezmoi edit ~/.zshrc                  # Edit ZSH config
chezmoi edit ~/.config/ghostty/config  # Edit Ghostty config
chezmoi apply                          # Apply changes
chezmoi cd                             # Go to chezmoi source directory
```

## Known issues

- **Claude Code on ARM64**: There are [known issues](https://github.com/anthropics/claude-code/issues/3569) with ARM64 Linux. Installation may fail; scripts include fallbacks.
- **rpm-ostree reboot**: Package layering requires a reboot. The bootstrap handles this with a two-phase approach.
- **Ghostty COPR**: The COPR repo may not always have the latest version. Build from source as alternative.
- **Android emulator on ARM64**: Hardware acceleration may be limited in VM environments (Parallels).

## Requirements

- Fedora COSMIC Atomic (arm64 or x86_64)
- Internet connection
- GitHub account (for chezmoi sync)
