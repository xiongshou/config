#!/bin/bash
# Kaku Shell Environment for Linux
# 一键安装脚本，将 Kaku 终端的 shell 环境（插件、工具、配置）迁移到 Linux
# 使用方法: bash kaku-linux-setup.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "  ${GREEN}✓${NC} ${BOLD}$1${NC}  $2"; }
warn()  { echo -e "  ${YELLOW}!${NC} ${BOLD}$1${NC}  $2"; }
err()   { echo -e "  ${RED}✗${NC} ${BOLD}$1${NC}  $2"; }

KAKU_ZSH_DIR="$HOME/.config/kaku/zsh"
KAKU_PLUGINS_DIR="$KAKU_ZSH_DIR/plugins"
STARSHIP_CONFIG="$HOME/.config/starship.toml"
YAZI_CONFIG_DIR="$HOME/.config/yazi"
TMUX_CONF="$HOME/.tmux.conf"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

echo -e "${BOLD}Kaku Shell Environment for Linux${NC}"
echo ""

# ============================================================
# 1. Install Homebrew (Linuxbrew) if not present
# ============================================================

install_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        info "Homebrew" "already installed"
        return 0
    fi

    echo -e "${BOLD}Installing Homebrew (Linuxbrew)...${NC}"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to PATH for this session
    if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -f "$HOME/.linuxbrew/bin/brew" ]]; then
        eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
    fi

    if command -v brew >/dev/null 2>&1; then
        info "Homebrew" "installed successfully"
    else
        err "Homebrew" "installation failed"
        exit 1
    fi
}

install_homebrew

# ============================================================
# 2. Install CLI tools via Homebrew
# ============================================================

echo ""
echo -e "${BOLD}Installing CLI tools...${NC}"

TOOLS=(tmux starship git-delta lazygit yazi zoxide zsh worktrunk)
MISSING_TOOLS=()

for tool in "${TOOLS[@]}"; do
    bin_name="$tool"
    case "$tool" in
        git-delta) bin_name="delta" ;;
    esac
    if ! command -v "$bin_name" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo "  Installing: ${MISSING_TOOLS[*]}"
    brew install "${MISSING_TOOLS[@]}"
    info "Tools" "installed: ${MISSING_TOOLS[*]}"
else
    info "Tools" "all already installed"
fi

# Configure worktrunk shell integration
if command -v wt >/dev/null 2>&1; then
    if ! grep -q "worktrunk\|wt shell" "${ZDOTDIR:-$HOME}/.zshrc" 2>/dev/null; then
        echo "y" | wt config shell install
        info "worktrunk" "shell integration configured"
    else
        info "worktrunk" "shell integration already present"
    fi
fi

# ============================================================
# 3. Download Zsh plugins
# ============================================================

echo ""
echo -e "${BOLD}Installing Zsh plugins...${NC}"

mkdir -p "$KAKU_PLUGINS_DIR"

download_plugin() {
    local name="$1"
    local repo="$2"
    local ref="$3"
    local dest="$KAKU_PLUGINS_DIR/$name"
    local marker_file="$dest/.kaku-vendor-ref"

    if [[ -f "$marker_file" ]] && [[ "$(cat "$marker_file")" == "$ref" ]]; then
        info "Plugin" "$name already up to date"
        return
    fi

    local archive_url="https://codeload.github.com/$repo/tar.gz/$ref"
    local temp_dir
    temp_dir="$(mktemp -d)"

    curl --fail --location --silent --show-error --retry 3 --retry-delay 2 "$archive_url" --output "$temp_dir/$name.tar.gz"
    mkdir -p "$temp_dir/extract"
    tar -xzf "$temp_dir/$name.tar.gz" -C "$temp_dir/extract"
    local source_dir
    source_dir="$(find "$temp_dir/extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

    rm -rf "$dest"
    mv "$source_dir" "$dest"
    printf '%s\n' "$ref" > "$marker_file"
    rm -rf "$temp_dir"
    info "Plugin" "$name installed"
}

download_plugin "zsh-autosuggestions" "zsh-users/zsh-autosuggestions" "85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5"
download_plugin "fast-syntax-highlighting" "zdharma-continuum/fast-syntax-highlighting" "3d574ccf48804b10dca52625df13da5edae7f553"
download_plugin "zsh-completions" "zsh-users/zsh-completions" "84615f3d0b0e943d5b1de862c9552e572c8e70bb"
download_plugin "zsh-z" "agkozak/zsh-z" "cf9225feebfae55e557e103e95ce20eca5eff270"

# ============================================================
# 4. Generate kaku.zsh init file
# ============================================================

