#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

DOTFILES_REPO="https://github.com/mateusabrahao/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
DOOM_DIR="$HOME/.config/emacs"
DOOM_CONFIG_DIR="$HOME/.config/doom"
BASHRC="$HOME/.bashrc"

echo " > Updating packages..."
pkg update -y && pkg upgrade -y

echo " > Installing required packages..."
pkg install -y \
  git \
  emacs \
  ripgrep \
  fd \
  clang \
  coreutils

if [ ! -d "$DOOM_DIR" ]; then
    echo " > Cloning Doom Emacs..."
    git clone https://github.com/doomemacs/doomemacs "$DOOM_DIR"
else
    echo "   > Doom Emacs already exists -- skipping"
fi

if ! grep -q 'config/emacs/bin' "$BASHRC"; then
    echo " > Adding Doom to PATH..."
    echo 'export PATH="$HOME/.config/emacs/bin:$PATH"' >> "$BASHRC"
else
    echo "   > Doom already in PATH -- skipping"
fi

source "$BASHRC"

if [ ! -d "$DOTFILES_DIR" ]; then
    echo " > Cloning dotfiles repository..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
    echo "   > Dotfiles repo already exists -- pulling updates..."
    git -C "$DOTFILES_DIR" pull
fi

echo " > Setting up Doom configuration..."
mkdir -p "$DOOM_CONFIG_DIR"

for file in config.el init.el packages.el; do
    SRC="$DOTFILES_DIR/doom/$file"
    DEST="$DOOM_CONFIG_DIR/$file"

    if [ -f "$SRC" ]; then
        ln -sf "$SRC" "$DEST"
        echo "   > Linked $file"
    else
        echo "   > WARNING: $SRC not found -- skipping"
    fi
done

echo " > Installing Doom Emacs..."
"$DOOM_DIR/bin/doom" install --force

echo " > Syncing Doom configuration..."
doom sync

echo " > Doom Emacs setup complete!"
echo " > Restart Termux or run: source ~/.bashrc"
echo " > Launch with: emacs -nw"
