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
if [ -f "$DOTFILES_DIR/packages.txt" ]; then
    mapfile -t pkgs < <(
        grep -vE '^\s*#|^\s*$' "$DOTFILES_DIR/packages.txt" || true
    )

    if [ "${#pkgs[@]}" -gt 0 ]; then
        sudo pacman -S --needed --noconfirm "${pkgs[@]}"
    fi
else
    echo "   > WARNING: packages.txt not found — skipping..."
fi

echo " > Checking for yay..."
if ! command -v yay &> /dev/null; then
    echo "   > Installing yay..."
    rm -rf yay
    git clone https://aur.archlinux.org/yay.git
    pushd yay >/dev/null
    
    if ! makepkg -si --noconfirm --cleanbuild; then
        echo "   > ERROR: yay installation failed"
        popd >/dev/null
        rm -rf yay
        exit 1
    fi
    popd >/dev/null
    rm -rf yay
fi

echo " > Installing AUR packages..."
if [ -f "$DOTFILES_DIR/aur.txt" ]; then
    mapfile -t aur_pkgs < <(
        grep -vE '^\s*#|^\s*$' "$DOTFILES_DIR/aur.txt" || true
    )

    if [ "${#aur_pkgs[@]}" -gt 0 ]; then
        yay -S --needed --noconfirm "${aur_pkgs[@]}" \
            || echo "   > WARNING: Some AUR packages failed to install"
    fi
else
    echo "   > WARNING: aur.txt not found — skipping..."
fi

echo " > Setting up configuration files..."
mkdir -p ~/.config
ln -sfn "$DOTFILES_DIR/i3wm" ~/.config/i3
ln -sfn "$DOTFILES_DIR/kitty" ~/.config/kitty
ln -sfn "$DOTFILES_DIR/picom" ~/.config/picom
ln -sfn "$DOTFILES_DIR/dunst" ~/.config/dunst
fc-cache -f
mkdir -p ~/.config/redshift
tee ~/.config/redshift/redshift.conf > /dev/null <<'EOF'
[redshift]
temp-day=3200
temp-night=2200
fade=0
dawn-time=4:00-6:00
dusk-time=17:00-18:30
brightness-day=1
brightness-night=0.9
gamma=1
location-provider=manual
adjustment-method=randr

[randr]
;screen=0
EOF

echo " > Setting up X session..."
tee ~/.xinitrc > /dev/null <<'EOF'
systemctl --user import-environment DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP
dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP

export XDG_CURRENT_DESKTOP=i3

exec i3
EOF

echo " > Setting up touchpad..."
touchpad_conf="/etc/X11/xorg.conf.d/30touchpad.conf"
sudo mkdir -p "$(dirname "$touchpad_conf")"
sudo tee "$touchpad_conf" > /dev/null <<'EOF'
Section "InputClass"
    Identifier "touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "TappingButtonMap" "lrm"
EndSection
EOF

echo " > Setting up battery notification daemon..."
mkdir -p ~/.local/bin
tee ~/.local/bin/battery-notify > /dev/null <<'EOF'
#!/bin/bash

THRESHOLD=20
BAT_PATH="/sys/class/power_supply"

while true; do
    for bat in "$BAT_PATH"/BAT*; do
        [ -e "$bat" ] || continue

        capacity=$(cat "$bat/capacity" 2>/dev/null)
        status=$(cat "$bat/status" 2>/dev/null)

        if [ "$status" = "Discharging" ] && [ "$capacity" -le "$THRESHOLD" ]; then
            notify-send -u critical "Battery Warning" "Battery is getting low (${capacity}%)"
            sleep 300
        fi
    done

    sleep 60
done
EOF

chmod +x ~/.local/bin/battery-notify

echo " > Configuring SSD TRIM..."

if ! command -v fstrim >/dev/null 2>&1; then
    echo "   > fstrim not found — installing util-linux..."
    sudo pacman -S --needed --noconfirm util-linux
fi

trim_devices=()

while read -r name type rota disc_gran disc_max; do
    if [ "$type" = "disk" ] &&
       [ "$rota" = "0" ] &&
       [ "$disc_gran" != "0B" ] &&
       [ "$disc_max" != "0B" ]; then

        trim_devices+=("/dev/$name")
    fi
done < <(
    lsblk -dn -o NAME,TYPE,ROTA,DISC-GRAN,DISC-MAX
)

if [ "${#trim_devices[@]}" -eq 0 ]; then
    echo "   > No SSD with TRIM/discard support detected — skipping..."
else
    for disk in "${trim_devices[@]}"; do
        echo "   > TRIM supported: $disk"
    done

    if systemctl is-enabled --quiet fstrim.timer &&
       systemctl is-active --quiet fstrim.timer; then

        echo "   > fstrim.timer already enabled and active — skipping initial TRIM..."

    else
        echo "   > Running initial TRIM..."
        if sudo fstrim -av; then
            echo "   > Initial TRIM completed successfully"
        else
            echo "   > WARNING: Initial TRIM failed — continuing..."
        fi

        echo "   > Enabling fstrim.timer..."
        sudo systemctl enable --now fstrim.timer
    fi

    if systemctl is-enabled --quiet fstrim.timer &&
       systemctl is-active --quiet fstrim.timer; then
        echo "   > fstrim.timer is enabled and active"
    else
        echo "   > WARNING: fstrim.timer could not be verified"
    fi
fi

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
    echo "   > No SATA HDDs detected — skipping..."
else
    mapfile -t hosts < <(find /sys/class/scsi_host/ -maxdepth 1 -type l | sed 's|.*/||')
    if [ ${#hosts[@]} -eq 0 ]; then  
        echo "   > No AHCI hosts detected — skipping..."  
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
    echo "   > No batteries detected — skipping..."
else
    # detect supported batteries
    supported_batteries=()

    for bat in "${batteries[@]}"; do
        if [ -w "/sys/class/power_supply/${bat}/charge_control_end_threshold" ] || \
           [ -w "/sys/class/power_supply/${bat}/charge_stop_threshold" ]; then
            supported_batteries+=("$bat")
        else
            echo "   > WARNING: $bat does not support charge thresholds — skipping..."
        fi
    done

    if [ ${#supported_batteries[@]} -eq 0 ]; then
        echo "   > WARNING: No batteries with charge threshold support detected — skipping..."
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
