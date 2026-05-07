#!/usr/bin/env bash
# ==============================================================================
#  macOS Terminal Setup — Full Bootstrap
#  Installs: Homebrew · Zsh · Oh My Zsh · Powerlevel10k · Nerd Fonts
#            Starship · Atuin · fzf · zsh-autosuggestions · zsh-syntax-highlighting
# ==============================================================================
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m';  GREEN='\033[0;32m';  YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m';   BOLD='\033[1m';  RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}${BOLD}[➜]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[✔]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[✘]${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; \
            echo -e "${BLUE}${BOLD}  $*${RESET}"; \
            echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"; }

# Append a line to a file only if it's not already present
append_if_missing() {
  local line="$1" file="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
section "macOS Terminal Bootstrap"
info "Running on: $(sw_vers -productName) $(sw_vers -productVersion)"
info "Architecture: $(uname -m)"
echo ""

# Must NOT be run as root
[[ "$EUID" -eq 0 ]] && error "Do not run this script as root / sudo."

# Ensure macOS
[[ "$(uname)" == "Darwin" ]] || error "This script is macOS only."

# Xcode Command Line Tools (git, curl, make, etc.)
section "1 · Xcode Command Line Tools"
if xcode-select -p &>/dev/null; then
  success "Xcode CLT already installed — skipping."
else
  info "Installing Xcode Command Line Tools..."
  xcode-select --install 2>/dev/null || true
  info "A dialog has appeared. Click 'Install', wait for it to finish, then re-run this script."
  exit 0
fi

# ── Homebrew ──────────────────────────────────────────────────────────────────
section "2 · Homebrew"
if command -v brew &>/dev/null; then
  success "Homebrew already installed — updating..."
  brew update --quiet
else
  info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add Homebrew to PATH for the rest of this script
  if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
  else
    BREW_PREFIX="/usr/local"
  fi
  eval "$("$BREW_PREFIX/bin/brew" shellenv)"
  success "Homebrew installed."
fi

# Silence the hints
export HOMEBREW_NO_ENV_HINTS=1

# ── Zsh ───────────────────────────────────────────────────────────────────────
section "3 · Zsh"
BREW_ZSH="$(brew --prefix)/bin/zsh"

if brew list zsh &>/dev/null; then
  success "Homebrew Zsh already installed."
else
  info "Installing Zsh via Homebrew..."
  brew install zsh
  success "Zsh installed."
fi

# Add brew's zsh to /etc/shells if not already there
if ! grep -q "$BREW_ZSH" /etc/shells; then
  info "Adding $BREW_ZSH to /etc/shells (requires sudo)..."
  echo "$BREW_ZSH" | sudo tee -a /etc/shells > /dev/null
  success "Added to /etc/shells."
fi

# Set as default shell
if [[ "$SHELL" != "$BREW_ZSH" ]]; then
  info "Changing default shell to $BREW_ZSH (requires sudo)..."
  sudo chsh -s "$BREW_ZSH" "$USER"
  success "Default shell changed to $BREW_ZSH."
else
  success "Default shell is already $BREW_ZSH."
fi

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
section "4 · Oh My Zsh"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  success "Oh My Zsh already installed — skipping."
else
  info "Installing Oh My Zsh..."
  # RUNZSH=no → don't launch zsh after install; CHSH=no → we already did it above
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ── Oh My Zsh community plugins ───────────────────────────────────────────────
section "5 · Zsh Plugins (autosuggestions + syntax-highlighting)"

AUTOSUGGEST_DIR="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
if [[ -d "$AUTOSUGGEST_DIR" ]]; then
  success "zsh-autosuggestions already installed."
else
  info "Cloning zsh-autosuggestions..."
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUGGEST_DIR"
  success "zsh-autosuggestions installed."
fi

SYNTAX_DIR="$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
if [[ -d "$SYNTAX_DIR" ]]; then
  success "zsh-syntax-highlighting already installed."
else
  info "Cloning zsh-syntax-highlighting..."
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$SYNTAX_DIR"
  success "zsh-syntax-highlighting installed."
fi

# ── Powerlevel10k ─────────────────────────────────────────────────────────────
section "6 · Powerlevel10k"
P10K_DIR="$ZSH_CUSTOM/themes/powerlevel10k"
if [[ -d "$P10K_DIR" ]]; then
  success "Powerlevel10k already installed."
else
  info "Cloning Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  success "Powerlevel10k installed."
fi

# ── Nerd Fonts ────────────────────────────────────────────────────────────────
section "7 · Nerd Fonts (MesloLGS — recommended by p10k)"
# MesloLGS NF is the font officially recommended by Powerlevel10k
brew tap homebrew/cask-fonts 2>/dev/null || true

declare -a FONTS=(
  "font-meslo-lg-nerd-font"           # p10k recommended
  "font-jetbrains-mono-nerd-font"     # beautiful for coding
  "font-fira-code-nerd-font"          # ligatures
)

for font in "${FONTS[@]}"; do
  if brew list --cask "$font" &>/dev/null; then
    success "$font already installed."
  else
    info "Installing $font..."
    brew install --cask "$font"
    success "$font installed."
  fi
done

# ── Starship ──────────────────────────────────────────────────────────────────
section "8 · Starship"
if command -v starship &>/dev/null; then
  success "Starship already installed — skipping."
else
  info "Installing Starship..."
  brew install starship
  success "Starship installed."
fi

# Create a default starship config if none exists
STARSHIP_CONFIG="$HOME/.config/starship.toml"
mkdir -p "$HOME/.config"
if [[ ! -f "$STARSHIP_CONFIG" ]]; then
  info "Writing default Starship config..."
  cat > "$STARSHIP_CONFIG" << 'TOML'
# Starship config — https://starship.rs/config/
"$schema" = 'https://starship.rs/config-schema.json'

format = """
[](color_orange)\
$os\
$username\
[](bg:color_yellow fg:color_orange)\
$directory\
[](fg:color_yellow bg:color_aqua)\
$git_branch\
$git_status\
[](fg:color_aqua bg:color_blue)\
$nodejs\
$rust\
$golang\
$python\
[](fg:color_blue bg:color_bg3)\
$docker_context\
[](fg:color_bg3 bg:color_bg1)\
$time\
[ ](fg:color_bg1)\
$line_break$character"""

palette = 'gruvbox_dark'

[palettes.gruvbox_dark]
color_fg0     = '#fbf1c7'
color_bg1     = '#3c3836'
color_bg3     = '#665c54'
color_blue    = '#458588'
color_aqua    = '#689d6a'
color_green   = '#98971a'
color_orange  = '#d65d0e'
color_purple  = '#b16286'
color_red     = '#cc241d'
color_yellow  = '#d79921'

[os]
disabled = false
style = "bg:color_orange fg:color_fg0"

[os.symbols]
Macos = "󰀵 "

[username]
show_always = true
style_user  = "bg:color_orange fg:color_fg0"
style_root  = "bg:color_orange fg:color_fg0"
format      = '[ $user ]($style)'

[directory]
style            = "fg:color_fg0 bg:color_yellow"
format           = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = ".../"

[git_branch]
symbol = ""
style  = "bg:color_aqua"
format = '[[ $symbol $branch ](fg:color_fg0 bg:color_aqua)]($style)'

[git_status]
style  = "bg:color_aqua"
format = '[[($all_status$ahead_behind )](fg:color_fg0 bg:color_aqua)]($style)'

[nodejs]
symbol = ""
style  = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[python]
symbol = ""
style  = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[rust]
symbol = ""
style  = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[golang]
symbol = ""
style  = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[docker_context]
symbol = ""
style  = "bg:color_bg3"
format = '[[ $symbol( $context) ](fg:#83a598 bg:color_bg3)]($style)'

[time]
disabled    = false
time_format = "%R"
style       = "bg:color_bg1"
format      = '[[  $time ](fg:color_fg0 bg:color_bg1)]($style)'
TOML
  success "Starship config written to $STARSHIP_CONFIG"
fi

# ── Atuin ─────────────────────────────────────────────────────────────────────
section "9 · Atuin"
if command -v atuin &>/dev/null; then
  success "Atuin already installed — skipping."
else
  info "Installing Atuin..."
  brew install atuin
  success "Atuin installed."
fi

# ── fzf ───────────────────────────────────────────────────────────────────────
section "10 · fzf"
if command -v fzf &>/dev/null; then
  success "fzf already installed — skipping key-bindings install."
else
  info "Installing fzf..."
  brew install fzf
  # Install shell integrations (key bindings + fuzzy completion)
  "$(brew --prefix)/opt/fzf/install" --all --no-bash --no-fish
  success "fzf installed with zsh key bindings."
fi

# ── .zshrc ────────────────────────────────────────────────────────────────────
section "11 · Configuring ~/.zshrc"

ZSHRC="$HOME/.zshrc"

# Back it up if it already existed
if [[ -f "$ZSHRC" ]]; then
  BACKUP="$ZSHRC.bak.$(date +%Y%m%d_%H%M%S)"
  cp "$ZSHRC" "$BACKUP"
  warn "Existing .zshrc backed up → $BACKUP"
fi

# ── Write a clean, well-structured .zshrc ─────────────────────────────────────
cat > "$ZSHRC" << 'ZSHRC_CONTENT'
# ==============================================================================
#  ~/.zshrc — macOS Terminal Config
#  Generated by setup_terminal.sh
# ==============================================================================

# ── Powerlevel10k instant prompt (keep at the very top) ──────────────────────
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Update silently
zstyle ':omz:update' mode silent

plugins=(
  git                       # git aliases + completion
  sudo                      # press ESC twice to prefix last command with sudo
  z                         # jump to frecent directories (built-in omz)
  copypath                  # copy current path to clipboard
  web-search                # google foo, ddg foo from terminal
  macos                     # macOS specific utils (ofd, cdf, etc.)
  zsh-autosuggestions       # ghost-text suggestions as you type
  zsh-syntax-highlighting   # red/green command colorization in real-time
)

source "$ZSH/oh-my-zsh.sh"

# ── Homebrew ──────────────────────────────────────────────────────────────────
if [[ "$(uname -m)" == "arm64" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv)"
fi
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ANALYTICS=1

# ── Starship prompt ───────────────────────────────────────────────────────────
# NOTE: Comment out or remove if you prefer Powerlevel10k exclusively.
# They can't both be active — pick ONE. Starship is enabled here by default.
# eval "$(starship init zsh)"

# ── Atuin — shell history ─────────────────────────────────────────────────────
eval "$(atuin init zsh)"

# ── fzf — fuzzy finder ────────────────────────────────────────────────────────
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS="
  --height 50%
  --layout=reverse
  --border=rounded
  --prompt='❯ '
  --color=fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8
  --color=fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8
  --color=info:#cba6f7,prompt:#89dceb,pointer:#f5c2e7
  --color=marker:#a6e3a1,spinner:#f5c2e7,header:#f38ba8
"
# Use fd for fzf if available (much faster than find)
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# ── Editor ────────────────────────────────────────────────────────────────────
export EDITOR="nano"          # change to nvim, vim, code --wait, etc.
export VISUAL="$EDITOR"

# ── History ───────────────────────────────────────────────────────────────────
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_DUPS         # don't record duplicates back-to-back
setopt HIST_IGNORE_SPACE        # ignore commands starting with a space
setopt SHARE_HISTORY            # share history across sessions
setopt EXTENDED_HISTORY         # record timestamp of each command

# ── Aliases — navigation ──────────────────────────────────────────────────────
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ~="cd ~"

# ── Aliases — listing (requires eza) ─────────────────────────────────────────
if command -v eza &>/dev/null; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza -lah --icons --git --group-directories-first"
  alias lt="eza --tree --icons --level=2"
  alias ltt="eza --tree --icons --level=3"
else
  alias ll="ls -lah"
fi

# ── Aliases — file viewing (requires bat) ────────────────────────────────────
if command -v bat &>/dev/null; then
  alias cat="bat"
  alias -g -- -h='-h 2>&1 | bat --language=help --style=plain'
fi

# ── Aliases — git shortcuts ───────────────────────────────────────────────────
alias g="git"
alias gs="git status -sb"
alias ga="git add"
alias gaa="git add -A"
alias gc="git commit -m"
alias gca="git commit --amend --no-edit"
alias gp="git push"
alias gpf="git push --force-with-lease"
alias gl="git log --oneline --graph --decorate --all"
alias gd="git diff"
alias gco="git checkout"
alias gcb="git checkout -b"

# ── Aliases — utilities ───────────────────────────────────────────────────────
alias reload="source ~/.zshrc && echo '✔ .zshrc reloaded'"
alias zshrc="$EDITOR ~/.zshrc"
alias ip="curl -s https://ipinfo.io/ip && echo"
alias flush="sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && echo '✔ DNS flushed'"
alias cleanup="find . -name '.DS_Store' -delete && echo '✔ .DS_Store files removed'"
alias brewup="brew update && brew upgrade && brew autoremove && brew cleanup && echo '✔ Homebrew updated'"

# ── Functions ─────────────────────────────────────────────────────────────────

# mkcd — make a directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# fcd — fzf-powered interactive directory jump
fcd() {
  local dir
  dir=$(find ${1:-.} -type d 2>/dev/null | fzf +m) && cd "$dir"
}

# fkill — interactively kill a process
fkill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf -m --header="Select process(es) to kill" | awk '{print $2}')
  [[ -n "$pid" ]] && echo "$pid" | xargs kill -${1:-9}
}

# extract — universal archive extractor
extract() {
  if [[ -f "$1" ]]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz)  tar xzf "$1" ;;
      *.tar.xz)  tar xJf "$1" ;;
      *.tar)     tar xf  "$1" ;;
      *.bz2)     bunzip2 "$1" ;;
      *.gz)      gunzip  "$1" ;;
      *.zip)     unzip   "$1" ;;
      *.7z)      7z x    "$1" ;;
      *)         echo "Cannot extract: $1" ;;
    esac
  else
    echo "'$1' is not a valid file."
  fi
}

