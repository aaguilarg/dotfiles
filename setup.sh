#!/bin/bash

set -e

OS="$(uname -s)"
DOTFILES="$HOME/dotfiles"
PREVIEW_ITEMS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helpers
add_preview()   { PREVIEW_ITEMS+=("$1"); }
check_command() { command -v "$1" &>/dev/null; }
check_file()    { [[ -f "$1" ]]; }
check_dir()     { [[ -d "$1" ]]; }
check_symlink() { [[ -L "$1" ]] && [[ "$(readlink "$1")" == "$2" ]]; }

# ─── PREVIEW ────────────────────────────────────────────────────────────────

echo ""
echo "=== Dotfiles Setup Preview ==="
echo ""
echo "Analyzing current state..."
echo ""

# 1. macOS settings
if [[ "$OS" == "Darwin" ]]; then
  echo -e "${BLUE}[macOS Settings]${NC}"

  KEYREPEAT=$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo "not set")
  INITIALREPEAT=$(defaults read NSGlobalDomain InitialKeyRepeat 2>/dev/null || echo "not set")
  PRESSHOLD=$(defaults read NSGlobalDomain ApplePressAndHoldEnabled 2>/dev/null || echo "not set")

  if [[ "$KEYREPEAT" == "1" ]] && [[ "$INITIALREPEAT" == "10" ]] && [[ "$PRESSHOLD" == "0" ]]; then
    echo -e "  ${GREEN}✓${NC} Keyboard already configured for fast Vim navigation"
  else
    echo -e "  ${YELLOW}•${NC} Will configure fast key repeat (KeyRepeat=1, InitialKeyRepeat=10)"
    echo -e "  ${YELLOW}•${NC} Will disable press-and-hold for accents"
    add_preview "macos_keyboard"
  fi
  echo ""
fi

# 2. Homebrew
if [[ "$OS" == "Darwin" ]]; then
  echo -e "${BLUE}[Homebrew]${NC}"

  if check_command brew; then
    echo -e "  ${GREEN}✓${NC} Already installed"

    if check_file "$DOTFILES/Brewfile"; then
      BREW_MISSING=$(brew bundle check --file="$DOTFILES/Brewfile" 2>&1 | grep -c "needs to be installed" || true)
      if [[ "$BREW_MISSING" -gt 0 ]]; then
        echo -e "  ${YELLOW}•${NC} Will install $BREW_MISSING package(s) from Brewfile"
        add_preview "brew_packages"
      else
        echo -e "  ${GREEN}✓${NC} All Brewfile packages already installed"
      fi
    fi
  else
    echo -e "  ${YELLOW}•${NC} Will install Homebrew"
    echo -e "  ${YELLOW}•${NC} Will install all packages from Brewfile"
    add_preview "brew_install"
    add_preview "brew_packages"
  fi
  echo ""
fi

# 3. Oh My Zsh + plugins
echo -e "${BLUE}[Oh My Zsh]${NC}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if check_dir "$HOME/.oh-my-zsh"; then
  echo -e "  ${GREEN}✓${NC} Already installed"
else
  echo -e "  ${YELLOW}•${NC} Will install Oh My Zsh"
  add_preview "ohmyzsh"
fi

if check_dir "$ZSH_CUSTOM/themes/powerlevel10k"; then
  echo -e "  ${GREEN}✓${NC} powerlevel10k theme installed"
else
  echo -e "  ${YELLOW}•${NC} Will install powerlevel10k theme"
  add_preview "p10k"
fi

if check_dir "$ZSH_CUSTOM/plugins/zsh-autosuggestions"; then
  echo -e "  ${GREEN}✓${NC} zsh-autosuggestions installed"
else
  echo -e "  ${YELLOW}•${NC} Will install zsh-autosuggestions"
  add_preview "zsh_autosuggestions"
fi

if check_dir "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"; then
  echo -e "  ${GREEN}✓${NC} zsh-syntax-highlighting installed"
else
  echo -e "  ${YELLOW}•${NC} Will install zsh-syntax-highlighting"
  add_preview "zsh_highlighting"
fi
echo ""

# 4. nodenv + Node LTS
echo -e "${BLUE}[Node.js]${NC}"