echo ""
echo -e "${BOLD}Generating Zsh configuration...${NC}"

mkdir -p "$KAKU_ZSH_DIR"

cat > "$KAKU_ZSH_DIR/kaku.zsh" << 'KAKUZSH'
# Kaku Zsh Integration for Linux
# Ported from Kaku terminal's shell environment

export KAKU_ZSH_DIR="$HOME/.config/kaku/zsh"

# Initialize Starship (Cross-shell prompt)
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# Enable color output for ls
export CLICOLOR=1
export LSCOLORS="gxfxcxdxbxegedabagacad"

# If eza/exa is available, use it for ls aliases
if command -v eza &> /dev/null; then
    alias ls='eza'
    alias ll='eza -lhF'
    alias la='eza -lAhF'
    alias l='eza -CF'
fi

# Smart History Configuration
HISTSIZE="${HISTSIZE:-50000}"
SAVEHIST="${SAVEHIST:-50000}"
if [[ -z "${HISTFILE:-}" ]]; then
    HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
fi
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY

# Default Zsh options
setopt interactive_comments
bindkey -e

# Prefix history search on Up/Down
if [[ "$(bindkey -M emacs '^[[A' 2>/dev/null)" == *"up-line-or-history"* ]]; then
    autoload -U up-line-or-beginning-search down-line-or-beginning-search
    zle -N up-line-or-beginning-search
    zle -N down-line-or-beginning-search
    zmodload zsh/terminfo 2>/dev/null || true
    for _kaku_keymap in emacs viins; do
        [[ -n "${terminfo[kcuu1]:-}" ]] && bindkey -M "$_kaku_keymap" "${terminfo[kcuu1]}" up-line-or-beginning-search
        [[ -n "${terminfo[kcud1]:-}" ]] && bindkey -M "$_kaku_keymap" "${terminfo[kcud1]}" down-line-or-beginning-search
        bindkey -M "$_kaku_keymap" '^[[A' up-line-or-beginning-search
        bindkey -M "$_kaku_keymap" '^[[B' down-line-or-beginning-search
    done
    unset _kaku_keymap
fi

# Directory Navigation Options
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus

# Common Aliases
alias ll='ls -lhF'
alias la='ls -lAhF'
alias l='ls -CF'

# Directory Navigation
alias ...='../..'
alias ....='../../..'
alias .....='../../../..'
alias ......='../../../../..'
alias md='mkdir -p'
alias rd=rmdir

# Grep Colors
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'

# Common Git Aliases
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gbd='git branch -d'
alias gc='git commit -v'
alias gcmsg='git commit -m'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch'
alias gl='git pull'
alias gp='git push'
alias gst='git status'
alias gss='git status -s'
alias glo='git log --oneline --decorate'
alias glg='git log --stat'
alias glgp='git log --stat -p'