# ── Powerlevel10k config ──────────────────────────────────────────────────────
# Run `p10k configure` at any time to re-launch the wizard.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
ZSHRC_CONTENT

success ".zshrc written."

# ── Set Terminal Font ─────────────────────────────────────────────────────────
section "12 · Setting Terminal Font to MesloLGS Nerd Font Mono"

# PostScript name of the installed font
FONT_PS_NAME="MesloLGSNerdFontMono-Regular"
FONT_DISPLAY="MesloLGS Nerd Font Mono"
FONT_SIZE=13
FONT_SET=0

# ── Helper: set font in Terminal.app ─────────────────────────────────────────
set_font_terminal_app() {
  info "Configuring Terminal.app font..."

  # Get all profile names and set the font on each one
  local profiles
  profiles=$(osascript -e 'tell application "Terminal" to return name of every settings set' 2>/dev/null) || true

  if [[ -z "$profiles" ]]; then
    warn "Terminal.app: could not read profiles — skipping."
    return 1
  fi

  osascript 2>/dev/null <<APPLESCRIPT
tell application "Terminal"
  repeat with s in settings sets
    set font name of s to "$FONT_PS_NAME"
    set font size of s to $FONT_SIZE
  end repeat
end tell
APPLESCRIPT

  success "Terminal.app → font set to $FONT_DISPLAY $FONT_SIZE pt on all profiles."
  return 0
}

