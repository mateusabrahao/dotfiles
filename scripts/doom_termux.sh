#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

DOTFILES_REPO="https://github.com/mateusabrahao/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
DOOM_DIR="$HOME/.config/emacs"
DOOM_CONFIG_DIR="$HOME/.config/doom"
BASHRC="$HOME/.bashrc"
TERMUX_DIR="$HOME/.termux"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/SourceCodePro/SauceCodeProNerdFontMono-Regular.ttf"

echo " > Updating packages..."
pkg update -y && pkg upgrade -y

if [ ! -d "$HOME/storage" ]; then
    echo " > Setting up Termux storage..."
    termux-setup-storage
else
    echo "   > Termux storage already set up -- skipping..."
fi

echo " > Installing required packages..."
pkg install -y \
  git \
  emacs \
  ripgrep \
  fd \
  clang \
  coreutils \
  aspell \
  aspell-en \
  nodejs \
  curl \
  termux-api

echo " > Setting up Termux font..."
mkdir -p "$TERMUX_DIR"
curl -fL "$FONT_URL" -o "$TERMUX_DIR/font.ttf"
if command -v termux-reload-settings &> /dev/null; then
    termux-reload-settings
fi

if [ ! -d "$DOOM_DIR" ]; then
    echo " > Cloning Doom Emacs..."
    git clone --depth 1 https://github.com/doomemacs/doomemacs "$DOOM_DIR"
else
    echo "   > Doom Emacs already exists -- skipping..."
fi

if ! grep -q 'config/emacs/bin' "$BASHRC" 2>/dev/null; then
    echo " > Adding Doom to PATH..."
    echo 'export PATH="$HOME/.config/emacs/bin:$PATH"' >> "$BASHRC"
else
    echo "   > Doom already in PATH -- skipping..."
fi

if [ ! -d "$DOTFILES_DIR" ]; then
    echo " > Cloning dotfiles repository..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
    echo "   > Dotfiles repo already exists -- skipping..."
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
        echo "   > WARNING: $SRC not found -- skipping..."
    fi
done

echo " > Installing Doom Emacs..."
"$DOOM_DIR/bin/doom" install --force

echo " > Setting up emacs alias..."
if ! grep -q 'alias emacs="emacs -nw"' ~/.bashrc; then
    echo 'alias emacs="emacs -nw"' >> ~/.bashrc
fi

echo " > Syncing Doom configuration..."
"$DOOM_DIR/bin/doom" sync

echo " > Doom Emacs setup complete!"
echo " > Run: source ~/.bashrc"