if check_command nodenv; then
  echo -e "  ${GREEN}✓${NC} nodenv installed"

  echo -e "  ${YELLOW}...${NC} Checking for latest Node LTS..."
  NODE_LTS=$(curl -s https://nodejs.org/dist/index.json 2>/dev/null \
    | grep -o '"version":"v[0-9.]*".*"lts":"[A-Za-z]' \
    | head -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/v//' || echo "")

  if [[ -n "$NODE_LTS" ]]; then
    if nodenv versions 2>/dev/null | grep -q "$NODE_LTS"; then
      echo -e "  ${GREEN}✓${NC} Node $NODE_LTS (LTS) already installed"
      CURRENT_GLOBAL=$(nodenv global 2>/dev/null || echo "")
      if [[ "$CURRENT_GLOBAL" == "$NODE_LTS" ]]; then
        echo -e "  ${GREEN}✓${NC} Node $NODE_LTS set as global"
      else
        echo -e "  ${YELLOW}•${NC} Will set Node $NODE_LTS as global (currently: $CURRENT_GLOBAL)"
        add_preview "node_global"
      fi
    else
      echo -e "  ${YELLOW}•${NC} Will install Node $NODE_LTS (LTS) and set as global"
      add_preview "node_install"
    fi
  fi
else
  echo -e "  ${YELLOW}•${NC} nodenv not installed yet — will configure after Brewfile"
  add_preview "nodenv_setup"
fi
echo ""

# 5. rbenv + Ruby
echo -e "${BLUE}[Ruby]${NC}"

if check_command rbenv; then
  echo -e "  ${GREEN}✓${NC} rbenv installed"

  RUBY_LATEST=$(rbenv install -l 2>/dev/null | grep -E "^[0-9]+\.[0-9]+\.[0-9]+$" | tail -1 || echo "")

  if [[ -n "$RUBY_LATEST" ]]; then
    if rbenv versions 2>/dev/null | grep -q "$RUBY_LATEST"; then
      echo -e "  ${GREEN}✓${NC} Ruby $RUBY_LATEST already installed"
      CURRENT_GLOBAL=$(rbenv global 2>/dev/null || echo "")
      if [[ "$CURRENT_GLOBAL" == "$RUBY_LATEST" ]]; then
        echo -e "  ${GREEN}✓${NC} Ruby $RUBY_LATEST set as global"
      else
        echo -e "  ${YELLOW}•${NC} Will set Ruby $RUBY_LATEST as global (currently: $CURRENT_GLOBAL)"
        add_preview "ruby_global"
      fi
    else
      echo -e "  ${YELLOW}•${NC} Will install Ruby $RUBY_LATEST and set as global"
      add_preview "ruby_install"
    fi
  fi
else
  echo -e "  ${YELLOW}•${NC} rbenv not installed yet — will configure after Brewfile"
  add_preview "rbenv_setup"
fi
echo ""

# 6. pyenv
echo -e "${BLUE}[Python]${NC}"

if check_command pyenv; then
  echo -e "  ${GREEN}✓${NC} pyenv installed"
else
  echo -e "  ${YELLOW}•${NC} pyenv not installed yet — will configure after Brewfile"
  add_preview "pyenv_setup"
fi
echo ""

# 7. TPM
echo -e "${BLUE}[Tmux Plugin Manager]${NC}"

if check_dir "$HOME/.tmux/plugins/tpm"; then
  echo -e "  ${GREEN}✓${NC} TPM already installed"
else
  echo -e "  ${YELLOW}•${NC} Will install TPM"
  add_preview "tpm"
fi
echo ""

# 8. Claude Code
echo -e "${BLUE}[Claude Code]${NC}"

if check_command claude || [[ -x "$HOME/.local/bin/claude" ]]; then
  echo -e "  ${GREEN}✓${NC} Already installed"
else
  echo -e "  ${YELLOW}•${NC} Will install Claude Code (Anthropic's native installer, auto-updates)"
  add_preview "claude_code"
fi
echo ""

# 9. Symlinks
echo -e "${BLUE}[Dotfile Symlinks]${NC}"

check_and_add_symlink() {
  local target="$1"
  local link="$2"

  if check_symlink "$link" "$target"; then
    echo -e "  ${GREEN}✓${NC} $link"
  else
    echo -e "  ${YELLOW}•${NC} Will link: $link -> $target"
    add_preview "symlinks"
  fi
}

check_and_add_symlink "$DOTFILES/.zshrc"                  "$HOME/.zshrc"
check_and_add_symlink "$DOTFILES/.p10k.zsh"               "$HOME/.p10k.zsh"
check_and_add_symlink "$DOTFILES/.gitconfig"              "$HOME/.gitconfig"
check_and_add_symlink "$DOTFILES/git/ignore"              "$HOME/.config/git/ignore"
check_and_add_symlink "$DOTFILES/tmux/tmux.conf"          "$HOME/.config/tmux/tmux.conf"
check_and_add_symlink "$DOTFILES/nvim"                    "$HOME/.config/nvim"
check_and_add_symlink "$DOTFILES/claude/CLAUDE.md"        "$HOME/.claude/CLAUDE.md"
check_and_add_symlink "$DOTFILES/claude/settings.json"    "$HOME/.claude/settings.json"
check_and_add_symlink "$DOTFILES/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"

for skill_dir in "$DOTFILES/claude/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  check_and_add_symlink "$DOTFILES/claude/skills/$skill_name" "$HOME/.claude/skills/$skill_name"
done

for script in "$DOTFILES/bin"/* "$DOTFILES/private/bin"/*; do
  [[ -f "$script" ]] || continue
  check_and_add_symlink "$script" "$HOME/.local/bin/$(basename "$script")"
done

if [[ -d "$DOTFILES/.git" ]]; then
  if [[ "$(git -C "$DOTFILES" config --get core.hooksPath)" == ".githooks" ]]; then
    echo -e "  ${GREEN}✓${NC} git hooks: .githooks"
  else
    echo -e "  ${YELLOW}•${NC} Will set git hooks path to .githooks"
    add_preview "symlinks"
  fi
fi
echo ""

# ─── CONFIRMATION ────────────────────────────────────────────────────────────

if [[ ${#PREVIEW_ITEMS[@]} -eq 0 ]]; then
  echo -e "${GREEN}Everything is already set up! Nothing to do.${NC}"
  echo ""
  exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Proceed with setup? [y/N] " -n 1 -r
echo ""
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Setup cancelled."
  exit 0
fi

# ─── EXECUTION ───────────────────────────────────────────────────────────────

echo "=== Running Setup ==="
echo ""

# 1. macOS keyboard
if [[ " ${PREVIEW_ITEMS[*]} " =~ " macos_keyboard " ]]; then
  echo -e "${BLUE}Configuring macOS keyboard settings...${NC}"
  defaults write NSGlobalDomain KeyRepeat -int 1
  defaults write NSGlobalDomain InitialKeyRepeat -int 10
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
  echo -e "${GREEN}✓${NC} Keyboard settings configured"
  echo ""
fi

# 2. Homebrew
if [[ " ${PREVIEW_ITEMS[*]} " =~ " brew_install " ]]; then
  echo -e "${BLUE}Installing Homebrew...${NC}"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  echo -e "${GREEN}✓${NC} Homebrew installed"
  echo ""
fi

if [[ " ${PREVIEW_ITEMS[*]} " =~ " brew_packages " ]] && [[ "$OS" == "Darwin" ]]; then
  echo -e "${BLUE}Installing packages from Brewfile...${NC}"
  brew bundle --file="$DOTFILES/Brewfile"
  echo -e "${GREEN}✓${NC} Packages installed"
  echo ""
fi

# 3. Oh My Zsh
if [[ " ${PREVIEW_ITEMS[*]} " =~ " ohmyzsh " ]]; then
  echo -e "${BLUE}Installing Oh My Zsh...${NC}"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  echo -e "${GREEN}✓${NC} Oh My Zsh installed"
  echo ""
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ " ${PREVIEW_ITEMS[*]} " =~ " p10k " ]]; then
  echo -e "${BLUE}Installing powerlevel10k...${NC}"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
  echo -e "${GREEN}✓${NC} powerlevel10k installed"
  echo ""
fi

if [[ " ${PREVIEW_ITEMS[*]} " =~ " zsh_autosuggestions " ]]; then
  echo -e "${BLUE}Installing zsh-autosuggestions...${NC}"
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  echo -e "${GREEN}✓${NC} zsh-autosuggestions installed"
  echo ""
fi

if [[ " ${PREVIEW_ITEMS[*]} " =~ " zsh_highlighting " ]]; then
  echo -e "${BLUE}Installing zsh-syntax-highlighting...${NC}"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  echo -e "${GREEN}✓${NC} zsh-syntax-highlighting installed"
  echo ""
fi

# 4. Node LTS
if [[ " ${PREVIEW_ITEMS[*]} " =~ " node_install " ]] || [[ " ${PREVIEW_ITEMS[*]} " =~ " node_global " ]] || [[ " ${PREVIEW_ITEMS[*]} " =~ " nodenv_setup " ]]; then
  echo -e "${BLUE}Installing Node.js LTS...${NC}"

  if [[ -d "$HOME/.nodenv/bin" ]]; then
    export PATH="$HOME/.nodenv/bin:$PATH"
    eval "$(nodenv init -)"
  fi

  NODE_LTS=$(curl -s https://nodejs.org/dist/index.json 2>/dev/null \
    | grep -o '"version":"v[0-9.]*".*"lts":"[A-Za-z]' \
    | head -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/v//' || echo "")

  if [[ -n "$NODE_LTS" ]]; then
    if ! nodenv versions 2>/dev/null | grep -q "$NODE_LTS"; then
      nodenv install "$NODE_LTS"
    fi
    nodenv global "$NODE_LTS"
    echo -e "${GREEN}✓${NC} Node $NODE_LTS (LTS) installed and set as global"
  else
    echo -e "${YELLOW}⚠${NC} Could not determine LTS version, skipping"
  fi
  echo ""
fi

# 5. Ruby
if [[ " ${PREVIEW_ITEMS[*]} " =~ " ruby_install " ]] || [[ " ${PREVIEW_ITEMS[*]} " =~ " ruby_global " ]] || [[ " ${PREVIEW_ITEMS[*]} " =~ " rbenv_setup " ]]; then
  echo -e "${BLUE}Installing Ruby...${NC}"

  if [[ -d "$HOME/.rbenv/bin" ]]; then
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
  fi

  RUBY_LATEST=$(rbenv install -l 2>/dev/null | grep -E "^[0-9]+\.[0-9]+\.[0-9]+$" | tail -1 || echo "")

  if [[ -n "$RUBY_LATEST" ]]; then
    if ! rbenv versions 2>/dev/null | grep -q "$RUBY_LATEST"; then
      rbenv install "$RUBY_LATEST"
    fi
    rbenv global "$RUBY_LATEST"
    echo -e "${GREEN}✓${NC} Ruby $RUBY_LATEST installed and set as global"
  else
    echo -e "${YELLOW}⚠${NC} Could not determine Ruby version, skipping"
  fi
  echo ""
fi

# 6. TPM
if [[ " ${PREVIEW_ITEMS[*]} " =~ " tpm " ]]; then
  echo -e "${BLUE}Installing Tmux Plugin Manager...${NC}"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  echo -e "${GREEN}✓${NC} TPM installed"
  echo ""
fi

# 7. Claude Code
if [[ " ${PREVIEW_ITEMS[*]} " =~ " claude_code " ]]; then
  echo -e "${BLUE}Installing Claude Code...${NC}"
  curl -fsSL https://claude.ai/install.sh | bash
  echo -e "${GREEN}✓${NC} Claude Code installed"
  echo ""
fi

# 8. Symlinks
if [[ " ${PREVIEW_ITEMS[*]} " =~ " symlinks " ]]; then
  echo -e "${BLUE}Creating symlinks...${NC}"

  mkdir -p "$HOME/.config/git"
  mkdir -p "$HOME/.config/tmux"

  ln -sf "$DOTFILES/.zshrc"         "$HOME/.zshrc"
  ln -sf "$DOTFILES/.p10k.zsh"      "$HOME/.p10k.zsh"
  ln -sf "$DOTFILES/.gitconfig"     "$HOME/.gitconfig"
  ln -sf "$DOTFILES/git/ignore"     "$HOME/.config/git/ignore"
  ln -sf "$DOTFILES/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
  ln -sf "$DOTFILES/nvim"           "$HOME/.config/nvim"

  mkdir -p "$HOME/.claude/skills"
  ln -sf "$DOTFILES/claude/CLAUDE.md"              "$HOME/.claude/CLAUDE.md"
  ln -sf "$DOTFILES/claude/settings.json"          "$HOME/.claude/settings.json"
  ln -sf "$DOTFILES/claude/statusline-command.sh"  "$HOME/.claude/statusline-command.sh"

  for skill_dir in "$DOTFILES/claude/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    ln -sf "$DOTFILES/claude/skills/$skill_name" "$HOME/.claude/skills/$skill_name"
  done

  mkdir -p "$HOME/.local/bin"
  for script in "$DOTFILES/bin"/* "$DOTFILES/private/bin"/*; do
    [[ -f "$script" ]] || continue
    ln -sf "$script" "$HOME/.local/bin/$(basename "$script")"
  done

  if [[ -d "$DOTFILES/.git" ]]; then
    git -C "$DOTFILES" config core.hooksPath .githooks
  fi

  echo -e "${GREEN}✓${NC} Symlinks created"
  echo ""
fi

# ─── DONE ────────────────────────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Restart your terminal (or run: exec zsh)"
if [[ "$OS" == "Darwin" ]] && [[ " ${PREVIEW_ITEMS[*]} " =~ " macos_keyboard " ]]; then
  echo "  2. Log out and log back in for keyboard settings to take effect"
fi
echo "  3. Open nvim — plugins will install automatically via lazy.nvim"
echo "  4. In tmux, press prefix + I to install plugins via TPM"
echo ""
