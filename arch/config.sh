#!/bin/bash    
set -euo pipefail
cd "$(dirname "$0")"

echo "> Updating system..."
sudo pacman -Syu --noconfirm

echo "> Installing official packages..."
if [ -f packages.txt ]; then
    sudo pacman -S --needed --noconfirm $(cat packages.txt)
else
    echo "  > WARNING: packages.txt not found -- skipping..."
fi

echo "> Checking for yay..."
if ! command -v yay &> /dev/null; then
    echo "  > Installing yay..."
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm --cleanbuild
    cd ..
    rm -rf yay
fi

echo "> Installing AUR packages..."
if [ -f aur.txt ]; then
    yay -S --needed --noconfirm $(cat aur.txt) || echo "  > WARNING: Some AUR packages failed to install"
else
    echo "  > WARNING: aur.txt not found -- skipping..."
fi

echo "> Setting up configuration files..."
mkdir -p ~/.config
ln -sf "$(pwd)/i3" ~/.config/i3
ln -sf "$(pwd)/kitty" ~/.config/kitty
ln -sf "$(pwd)/picom" ~/.config/picom
fc-cache -fv
mkdir -p ~/.config/redshift
tee ~/.config/redshift/redshift.conf > /dev/null <<'EOF'
[redshift]
temp-day=5200
temp-night=3000
fade=0
dawn-time=3:30-5:30
dusk-time=17:00-18:30
brightness-day=1
brightness-night=0.9
gamma=1
location-provider=manual
adjustment-method=randr

[randr]
;screen=0
EOF

echo "> Setting up syncthing web shortcut..."
mkdir -p ~/.local/bin
tee ~/.local/bin/syncthing-web > /dev/null <<'EOF'
#!/bin/bash
firefox http://localhost:8384
EOF
chmod +x ~/.local/bin/syncthing-web
if ! grep -q 'export PATH="$PATH:$HOME/.local/bin"' ~/.bashrc; then
    echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
fi

echo "> Setting up wallpaper and screenshots folder..."
mkdir -p ~/Pictures/screenshots
if [ ! -f ~/Pictures/wallpaper.jpg ]; then
    if [ -f "$HOME/dotfiles/wallpapers/desktop2.jpg" ]; then
        cp "$HOME/dotfiles/wallpapers/desktop2.jpg" "$HOME/Pictures/wallpaper.jpg"
    else
        echo "  > WARNING: wallpapers/desktop2.jpg not found -- skipping"
    fi
fi

echo "> Setting up X session..."
echo "exec i3" > ~/.xinitrc

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

echo "> Enabling tlp power management service..."
sudo systemctl enable tlp.service
sudo systemctl start tlp.service

echo "> Optimizing disk power settings..."
mapfile -t hdds < <(lsblk -ndo NAME,TYPE,ROTA | awk '$2=="disk" && $3=="1" && $1 !~ /^nvme/ {print "/dev/"$1}')  
if [ ${#hdds[@]} -eq 0 ]; then
    echo "  > No SATA HDDs detected -- skipping..."
else
    mapfile -t hosts < <(find /sys/class/scsi_host/ -maxdepth 1 -type l | sed 's|.*/||')
    if [ ${#hosts[@]} -eq 0 ]; then  
        echo "  > No AHCI hosts detected -- skipping..."  
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
                echo "  > WARNING: Settings may not be correctly applied for $disk!"
                echo "    rpm_policy: $rpm_policy (expected: max_performance)"
                echo "    runtime_pm: $runtime_pm (expected: on)"
            fi
        done  
    fi  
fi  
    
echo "> Configuration completed!"