# ── Helper: set font in iTerm2 ────────────────────────────────────────────────
set_font_iterm2() {
  info "Configuring iTerm2 font..."
  local plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"

  if [[ ! -f "$plist" ]]; then
    warn "iTerm2 plist not found — has iTerm2 been launched at least once?"
    return 1
  fi

  # Kill iTerm2 if running so plist writes aren't overwritten on quit
  if pgrep -x "iTerm2" &>/dev/null; then
    warn "iTerm2 is running — font will apply after restart."
  fi

  # Count profiles in 'New Bookmarks'
  local count
  count=$(/usr/libexec/PlistBuddy -c "Print :'New Bookmarks'" "$plist" 2>/dev/null \
          | grep -c "^    Dict$") || count=0

  if [[ "$count" -eq 0 ]]; then
    warn "iTerm2: no profiles found in plist — skipping."
    return 1
  fi

  for (( i=0; i<count; i++ )); do
    /usr/libexec/PlistBuddy \
      -c "Set :'New Bookmarks':${i}:'Normal Font' '${FONT_PS_NAME} ${FONT_SIZE}'" \
      "$plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy \
      -c "Add :'New Bookmarks':${i}:'Normal Font' string '${FONT_PS_NAME} ${FONT_SIZE}'" \
      "$plist" 2>/dev/null || true

    # Non-ASCII font (used for non-latin characters)
    /usr/libexec/PlistBuddy \
      -c "Set :'New Bookmarks':${i}:'Non Ascii Font' '${FONT_PS_NAME} ${FONT_SIZE}'" \
      "$plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy \
      -c "Add :'New Bookmarks':${i}:'Non Ascii Font' string '${FONT_PS_NAME} ${FONT_SIZE}'" \
      "$plist" 2>/dev/null || true
  done

  # Flush defaults cache
  defaults read com.googlecode.iterm2 &>/dev/null || true

  success "iTerm2 → font set to $FONT_DISPLAY $FONT_SIZE pt across $count profile(s)."
  return 0
}

