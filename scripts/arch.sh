#!/bin/bash    
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# verify sudo access
if ! sudo -v; then
    echo "ERROR: This script requires sudo privileges"
    exit 1
fi

echo " > Updating system..."
sudo pacman -Syu --noconfirm

echo " > Installing official packages..."
if [ -f packages.txt ]; then
    sudo pacman -S --needed --noconfirm $(cat packages.txt)
else
    echo "   > WARNING: packages.txt not found -- skipping..."
fi

echo " > Checking for yay..."
if ! command -v yay &> /dev/null; then
    echo "   > Installing yay..."
    rm -rf yay
    git clone https://aur.archlinux.org/yay.git
    cd yay
    if ! makepkg -si --noconfirm --cleanbuild; then
        echo "   > ERROR: yay installation failed"
        cd ..
        rm -rf yay
        exit 1
    fi
    cd ..
    rm -rf yay
fi

echo " > Installing AUR packages..."
if [ -f aur.txt ]; then
    yay -S --needed --noconfirm $(cat aur.txt) || echo "   > WARNING: Some AUR packages failed to install"
else
    echo "   > WARNING: aur.txt not found -- skipping..."
fi

echo " > Setting up configuration files..."
mkdir -p ~/.config
ln -sf "$DOTFILES_DIR/i3" ~/.config/i3
ln -sf "$DOTFILES_DIR/kitty" ~/.config/kitty
ln -sf "$DOTFILES_DIR/picom" ~/.config/picom
fc-cache -fv
mkdir -p ~/.config/redshift
tee ~/.config/redshift/redshift.conf > /dev/null <<'EOF'
[redshift]
temp-day=4800
temp-night=2900
fade=0
dawn-time=3:40-5:20
dusk-time=17:30-18:30
brightness-day=1
brightness-night=0.9
gamma=1
location-provider=manual
adjustment-method=randr

[randr]
;screen=0
EOF

echo " > Setting up syncthing web shortcut..."
mkdir -p ~/.local/bin
tee ~/.local/bin/syncthing-web > /dev/null <<'EOF'
#!/bin/bash
firefox http://localhost:8384
EOF
chmod +x ~/.local/bin/syncthing-web
if ! grep -q 'export PATH="$PATH:$HOME/.local/bin"' ~/.bashrc; then
    echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
fi

echo " > Setting up wallpaper and screenshots folder..."
mkdir -p ~/Pictures/screenshots
if [ -f "$DOTFILES_DIR/wallpapers/desktop2.jpg" ]; then
    cp "$DOTFILES_DIR/wallpapers/desktop2.jpg" "$HOME/Pictures/wallpaper.jpg"
else
    echo "   > WARNING: wallpapers/desktop2.jpg not found -- skipping..."
fi

echo " > Setting up X session..."
echo "exec i3" > ~/.xinitrc

echo " > Setting up touchpad..."
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

echo " > Enabling tlp power management service..."
sudo systemctl enable tlp.service
sudo systemctl start tlp.service

# unified edit_conf function
edit_tlp_conf() {
    local key="$1"
    local value="$2"
    local conf="/etc/tlp.conf"
    
    if grep -qE "^\s*#?\s*${key}=" "$conf"; then
        sudo sed -i "s|^\s*#\?\\s*${key}=.*|${key}=${value}|" "$conf"
    else
        echo "${key}=${value}" | sudo tee -a "$conf" >/dev/null
    fi
}

