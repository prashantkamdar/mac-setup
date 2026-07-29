# mac-setup

A single-script terminal setup for a new Mac. Run it once and get the exact same shell environment — prompt, tools, aliases, plugins, and all.

## What it installs

### Shell
- **zsh** (macOS default)
- **Oh My Zsh** — framework for managing zsh config
- **Powerlevel10k** — prompt theme (lean style, instant prompt enabled)

### Oh My Zsh plugins
| Plugin | Purpose |
|--------|---------|
| `git` | Git aliases and helpers |
| `docker` | Docker completions |
| `docker-compose` | docker-compose completions |
| `npm` / `node` | npm/node completions |
| `zsh-autosuggestions` | Fish-style command suggestions |
| `zsh-syntax-highlighting` | Syntax colouring as you type |
| `zsh-completions` | Extra completion definitions |

### CLI tools (via Homebrew)
| Tool | Purpose |
|------|---------|
| `eza` | Better `ls` — aliased as `ls`, `ll`, `lt` |
| `bat` | Better `cat` with syntax highlighting |
| `fd` | Better `find` |
| `ripgrep` | Better `grep` |
| `fzf` | Fuzzy finder |
| `glow` | Markdown viewer in the terminal |
| `zoxide` | Smarter `cd` that learns your dirs |
| `atuin` | Shell history search (replaces Ctrl+R) |
| `btop` / `htop` / `bottom` / `gtop` | System monitors |
| `node` | Node.js runtime |
| `python@3.14` | Python runtime |
| `ollama` | Run LLMs locally |

### GUI apps (via Homebrew Cask)
- AltTab (Windows-style alt-tab switcher)
- Cursor (AI editor — installed via cask)
- Cursor CLI (installed via `curl https://cursor.com/install`)
- ForkLift (Finder replacement / file transfer)
- iTerm2
- Visual Studio Code
- Sublime Text
- Postman
- TablePlus
- JetBrains Mono Nerd Font
- MesloLGS Nerd Font (used by iTerm2 profile + Powerlevel10k)

### iTerm2
- Full preferences are exported as `com.googlecode.iterm2.plist` — keep it alongside `setup.sh`
- Includes the **Catppuccin Frappé** color theme and all profile settings
- The script imports it automatically after installing iTerm2; restart iTerm2 after setup to apply

### Dotfiles written
| File | Purpose |
|------|---------|
| `~/.zprofile` | Initialises Homebrew on Apple Silicon |
| `~/.zshrc` | Main shell config — plugins, aliases, tool inits, `cursor-chats` function |
| `~/.p10k.zsh` | Powerlevel10k prompt configuration |

## Aliases

```zsh
ls   → eza --icons
ll   → eza -la --icons --git
lt   → eza --tree --icons --level=2
cat  → bat --paging=never
find → fd
grep → rg
gtop → TERM=xterm gtop
```

## Usage

```bash
chmod +x setup.sh && ./setup.sh
```

Open a new terminal tab after it completes. If the prompt looks off, run:

```bash
p10k configure
```

## Notes

- Designed for **Apple Silicon Macs** (Homebrew at `/opt/homebrew`). Works on Intel Macs too since the script checks for an existing Homebrew install.
- The script is **idempotent** — safe to re-run. Already-installed components are skipped.
- No secrets or credentials are embedded. Safe to host publicly.
