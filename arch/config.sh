#!/bin/bash    
set -euo pipefail
cd "$(dirname "$0")"

echo "> Updating system..."
sudo pacman -Syu --noconfirm

echo "> Installing official packages..."
sudo pacman -S --needed --noconfirm - < packages.txt

echo "> Checking for yay..."
if ! command -v yay &> /dev/null; then
    echo "  > Installing yay..."
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm --noedit -C
    cd ..
    rm -rf yay
fi

echo "> Installing AUR packages..."
yay -S --needed - < aur.txt

echo "> Installing doom emacs..."
if [ ! -d ~/.emacs.d ]; then
    git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.emacs.d
    ~/.emacs.d/bin/doom install --no-env
else
    ~/.emacs.d/bin/doom sync
fi

echo "> Setting up configuration files..."
mkdir -p ~/.config
mkdir -p ~/org
ln -sf "$(pwd)/i3" ~/.config/i3
ln -sf "$(pwd)/kitty" ~/.config/kitty
ln -sf "$(pwd)/picom" ~/.config/picom
rm -rf ~/.doom.d
ln -sf "$(pwd)/doom" ~/.doom.d
fc-cache -fv
git -C ~/.emacs.d fetch origin && git -C ~/.emacs.d reset --hard origin/master
~/.emacs.d/bin/doom sync

echo "> Enabling tlp power management service..."
sudo systemctl enable tlp.service
sudo systemctl start tlp.service

echo "> Setting up wallpaper..."
mkdir -p ~/Pictures
if [ ! -f ~/Pictures/wallpaper.jpg ]; then
    cp "$(pwd)/wallpapers/lain.jpg" ~/Pictures/wallpaper.jpg
fi

echo "> Setting up X session..."
echo "exec i3" > ~/.xinitrc
chmod +x ~/.xinitrc

echo "> Setting up touchpad..."
touchpad_conf="/etc/X11/xorg.conf.d/30touchpad.conf"
sudo mkdir -p "$(dirname "$touchpad_conf")"
sudo tee "$touchpad_conf" > /dev/null <<'EOF'
Section "InputClass"
    Identifier "touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
EndSection
EOF

echo "> Optimizing disk power settings..."
mapfile -t hdds < <(lsblk -ndo NAME,TYPE,ROTA | awk '$2=="disk" && $3=="1" && $1 !~ /^nvme/ {print "/dev/"$1}')  
if [ ${#hdds[@]} -eq 0 ]; then
    echo "  > No SATA HDDs detected: Skipping..."
else
    mapfile -t hosts < <(find /sys/class/scsi_host/ -maxdepth 1 -type l | sed 's|.*/||')
    if [ ${#hosts[@]} -eq 0 ]; then  
        echo "  > No AHCI hosts detected: Skipping..."  
    else  
        conf="/etc/tlp.conf"  
        backup="/etc/tlpbackup.conf"  
        if [ -f "$conf" ]; then
            sudo cp "$conf" "$backup"  
        else
            sudo cp /usr/share/tlp/defaults.conf "$conf"  
        fi  
  
        edit_conf() {  
            local key="$1"  
            local value="$2"  
            if grep -qE "^\s*$key" "$conf"; then  
                sudo sed -i "s|^\s*$key.*|$key=$value|" "$conf"  
            else  
                echo "$key=$value" | sudo tee -a "$conf" >/dev/null  
            fi  
        }  
  
        denylist_hosts=$(IFS=,; echo "${hosts[*]}")  
        edit_conf "SATA_LINKPWR_DENYLIST" "\"$denylist_hosts\""  
        edit_conf "AHCI_RUNTIME_PM_ON_BAT" "on"  
  
        sudo systemctl restart tlp  
  
        for disk in "${hdds[@]}"; do  
            base=$(basename "$disk")  
            host_path=$(readlink -f /sys/block/$base/device/host*/)  
            rpm_policy_file="$host_path/link_power_management_policy"  
            runtime_pm_file="$host_path/device/power/control"  
  
            rpm_policy=$(cat "$rpm_policy_file" 2>/dev/null || echo "unknown")  
            runtime_pm=$(cat "$runtime_pm_file" 2>/dev/null || echo "unknown")
            
            if [ "$rpm_policy" != "max_performance" ] || [ "$runtime_pm" != "on" ]; then
        echo "  > ERROR: settings may not be correctly applied!"
    fi
        done  
    fi  
fi  
    
echo "> Configuration completed!"