# Yazi launcher - cd into the directory yazi is in when you exit
'y'() {
    emulate -L zsh
    setopt local_options no_sh_word_split

    local yazi_cmd
    yazi_cmd="$(command -v yazi 2>/dev/null || true)"

    if [[ -z "$yazi_cmd" ]]; then
        echo "yazi not found. Install it with: brew install yazi"
        return 127
    fi

    local tmp cwd
    tmp="$(mktemp -t 'yazi-cwd.XXXXXX')"
    "$yazi_cmd" "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# Lazygit shortcut
alias lg='lazygit'

# Load Plugins

# zsh-completions
if [[ -d "$KAKU_ZSH_DIR/plugins/zsh-completions/src" ]] && (( ${fpath[(Ie)$KAKU_ZSH_DIR/plugins/zsh-completions/src]} == 0 )); then
    fpath=("$KAKU_ZSH_DIR/plugins/zsh-completions/src" $fpath)
fi

# compinit (optimized)
autoload -Uz compinit
if ! (( ${+functions[_main_complete]} )) || ! (( ${+_comps} )); then
    if [[ -n "${ZDOTDIR:-$HOME}/.zcompdump"(#qN.mh+24) ]]; then
        compinit
    else
        compinit -C
    fi
fi

# zsh-z (smart directory jumping)
if [[ -f "$KAKU_ZSH_DIR/plugins/zsh-z/zsh-z.plugin.zsh" ]] && ! (( ${+functions[zshz]} )); then
    : "${ZSHZ_CASE:=smart}"
    export ZSHZ_CASE
    source "$KAKU_ZSH_DIR/plugins/zsh-z/zsh-z.plugin.zsh"
fi

# zsh-autosuggestions
if ! (( ${+functions[_zsh_autosuggest_start]} )); then
    if [[ -f "$KAKU_ZSH_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
        source "$KAKU_ZSH_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
fi

# fast-syntax-highlighting (deferred to first prompt for faster startup)
if ! (( ${+functions[_zsh_highlight]} )) && [[ -f "$KAKU_ZSH_DIR/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
    fast_syntax_highlighting_defer() {
        source "$KAKU_ZSH_DIR/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
        typeset -gA FAST_HIGHLIGHT_STYLES
        FAST_HIGHLIGHT_STYLES[comment]='fg=244'
        precmd_functions=("${precmd_functions[@]:#fast_syntax_highlighting_defer}")
    }
    precmd_functions+=(fast_syntax_highlighting_defer)
fi

# Initialize zoxide if available (alternative to zsh-z for broader compat)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi
KAKUZSH

info "Config" "generated kaku.zsh"

# ============================================================
# 5. Starship configuration
# ============================================================

if [[ ! -f "$STARSHIP_CONFIG" ]]; then
    mkdir -p "$(dirname "$STARSHIP_CONFIG")"
    cat > "$STARSHIP_CONFIG" << 'STARSHIPTOML'
# Kaku Starship Configuration

add_newline = false
command_timeout = 10000
format = "$directory$git_branch$python$conda$package$character"

[directory]
truncate_to_repo = true
truncation_length = 2
style = "bold blue"
format = "[$path]($style)[$read_only]($read_only_style)"

[character]
success_symbol = " "
error_symbol = " "
format = "$symbol"

[git_branch]
symbol = " "
style = "bold purple"
format = " [$symbol$branch]($style)"
truncation_length = 24
truncation_symbol = "…"

[python]
format = ' [\($virtualenv\)]($style)'
style = 'bold green'
python_binary = ['python3', 'python']
detect_extensions = []
detect_files = []
detect_folders = []
detect_env_vars = ['VIRTUAL_ENV']

[conda]
format = ' [\($environment\)]($style)'
style = 'bold green'
ignore_base = false

[package]
format = " is [$symbol$version]($style)"

[aws]
disabled = true
STARSHIPTOML
    info "Config" "generated starship.toml"
else
    info "Config" "starship.toml already exists, skipping"
fi

# ============================================================
# 6. Git Delta configuration
# ============================================================

echo ""
echo -e "${BOLD}Configuring git delta...${NC}"

if command -v delta >/dev/null 2>&1; then
    git config --global core.pager "delta"
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate "true"
    git config --global delta.pager "less --mouse --wheel-lines=3 -R -F -X"
    git config --global delta.line-numbers "true"
    git config --global delta.side-by-side "true"
    git config --global delta.line-fill-method "spaces"
    git config --global delta.syntax-theme "Coldark-Dark"
    git config --global delta.file-style "omit"
    git config --global delta.file-decoration-style "omit"
    git config --global delta.hunk-header-style "file line-number syntax"
    info "Git" "delta configured as global pager"
else
    warn "Git" "delta not found, skipping git config"
fi

# ============================================================
# 7. Tmux configuration
# ============================================================

echo ""
echo -e "${BOLD}Configuring tmux...${NC}"

if [[ -f "$TMUX_CONF" ]]; then
    cp "$TMUX_CONF" "${TMUX_CONF}.kaku-backup-$(date +%s)"
    info "Tmux" "backed up existing .tmux.conf"
fi

cat > "$TMUX_CONF" << 'TMUXCONF'
# Kaku Tmux Configuration for Linux
# Ported from Kaku terminal + practical enhancements

# ---- General Settings ----
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -g history-limit 50000
set -g display-time 4000
set -g status-interval 5
set -g focus-events on
set -sg escape-time 0

# ---- Prefix Key ----
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# ---- Mouse Support (from Kaku) ----
set -g mouse on
bind-key -n S-WheelUpPane if-shell -F '#{pane_in_mode}' 'send-keys -X -N 5 scroll-up' 'copy-mode -e -u'
bind-key -n S-WheelDownPane if-shell -F '#{pane_in_mode}' 'send-keys -X -N 5 scroll-down' ''

# ---- Window/Pane Numbering ----
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# ---- Split Panes ----
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"
unbind '"'
unbind %

# ---- Pane Navigation (vim-style) ----
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# ---- Pane Resizing ----
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# ---- Copy Mode (vi) ----
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
bind -T copy-mode-vi r send-keys -X rectangle-toggle

# ---- Reload Config ----
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"

# ---- Status Bar ----
set -g status-position bottom
set -g status-style "bg=#1e1e2e,fg=#cdd6f4"
set -g status-left-length 30
set -g status-right-length 50
set -g status-left "#[fg=#89b4fa,bold] #S "
set -g status-right "#[fg=#a6adc8] %Y-%m-%d %H:%M "

# Window status
setw -g window-status-format "#[fg=#6c7086] #I:#W "
setw -g window-status-current-format "#[fg=#89b4fa,bold] #I:#W "

# Pane borders
set -g pane-border-style "fg=#313244"
set -g pane-active-border-style "fg=#89b4fa"

# Message style
set -g message-style "bg=#1e1e2e,fg=#cdd6f4"

# ---- Auto Rename ----
setw -g automatic-rename on
set -g set-titles on
set -g set-titles-string "#S - #W"
TMUXCONF

info "Tmux" "configuration generated"

# ============================================================
# 8. Yazi configuration
# ============================================================

echo ""
echo -e "${BOLD}Configuring Yazi...${NC}"

mkdir -p "$YAZI_CONFIG_DIR"

if [[ ! -f "$YAZI_CONFIG_DIR/yazi.toml" ]]; then
    cat > "$YAZI_CONFIG_DIR/yazi.toml" << 'YAZITOML'
[mgr]
ratio = [3, 3, 10]

[preview]
max_width = 2000
max_height = 2400
wrap = "yes"

[opener]
edit = [
  { run = "${EDITOR:-vim} %s", desc = "edit", for = "unix", block = true },
]
YAZITOML
    info "Yazi" "generated yazi.toml"
else
    info "Yazi" "yazi.toml already exists, skipping"
fi

if [[ ! -f "$YAZI_CONFIG_DIR/keymap.toml" ]] || grep -q '\$schema' "$YAZI_CONFIG_DIR/keymap.toml" 2>/dev/null; then
    cat > "$YAZI_CONFIG_DIR/keymap.toml" << 'YAZIKEYMAP'
[mgr]
prepend_keymap = [
  { on = "e", run = "open", desc = "Edit or open selected files" },
  { on = "o", run = "open", desc = "Edit or open selected files" },
  { on = "<Enter>", run = "enter", desc = "Enter the child directory" },
]
YAZIKEYMAP
    info "Yazi" "generated keymap.toml"
else
    info "Yazi" "keymap.toml already exists, skipping"
fi

# ============================================================
# 9. Update .zshrc
# ============================================================

echo ""
echo -e "${BOLD}Updating .zshrc...${NC}"

KAKU_SOURCE_LINE='[[ -f "$HOME/.config/kaku/zsh/kaku.zsh" ]] && source "$HOME/.config/kaku/zsh/kaku.zsh" # Kaku Shell Integration'

if [[ -f "$ZSHRC" ]] && grep -Fq "kaku.zsh" "$ZSHRC"; then
    info "Zshrc" "Kaku integration already present"
else
    # Ensure .zshrc exists
    touch "$ZSHRC"
    echo "" >> "$ZSHRC"
    echo "$KAKU_SOURCE_LINE" >> "$ZSHRC"
    info "Zshrc" "added Kaku source line to .zshrc"
fi

# ============================================================
# 10. Ensure brew is in shell PATH permanently
# ============================================================

BREW_PATH_LINE='export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH" # Linuxbrew'

if [[ -f "$ZSHRC" ]] && grep -Fq "linuxbrew" "$ZSHRC"; then
    : # already there
elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
    echo "" >> "$ZSHRC"
    echo "$BREW_PATH_LINE" >> "$ZSHRC"
    info "Zshrc" "added Homebrew PATH to .zshrc"
fi

# ============================================================
# 11. Install npm global tools (openspec, claude code)
# ============================================================

echo ""
echo -e "${BOLD}Installing npm global tools...${NC}"

if ! command -v node >/dev/null 2>&1; then
    warn "npm tools" "node not found, skipping openspec and claude code"
else
    if ! npm list -g @fission-ai/openspec >/dev/null 2>&1; then
        npm install -g @fission-ai/openspec@latest
        info "openspec" "installed"
    else
        info "openspec" "already installed"
    fi
fi

# ============================================================
# Done
# ============================================================

echo ""
echo -e "${GREEN}${BOLD}Setup complete!${NC}"
echo ""
echo "  Next steps:"
echo "    1. Run: exec zsh"
echo "    2. Verify: starship prompt, git diff with delta, tmux, lazygit, y (yazi)"
echo ""
echo "  Installed tools: tmux, starship, delta, lazygit, yazi, zoxide"
echo "  Zsh plugins: autosuggestions, fast-syntax-highlighting, completions, zsh-z"
echo "  Configs: ~/.config/kaku/zsh/kaku.zsh, ~/.config/starship.toml, ~/.tmux.conf, ~/.config/yazi/"
echo ""


