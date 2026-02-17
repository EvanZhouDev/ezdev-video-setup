#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_SETTINGS_FILE="$SCRIPT_DIR/settings.json"
MERGE_SCRIPT_FILE="$SCRIPT_DIR/scripts/merge-vscode-settings.ts"
VSCODE_SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
VSCODE_SETTINGS_FILE="$VSCODE_SETTINGS_DIR/settings.json"

log() {
  printf '[setup] %s\n' "$1"
}

load_homebrew_env() {
  if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
    return 0
  fi

  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi

  if [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return 0
  fi

  return 1
}

install_homebrew_if_needed() {
  if load_homebrew_env; then
    log "Homebrew is already installed."
    return
  fi

  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if ! load_homebrew_env; then
    log "Homebrew installed, but brew is not available in this shell. Open a new shell and run setup again."
    return 1
  fi
}

install_formula_if_missing() {
  local formula="$1"
  if brew list --formula "$formula" >/dev/null 2>&1; then
    log "Formula already installed: $formula"
  else
    log "Installing formula: $formula"
    brew install "$formula"
  fi
}

install_cask_if_missing() {
  local cask="$1"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    log "Cask already installed: $cask"
  else
    log "Installing cask: $cask"
    brew install --cask "$cask"
  fi
}

install_vscode_extensions() {
  local code_bin="code"
  local vscode_cli_path="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  local extensions=(
    "miguelsolorio.fluent-icons"
    "zhuangtongfa.material-theme"
    "miguelsolorio.symbols"
    "asvetliakov.vscode-neovim"
  )

  if ! command -v "$code_bin" >/dev/null 2>&1; then
    if [[ -x "$vscode_cli_path" ]]; then
      code_bin="$vscode_cli_path"
      log "Using VS Code CLI from app bundle: $code_bin"
    else
      log "VS Code CLI not found. Skipping extension installation."
      return
    fi
  fi

  for extension in "${extensions[@]}"; do
    log "Installing VS Code extension: $extension"
    "$code_bin" --install-extension "$extension" --force
  done
}

merge_vscode_settings() {
  local backup_file=""

  if [[ ! -f "$LOCAL_SETTINGS_FILE" ]]; then
    log "Local settings file not found at $LOCAL_SETTINGS_FILE. Skipping merge."
    return
  fi

  log "Merging local VS Code settings into: $VSCODE_SETTINGS_FILE"
  mkdir -p "$VSCODE_SETTINGS_DIR"

  if [[ -f "$VSCODE_SETTINGS_FILE" ]]; then
    backup_file="$VSCODE_SETTINGS_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$VSCODE_SETTINGS_FILE" "$backup_file"
    log "Backed up existing settings to: $backup_file"
  else
    printf '{}\n' > "$VSCODE_SETTINGS_FILE"
    log "No existing settings file found. Created a new one."
  fi

  if [[ ! -f "$MERGE_SCRIPT_FILE" ]]; then
    log "Merge script not found at $MERGE_SCRIPT_FILE"
    return 1
  fi

  if ! command -v bun >/dev/null 2>&1; then
    log "bun is required for VS Code settings merge, but it is not installed."
    return 1
  fi

  if ! bun run "$MERGE_SCRIPT_FILE" "$LOCAL_SETTINGS_FILE" "$VSCODE_SETTINGS_FILE"
  then
    log "VS Code settings merge failed."
    if [[ -n "$backup_file" ]]; then
      log "You can restore previous settings from: $backup_file"
    fi
    return 1
  fi

  log "VS Code settings merge complete."
}

copy_zshrc() {
  local source="$SCRIPT_DIR/.zshrc"
  local target="$HOME/.zshrc"

  if [[ -f "$source" ]]; then
    cp "$source" "$target"
    log "Copied $source to $target"
  else
    log "No local .zshrc found at $source. Skipping."
  fi
}

main() {
  log "Starting environment setup..."
  install_homebrew_if_needed

  log "Installing IDEs..."
  install_cask_if_missing "visual-studio-code"
  install_formula_if_missing "neovim"

  log "Installing runtimes..."
  install_formula_if_missing "node"
  install_formula_if_missing "bun"

  log "Installing agent tools..."
  install_formula_if_missing "codex"
  install_formula_if_missing "anomalyco/tap/opencode"

  log "Installing font..."
  install_cask_if_missing "font-fira-code-nerd-font"

  log "Installing developer tools..."
  install_formula_if_missing "gnupg"
  install_formula_if_missing "zsh-syntax-highlighting"
  install_formula_if_missing "ripgrep"
  install_formula_if_missing "powerlevel10k"

  log "Configuring VS Code..."
  install_vscode_extensions
  merge_vscode_settings

  log "Setting up shell config..."
  copy_zshrc

  log "Setup complete."
}

main "$@"
