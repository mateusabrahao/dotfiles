#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

DOOM_FILES_URL="https://raw.githubusercontent.com/mateusabrahao/dotfiles/main/doom"
DOOM_DIR="$HOME/.config/emacs"
DOOM_CONFIG_DIR="$HOME/.config/doom"
BASHRC="$HOME/.bashrc"
TERMUX_DIR="$HOME/.termux"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/SourceCodePro/SauceCodeProNerdFontMono-Regular.ttf"

echo " > Updating packages..."
pkg update -y && pkg upgrade -y

echo " > Installing required packages..."
pkg install -y \
  curl \
  git \
  emacs \
  ripgrep \
  fd \
  clang \
  coreutils \
  hunspell \
  hunspell-en-us \
  nodejs \
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
    echo "   > Doom Emacs already exists — skipping..."
fi

if ! grep -q 'config/emacs/bin' "$BASHRC" 2>/dev/null; then
    echo " > Adding Doom to PATH..."
    echo 'export PATH="$HOME/.config/emacs/bin:$PATH"' >> "$BASHRC"
else
    echo "   > Doom already in PATH — skipping..."
fi

echo " > Downloading Doom configuration files..."
mkdir -p "$DOOM_CONFIG_DIR"

for file in config.el init.el packages.el; do
    echo "   > Downloading $file..."
    curl -fsSL "$DOOM_FILES_URL/$file" \
        -o "$DOOM_CONFIG_DIR/$file"
    echo "   > Saved $file"
done

echo " > Installing Doom Emacs..."
"$DOOM_DIR/bin/doom" install

echo " > Syncing Doom configuration..."
"$DOOM_DIR/bin/doom" sync

echo " > Doom Emacs setup complete!"
echo " > Run: source ~/.bashrc"
