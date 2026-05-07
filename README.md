# setup_terminal.sh — Complete Reference

> A fully automated macOS terminal bootstrap script. One run takes a stock macOS install to a professional-grade developer terminal with a configured shell, prompt, history engine, fuzzy finder, and three Nerd Fonts — all idempotent, all safe to re-run.

---

## Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Usage](#usage)
4. [How It Works — Step by Step](#how-it-works--step-by-step)
   - [Safety Flags & Shell Behaviour](#safety-flags--shell-behaviour)
   - [Logging Helpers](#logging-helpers)
   - [Preflight Checks](#preflight-checks)
   - [Step 1 — Xcode Command Line Tools](#step-1--xcode-command-line-tools)
   - [Step 2 — Homebrew](#step-2--homebrew)
   - [Step 3 — Zsh](#step-3--zsh)
   - [Step 4 — Oh My Zsh](#step-4--oh-my-zsh)
   - [Step 5 — Zsh Plugins](#step-5--zsh-plugins)
   - [Step 6 — Powerlevel10k](#step-6--powerlevel10k)
   - [Step 7 — Nerd Fonts](#step-7--nerd-fonts)
   - [Step 8 — Starship](#step-8--starship)
   - [Step 9 — Atuin](#step-9--atuin)
   - [Step 10 — fzf](#step-10--fzf)
   - [Step 11 — ~/.zshrc](#step-11--zshrc)
   - [Step 12 — Terminal Font Auto-Configuration](#step-12--terminal-font-auto-configuration)
5. [Generated ~/.zshrc — Full Breakdown](#generated-zshrc--full-breakdown)
   - [Powerlevel10k Instant Prompt](#powerlevel10k-instant-prompt)
   - [Oh My Zsh & Theme](#oh-my-zsh--theme)
   - [Enabled Plugins](#enabled-plugins)
   - [Homebrew Environment](#homebrew-environment)
   - [Starship (commented out)](#starship-commented-out)
   - [Atuin Init](#atuin-init)
   - [fzf Configuration](#fzf-configuration)
   - [History Settings](#history-settings)
   - [Aliases — Navigation](#aliases--navigation)
   - [Aliases — Listing (eza)](#aliases--listing-eza)
   - [Aliases — File Viewing (bat)](#aliases--file-viewing-bat)
   - [Aliases — Git](#aliases--git)
   - [Aliases — Utilities](#aliases--utilities)
   - [Shell Functions](#shell-functions)
6. [Starship Configuration](#starship-configuration)
7. [Terminal Font Configuration — Per App](#terminal-font-configuration--per-app)
8. [Idempotency](#idempotency)
9. [After Running — Next Steps](#after-running--next-steps)
10. [Switching Between Powerlevel10k and Starship](#switching-between-powerlevel10k-and-starship)
11. [File Locations Reference](#file-locations-reference)

---

## Overview

| Property | Detail |
|---|---|
| **Shell** | `#!/usr/bin/env bash` |
| **Safety mode** | `set -euo pipefail` |
| **Target OS** | macOS (Darwin) only |
| **Architecture** | Apple Silicon (`arm64`) and Intel (`x86_64`) |
| **Run as root** | Blocked — must run as a normal user |
| **Idempotent** | Yes — every step checks before acting |
| **Total steps** | 12 |

---

## Requirements

- macOS (any version with Xcode CLT available)
- An internet connection
- A normal user account (not root)
- One of: Terminal.app, iTerm2, Ghostty, or Warp

The script self-installs every other dependency it needs.

---

## Usage

```bash
# 1. Make executable
chmod +x setup_terminal.sh

# 2. Run
./setup_terminal.sh
```

If Xcode Command Line Tools are not yet installed, the script launches the system installer dialog, prints instructions, and exits cleanly. Re-run it after the tools finish installing.

---

## How It Works — Step by Step

### Safety Flags & Shell Behaviour

```bash
set -euo pipefail
```

| Flag | Effect |
|---|---|
| `-e` | Exit immediately if any command returns a non-zero status |
| `-u` | Treat unset variables as errors |
| `-o pipefail` | A pipeline fails if any command in it fails, not just the last one |

Together these flags make the script fail loudly and early rather than silently continuing in a broken state.

---

### Logging Helpers

Five colour-coded logging functions are defined at the top and used throughout every section:

| Function | Colour | Symbol | Usage |
|---|---|---|---|
| `info` | Cyan | `[➜]` | Normal progress messages |
| `success` | Green | `[✔]` | Confirmation that a step completed |
| `warn` | Yellow | `[!]` | Non-fatal advisories |
| `error` | Red | `[✘]` | Fatal errors — prints to stderr and exits |
| `section` | Blue | `━━━` banner | Visual separator between major steps |

There is also a utility function:

```bash
append_if_missing() {
  local line="$1" file="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}
```

This appends a line to a file only when that exact line is not already present, preventing duplicate entries on re-runs.

---

### Preflight Checks

Before any installation begins, three checks run:

1. **Root guard** — `$EUID -eq 0` causes an immediate fatal error. Homebrew must never be installed as root.
2. **macOS guard** — `uname` is checked for `Darwin`. The script aborts on Linux or any other OS.
3. **System info** — Prints the macOS product name, version, and CPU architecture so the output log is self-documenting.

---

### Step 1 — Xcode Command Line Tools

```bash
xcode-select -p
```

Checks whether the Xcode CLT path is registered. If not, it triggers `xcode-select --install` which causes macOS to display a GUI dialog, then exits with instructions to re-run. This is necessary because the CLT installer is asynchronous — the script cannot wait for it inline.

The CLT provides `git`, `curl`, `make`, `clang`, and other build tools required by Homebrew and the `git clone` steps later.

---

### Step 2 — Homebrew

Checks for an existing `brew` binary via `command -v`. If missing, downloads and runs the official Homebrew installer with `NONINTERACTIVE=1` to suppress prompts.

After installation the script detects the CPU architecture to set `BREW_PREFIX` correctly:

| Architecture | Homebrew prefix |
|---|---|
| Apple Silicon (`arm64`) | `/opt/homebrew` |
| Intel (`x86_64`) | `/usr/local` |

It then runs `eval "$(...brew shellenv)"` to add Homebrew to `PATH` for the remainder of the script session without requiring a shell restart.

Two environment variables are exported to reduce noise:

```bash
export HOMEBREW_NO_ENV_HINTS=1   # suppresses the "run brew shellenv" hint
```

---

### Step 3 — Zsh

macOS ships with a system Zsh at `/bin/zsh`, but it is often outdated and Apple does not update it. This step installs the latest Zsh via Homebrew.

Three actions are performed:

1. **Install** `zsh` via `brew install zsh` if not already present.
2. **Register** the Homebrew Zsh path (`$(brew --prefix)/bin/zsh`) in `/etc/shells`. This is required by macOS before a shell can be set as the login shell. Uses `sudo tee -a`.
3. **Set as default** via `sudo chsh -s "$BREW_ZSH" "$USER"`. Only runs if the current `$SHELL` is not already pointing to the Homebrew Zsh.

---

### Step 4 — Oh My Zsh

Checks for `~/.oh-my-zsh`. If absent, downloads and runs the official installer with two environment flags:

```bash
RUNZSH=no    # don't exec into zsh immediately after install
CHSH=no      # don't run chsh — we already did it in Step 3
```

After installation, `ZSH_CUSTOM` is set to `~/.oh-my-zsh/custom` (with a fallback to the environment variable if already set). All community plugins and themes install into this path.

---

### Step 5 — Zsh Plugins

Two community plugins are installed by cloning into the Oh My Zsh custom plugins directory. Both use `--depth=1` (shallow clone) to minimise download size.

**zsh-autosuggestions** (`~/.oh-my-zsh/custom/plugins/zsh-autosuggestions`)
Shows grey ghost-text command completions in real time as you type, drawn from your shell history. Press `→` or `End` to accept.

**zsh-syntax-highlighting** (`~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting`)
Colours commands as you type them before you press Enter. Valid commands appear green, invalid ones red, arguments and paths in distinct colours.

---

### Step 6 — Powerlevel10k

Clones the Powerlevel10k repository into `~/.oh-my-zsh/custom/themes/powerlevel10k` using a shallow clone. It is activated by setting `ZSH_THEME="powerlevel10k/powerlevel10k"` in the generated `.zshrc`.

Powerlevel10k is a Zsh theme that renders a feature-rich, fully customisable prompt. Its key capability is the **instant prompt** feature: it caches the prompt rendering so the shell is interactive in under 50ms regardless of how many git checks or version lookups the prompt performs.

First-time configuration is done by running `p10k configure` after installation, which launches an interactive wizard that walks through every visual option.

---

### Step 7 — Nerd Fonts

Three font packages are installed via Homebrew Cask. The script first attempts `brew tap homebrew/cask-fonts` (suppressing errors if the tap has already been merged into core).

| Cask name | Font family | Why included |
|---|---|---|
| `font-meslo-lg-nerd-font` | MesloLGS Nerd Font Mono | Officially recommended by Powerlevel10k |
| `font-jetbrains-mono-nerd-font` | JetBrains Mono Nerd Font | Popular, highly legible coding font |
| `font-fira-code-nerd-font` | Fira Code Nerd Font | Supports programming ligatures |

Nerd Fonts are developer fonts patched with over 3,000 icons from icon sets including Font Awesome, Devicons, Powerline, and Material Design Icons. Without a Nerd Font, the icons in Powerlevel10k and Starship prompts render as missing-character boxes.

The loop checks `brew list --cask "$font"` before each install to skip fonts already present.

---

### Step 8 — Starship

Installs Starship via `brew install starship`. If no `~/.config/starship.toml` exists, the script writes a complete configuration file using a **Gruvbox Dark** colour palette. See [Starship Configuration](#starship-configuration) for the full breakdown of what that config does.

Starship is written in Rust and is cross-shell — the same binary and config works in Zsh, Bash, Fish, and others. In the generated `.zshrc` the Starship initialisation line is commented out by default since Powerlevel10k is set as the active theme. See [Switching](#switching-between-powerlevel10k-and-starship) for how to swap.

---

### Step 9 — Atuin

Installs Atuin via `brew install atuin`. Atuin replaces the standard shell history file with a **SQLite database**. Every command is stored with:

- Timestamp
- Exit code
- Working directory
- Hostname
- Shell session ID

The standard `Ctrl+R` reverse-history shortcut is replaced by Atuin's full-screen interactive TUI, which supports fuzzy search, filtering by host or directory, and sorting by recency or frequency.

Atuin also supports optional encrypted cloud sync across multiple machines using its hosted service or a self-hosted server.

---

### Step 10 — fzf

Installs fzf via `brew install fzf`, then runs the bundled shell integration installer:

```bash
"$(brew --prefix)/opt/fzf/install" --all --no-bash --no-fish
```

The `--all` flag installs key bindings and fuzzy completion. `--no-bash` and `--no-fish` restrict the integration to Zsh only.

This adds three Zsh key bindings:

| Binding | Action |
|---|---|
| `Ctrl+R` | Interactive fuzzy search through shell history |
| `Ctrl+T` | Fuzzy-select a file and insert its path at the cursor |
| `Alt+C` | Fuzzy-select a directory and `cd` into it |

---

### Step 11 — ~/.zshrc

The script backs up any existing `.zshrc` to a timestamped file (e.g. `.zshrc.bak.20250507_143022`) before overwriting it, so no previous configuration is lost.

A complete, fully annotated `.zshrc` is then written using a heredoc with the `'ZSHRC_CONTENT'` delimiter (single-quoted to prevent variable expansion during the write). See [Generated ~/.zshrc — Full Breakdown](#generated-zshrc--full-breakdown) for every section.

---

### Step 12 — Terminal Font Auto-Configuration

The script detects every installed terminal emulator and programmatically sets the font to **MesloLGS Nerd Font Mono** at 13pt. This removes the need for the user to manually navigate terminal preferences.

Four terminals are supported. See [Terminal Font Configuration — Per App](#terminal-font-configuration--per-app) for the exact mechanism used for each.

---

## Generated ~/.zshrc — Full Breakdown

### Powerlevel10k Instant Prompt

```zsh
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
```

Must appear at the very top of `.zshrc` before any output-generating code. It sources a pre-rendered prompt from cache so the shell is visually ready instantly while the rest of `.zshrc` finishes loading in the background.

---

### Oh My Zsh & Theme

```zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
zstyle ':omz:update' mode silent
```

Sets the Oh My Zsh installation path, activates the Powerlevel10k theme, and configures silent background updates so OMZ never interrupts a session with an update prompt.

---

### Enabled Plugins

```zsh
plugins=(
  git
  sudo
  z
  copypath
  web-search
  macos
  zsh-autosuggestions
  zsh-syntax-highlighting
)
```

| Plugin | What it provides |
|---|---|
| `git` | ~150 git aliases (`gst`, `gco`, `gp`, etc.) and prompt integration |
| `sudo` | Press `Esc` twice to prepend `sudo` to the current or previous command |
| `z` | Tracks directory visit frequency; `z proj` jumps to the most likely match |
| `copypath` | `copypath` copies the current working directory to the clipboard |
| `web-search` | `google foo`, `ddg foo`, `gh foo` open searches from the terminal |
| `macos` | `ofd` opens Finder at the current directory; `cdf` does the reverse |
| `zsh-autosuggestions` | Ghost-text history suggestions |
| `zsh-syntax-highlighting` | Real-time command colouring |

---

### Homebrew Environment

```zsh
if [[ "$(uname -m)" == "arm64" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv)"
fi
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ANALYTICS=1
```

Initialises Homebrew in the shell session for the correct architecture and opts out of both Homebrew's usage analytics and its environment hints.

---

### Starship (commented out)

```zsh
# eval "$(starship init zsh)"
```

Starship is installed and configured but inactive by default. The comment is intentional — Powerlevel10k and Starship cannot both run simultaneously since both hook into the `PROMPT` variable. See [Switching](#switching-between-powerlevel10k-and-starship).

---

### Atuin Init

```zsh
eval "$(atuin init zsh)"
```

Registers Atuin's Zsh hooks. This replaces the built-in `Ctrl+R` binding with Atuin's interactive TUI history search.

---

### fzf Configuration

```zsh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export FZF_DEFAULT_OPTS="
  --height 50%
  --layout=reverse
  --border=rounded
  --prompt='❯ '
  --color=fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8
  ..."
```

Sources the fzf shell integration file installed in Step 10. The `FZF_DEFAULT_OPTS` apply a **Catppuccin Mocha** colour scheme to every fzf invocation globally. Key options:

| Option | Effect |
|---|---|
| `--height 50%` | fzf opens in the bottom half of the terminal, not full-screen |
| `--layout=reverse` | Input at the top, results below |
| `--border=rounded` | Rounded border around the fzf window |

If `fd` (a faster `find` replacement) is installed, `FZF_DEFAULT_COMMAND` is set to use it instead of `find` for the `Ctrl+T` file search.

---

### History Settings

```zsh
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
```

| Setting | Effect |
|---|---|
| `HISTSIZE` / `SAVEHIST` | 100,000 entries in memory and on disk |
| `HIST_IGNORE_DUPS` | Consecutive duplicate commands are stored only once |
| `HIST_IGNORE_SPACE` | Commands prefixed with a space are never recorded |
| `SHARE_HISTORY` | All open shell sessions share the same history in real time |
| `EXTENDED_HISTORY` | Each entry is stored with a Unix timestamp and elapsed time |

---

### Aliases — Navigation

```zsh
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ~="cd ~"
```

Shorthand for moving up directory levels. `....` goes up three levels in one keystroke.

---

### Aliases — Listing (eza)

```zsh
alias ls="eza --icons --group-directories-first"
alias ll="eza -lah --icons --git --group-directories-first"
alias lt="eza --tree --icons --level=2"
alias ltt="eza --tree --icons --level=3"
```

These replace the default `ls` with `eza` when it is installed. Falls back to standard `ls -lah` if `eza` is not present. The `--git` flag on `ll` shows the git status of each file inline in the listing.

---

### Aliases — File Viewing (bat)

```zsh
alias cat="bat"
alias -g -- -h='-h 2>&1 | bat --language=help --style=plain'
```

Replaces `cat` with `bat` when available. The global alias for `-h` pipes any command's `--help` output through `bat` with help-text syntax highlighting, making man-page-style output colourful and readable.

---

### Aliases — Git

| Alias | Expands to |
|---|---|
| `g` | `git` |
| `gs` | `git status -sb` (short format with branch info) |
| `ga` | `git add` |
| `gaa` | `git add -A` (stage everything) |
| `gc` | `git commit -m` |
| `gca` | `git commit --amend --no-edit` |
| `gp` | `git push` |
| `gpf` | `git push --force-with-lease` (safe force push) |
| `gl` | `git log --oneline --graph --decorate --all` |
| `gd` | `git diff` |
| `gco` | `git checkout` |
| `gcb` | `git checkout -b` |

Note: `gpf` uses `--force-with-lease` rather than `--force`. This is safer because it refuses to overwrite remote commits that you have not fetched locally.

---

### Aliases — Utilities

| Alias | What it does |
|---|---|
| `reload` | Sources `~/.zshrc` in the current session |
| `zshrc` | Opens `~/.zshrc` in `$EDITOR` |
| `ip` | Prints your public IP address via `ipinfo.io` |
| `flush` | Flushes the macOS DNS cache |
| `cleanup` | Recursively deletes all `.DS_Store` files in the current tree |
| `brewup` | Runs a full Homebrew update cycle: `update`, `upgrade`, `autoremove`, `cleanup` |

---

### Shell Functions

Four custom functions are written into `.zshrc`:

**`mkcd <dir>`** — Creates a directory (including any missing parents) and `cd`s into it in one step.

```zsh
mkcd() { mkdir -p "$1" && cd "$1"; }
```

**`fcd [dir]`** — Uses `find` and `fzf` to display an interactive directory picker. Selecting an entry navigates into it. Starts from the current directory by default, or a given path.

```zsh
fcd() {
  local dir
  dir=$(find ${1:-.} -type d 2>/dev/null | fzf +m) && cd "$dir"
}
```

**`fkill`** — Pipes the running process list through `fzf` for interactive selection, then kills the chosen process. Accepts an optional signal number argument (defaults to 9).

```zsh
fkill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf -m --header="Select process(es) to kill" | awk '{print $2}')
  [[ -n "$pid" ]] && echo "$pid" | xargs kill -${1:-9}
}
```

**`extract <file>`** — Detects archive type by file extension and runs the correct decompression command. Supports `.tar.gz`, `.tar.bz2`, `.tar.xz`, `.tar`, `.bz2`, `.gz`, `.zip`, and `.7z`.

---

## Starship Configuration

The script writes a `~/.config/starship.toml` using the **Gruvbox Dark** palette only if no config file already exists. The prompt is structured as a segmented powerline-style bar.

**Prompt segments, left to right:**

| Segment | Shows | Colour |
|---|---|---|
| OS icon | Apple logo | Orange |
| Username | Current user | Orange |
| Directory | Truncated path (3 levels) | Yellow |
| Git branch | Branch name with icon | Aqua |
| Git status | Ahead/behind/dirty indicators | Aqua |
| Runtime | Node.js, Python, Rust, or Go version (auto-detected) | Blue |
| Docker context | Active Docker context name | Dark grey |
| Time | Current time in `HH:MM` format | Dark |

The palette maps named colour variables (e.g. `color_orange`, `color_aqua`) to specific Gruvbox hex values, making it easy to retheme by changing only the palette section.

---

## Terminal Font Configuration — Per App

The font PostScript name used across all terminals is `MesloLGSNerdFontMono-Regular` at 13pt.

### Terminal.app

Uses `osascript` (AppleScript) to iterate over every settings set (profile) and call:

```applescript
tell application "Terminal"
  repeat with s in settings sets
    set font name of s to "MesloLGSNerdFontMono-Regular"
    set font size of s to 13
  end repeat
end tell
```

This modifies all profiles in a single pass without needing to know their names.

### iTerm2

Uses `/usr/libexec/PlistBuddy` — a built-in macOS tool for editing plist files — to write directly into `~/Library/Preferences/com.googlecode.iterm2.plist`. For each profile in the `New Bookmarks` array it sets both `Normal Font` (ASCII text) and `Non Ascii Font` (non-Latin characters) to `MesloLGSNerdFontMono-Regular 13`. Uses a try-then-add pattern: attempts `Set` first, falls back to `Add` if the key does not yet exist. If iTerm2 is running when the script executes, a warning is printed because iTerm2 overwrites the plist on quit, which would discard the changes.

### Ghostty

Writes two lines into `~/.config/ghostty/config`:

```
font-family = MesloLGS Nerd Font Mono
font-size = 13
```

If either key already exists in the config, `sed -i ''` (BSD in-place) replaces the existing line rather than duplicating it. The config directory is created if it does not exist.

### Warp

Warp stores its settings in an internal Electron data store that is not safely writable from the command line. The script detects Warp and prints manual navigation instructions instead:

```
Warp → Settings (Cmd+,) → Appearance → Font → MesloLGS Nerd Font Mono
```

---

## Idempotency

Every installation step checks for an existing installation before acting. The table below summarises the guard used for each component:

| Component | Guard condition |
|---|---|
| Xcode CLT | `xcode-select -p` succeeds |
| Homebrew | `command -v brew` succeeds |
| Zsh | `brew list zsh` succeeds |
| `/etc/shells` entry | `grep -q "$BREW_ZSH" /etc/shells` |
| Default shell | `$SHELL == $BREW_ZSH` |
| Oh My Zsh | `~/.oh-my-zsh` directory exists |
| zsh-autosuggestions | plugin directory exists |
| zsh-syntax-highlighting | plugin directory exists |
| Powerlevel10k | theme directory exists |
| Each Nerd Font | `brew list --cask $font` succeeds |
| Starship | `command -v starship` succeeds |
| Starship config | `~/.config/starship.toml` file exists |
| Atuin | `command -v atuin` succeeds |
| fzf | `command -v fzf` succeeds |

The `.zshrc` is always overwritten (with a timestamped backup), as is the terminal font configuration, since both are idempotent by nature.

---

## After Running — Next Steps

1. **Restart your terminal** — fully quit and reopen it (not just a new tab) so the new default shell and `.zshrc` take effect.

2. **Run the Powerlevel10k wizard:**
   ```zsh
   p10k configure
   ```
   This interactive wizard walks through every visual option — prompt style, icons, colour scheme, clock, and more. It writes your choices to `~/.p10k.zsh`.

3. **Optionally install recommended extras:**
   ```bash
   brew install eza bat lazygit fd ripgrep
   ```
   These are referenced in the `.zshrc` aliases but not installed by the script since they are optional enhancements rather than core requirements.

---

## Switching Between Powerlevel10k and Starship

Both are installed. They cannot run simultaneously. To switch from Powerlevel10k to Starship, edit `~/.zshrc` and make three changes:

```zsh
# 1. Comment out (or remove) the p10k instant prompt block at the top

# 2. Change the theme to blank
ZSH_THEME=""

# 3. Uncomment the Starship init line
eval "$(starship init zsh)"
```

To switch back, reverse those changes and re-run `p10k configure`.

---

## File Locations Reference

| File / Directory | Purpose |
|---|---|
| `~/.oh-my-zsh/` | Oh My Zsh installation |
| `~/.oh-my-zsh/custom/themes/powerlevel10k/` | Powerlevel10k theme |
| `~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/` | Autosuggestions plugin |
| `~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/` | Syntax highlighting plugin |
| `~/.zshrc` | Main Zsh configuration (generated by this script) |
| `~/.zshrc.bak.YYYYMMDD_HHMMSS` | Timestamped backup of previous `.zshrc` |
| `~/.p10k.zsh` | Powerlevel10k prompt config (generated by `p10k configure`) |
| `~/.config/starship.toml` | Starship prompt config (generated by this script) |
| `~/.fzf.zsh` | fzf shell integration (generated by fzf installer) |
| `~/.zsh_history` | Zsh history file (100,000 entries) |
| `~/.config/ghostty/config` | Ghostty terminal config (font written here) |
| `~/Library/Preferences/com.googlecode.iterm2.plist` | iTerm2 preferences (font written here) |