# ── Helper: set font in Ghostty ───────────────────────────────────────────────
set_font_ghostty() {
  info "Configuring Ghostty font..."
  local config="$HOME/.config/ghostty/config"
  mkdir -p "$(dirname "$config")"
  touch "$config"

  # Replace existing font-family line or append it
  if grep -q "^font-family" "$config" 2>/dev/null; then
    sed -i '' "s|^font-family.*|font-family = $FONT_DISPLAY|" "$config"
  else
    echo "font-family = $FONT_DISPLAY" >> "$config"
  fi

  # Replace existing font-size line or append it
  if grep -q "^font-size" "$config" 2>/dev/null; then
    sed -i '' "s|^font-size.*|font-size = $FONT_SIZE|" "$config"
  else
    echo "font-size = $FONT_SIZE" >> "$config"
  fi

  success "Ghostty → font set to $FONT_DISPLAY $FONT_SIZE pt in $config"
  return 0
}

# ── Helper: set font in Warp ──────────────────────────────────────────────────
set_font_warp() {
  # Warp manages fonts through its own Electron settings store — not editable
  # via plist or config file without risking corruption.
  warn "Warp detected. Warp's font must be set inside the app:"
  warn "  Warp → Settings ( Cmd+, ) → Appearance → Font → $FONT_DISPLAY"
  return 0
}