echo " > Optimizing disk power settings (tlp)..."
mapfile -t hdds < <(lsblk -ndo NAME,TYPE,ROTA | awk '$2=="disk" && $3=="1" && $1 !~ /^nvme/ {print "/dev/"$1}')  
if [ ${#hdds[@]} -eq 0 ]; then
    echo "   > No SATA HDDs detected -- skipping..."
else
    mapfile -t hosts < <(find /sys/class/scsi_host/ -maxdepth 1 -type l | sed 's|.*/||')
    if [ ${#hosts[@]} -eq 0 ]; then  
        echo "   > No AHCI hosts detected -- skipping..."  
    else  
        conf="/etc/tlp.conf"  
        if [ ! -f "$conf" ]; then
            sudo cp /usr/share/tlp/defaults.conf "$conf"  
        fi  
  
        denylist_hosts=$(IFS=,; echo "${hosts[*]}")  
        edit_tlp_conf "SATA_LINKPWR_DENYLIST" "\"$denylist_hosts\""  
        edit_tlp_conf "AHCI_RUNTIME_PM_ON_BAT" "on"  
  
        sudo systemctl restart tlp  
  
        for disk in "${hdds[@]}"; do  
            base=$(basename "$disk")  
            host_path=$(readlink -f /sys/block/$base/device/host*/)  
            rpm_policy_file="$host_path/link_power_management_policy"  
            runtime_pm_file="$host_path/device/power/control"  
  
            rpm_policy=$(cat "$rpm_policy_file" 2>/dev/null || echo "unknown")  
            runtime_pm=$(cat "$runtime_pm_file" 2>/dev/null || echo "unknown")
            
            if [ "$rpm_policy" != "max_performance" ] || [ "$runtime_pm" != "on" ]; then
                echo "   > WARNING: Settings may not be correctly applied for $disk!"
                echo "      > rpm_policy: $rpm_policy (expected: max_performance)"
                echo "      > runtime_pm: $runtime_pm (expected: on)"
            fi
        done  
    fi  
fi  

echo " > Configuring battery charge thresholds (tlp)..."

START_CHARGE=75
STOP_CHARGE=80
TLP_CONF="/etc/tlp.conf"
TLP_DEFAULTS="/usr/share/tlp/defaults.conf"

# battery detection
mapfile -t batteries < <(ls /sys/class/power_supply/ 2>/dev/null | grep '^BAT' || true)

if [ ${#batteries[@]} -eq 0 ]; then
    echo "   > No batteries detected -- skipping..."
else
    # detect supported batteries
    supported_batteries=()

    for bat in "${batteries[@]}"; do
        if [ -w "/sys/class/power_supply/${bat}/charge_control_end_threshold" ] || \
           [ -w "/sys/class/power_supply/${bat}/charge_stop_threshold" ]; then
            supported_batteries+=("$bat")
        else
            echo "   > WARNING: $bat does not support charge thresholds -- skipping..."
        fi
    done

    if [ ${#supported_batteries[@]} -eq 0 ]; then
        echo "   > WARNING: No batteries with charge threshold support detected -- skipping..."
    else
        # ensure tlp.conf exists
        if [ ! -f "$TLP_CONF" ]; then
            sudo cp "$TLP_DEFAULTS" "$TLP_CONF"
        fi

        # configure thresholds
        for bat in "${supported_batteries[@]}"; do
            echo "   > Setting thresholds for $bat (${START_CHARGE}% → ${STOP_CHARGE}%)"
            edit_tlp_conf "START_CHARGE_THRESH_${bat}" "$START_CHARGE"
            edit_tlp_conf "STOP_CHARGE_THRESH_${bat}" "$STOP_CHARGE"
        done

        # apply
        sudo systemctl restart tlp
        sleep 2

        # verify
        for bat in "${supported_batteries[@]}"; do
            start="unknown"
            stop="unknown"

            if [ -f "/sys/class/power_supply/${bat}/charge_control_start_threshold" ]; then
                start=$(cat "/sys/class/power_supply/${bat}/charge_control_start_threshold" 2>/dev/null || echo "unknown")
                stop=$(cat "/sys/class/power_supply/${bat}/charge_control_end_threshold" 2>/dev/null || echo "unknown")
            elif [ -f "/sys/class/power_supply/${bat}/charge_start_threshold" ]; then
                start=$(cat "/sys/class/power_supply/${bat}/charge_start_threshold" 2>/dev/null || echo "unknown")
                stop=$(cat "/sys/class/power_supply/${bat}/charge_stop_threshold" 2>/dev/null || echo "unknown")
            fi

            if [ "$start" != "$START_CHARGE" ] || [ "$stop" != "$STOP_CHARGE" ]; then
                echo "   > WARNING: Thresholds may not be correctly applied for $bat!"
                echo "      > start: $start (expected: $START_CHARGE)"
                echo "      > stop:  $stop  (expected: $STOP_CHARGE)"
            fi
        done
    fi
fi

echo " > Done!"