# ── Detect and configure every installed terminal ────────────────────────────

# Terminal.app — always present on macOS
if [[ -d "/System/Applications/Utilities/Terminal.app" ]] || \
   [[ -d "/Applications/Utilities/Terminal.app" ]]; then
  set_font_terminal_app && FONT_SET=1 || true
fi

# iTerm2
if [[ -d "/Applications/iTerm.app" ]]; then
  set_font_iterm2 && FONT_SET=1 || true
fi

# Ghostty
if command -v ghostty &>/dev/null || [[ -d "/Applications/Ghostty.app" ]]; then
  set_font_ghostty && FONT_SET=1 || true
fi

# Warp
if [[ -d "/Applications/Warp.app" ]]; then
  set_font_warp
fi

if [[ "$FONT_SET" -eq 1 ]]; then
  success "Font configuration complete — restart your terminal to see the change."
else
  warn "No supported terminals detected to configure automatically."
  warn "Manually set the font to: $FONT_DISPLAY $FONT_SIZE pt"
fi

# ── Final summary ─────────────────────────────────────────────────────────────
section "✔ Installation Complete"

echo -e "${BOLD}What was installed:${RESET}"
echo -e "  ${GREEN}✔${RESET}  Homebrew         $(brew --version | head -1)"
echo -e "  ${GREEN}✔${RESET}  Zsh              $(zsh --version)"
echo -e "  ${GREEN}✔${RESET}  Oh My Zsh        $HOME/.oh-my-zsh"
echo -e "  ${GREEN}✔${RESET}  Powerlevel10k    $P10K_DIR"
echo -e "  ${GREEN}✔${RESET}  Nerd Fonts       MesloLGS, JetBrainsMono, FiraCode"
echo -e "  ${GREEN}✔${RESET}  Starship         $(starship --version | head -1)"
echo -e "  ${GREEN}✔${RESET}  Atuin            $(atuin --version)"
echo -e "  ${GREEN}✔${RESET}  fzf              $(fzf --version)"
echo -e "  ${GREEN}✔${RESET}  zsh-autosuggestions"
echo -e "  ${GREEN}✔${RESET}  zsh-syntax-highlighting"

echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo -e "  ${CYAN}1.${RESET} Fully quit and reopen your terminal, then run:"
echo -e "       ${BOLD}p10k configure${RESET}  — interactive Powerlevel10k setup wizard"
echo ""
echo -e "  ${CYAN}2.${RESET} Starship vs Powerlevel10k:"
echo -e "       Both are installed. ${BOLD}Powerlevel10k is active by default.${RESET}"
echo -e "       To switch to Starship, open ~/.zshrc and:"
echo -e "         • Comment out  →  ZSH_THEME=\"powerlevel10k/powerlevel10k\""
echo -e "         • Set          →  ZSH_THEME=\"\""
echo -e "         • Uncomment    →  eval \"\$(starship init zsh)\""
echo ""
echo -e "  ${CYAN}4.${RESET} Optional recommended extras:"
echo -e "       ${BOLD}brew install eza bat lazygit fd ripgrep${RESET}"
echo ""
echo -e "${GREEN}${BOLD}Happy hacking! 🚀${RESET}\n"
