#!/bin/bash

# Gaming Setup Script for Arch Linux with Hyprland
# Supports installation and full revert of changes

set -e

BACKUP_DIR="$HOME/.gaming_setup_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$BACKUP_DIR/setup_$TIMESTAMP.log"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to backup a file
backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        local backup_path="$BACKUP_DIR/$(basename $file)_$TIMESTAMP"
        cp "$file" "$backup_path"
        log "Backed up: $file -> $backup_path"
        echo "$file|$backup_path" >> "$BACKUP_DIR/file_mapping.txt"
    fi
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        error "Please run this script as a normal user, not root. Sudo will be used when needed."
        exit 1
    fi
}

# Function to install packages
install_packages() {
    log "Installing gaming packages..."
    
    # Check if multilib is enabled
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        warning "Multilib repository not enabled. Enabling it now..."
        backup_file "/etc/pacman.conf"
        sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
        sudo pacman -Sy
        log "Multilib repository enabled"
    else
        log "Multilib repository already enabled"
    fi
    
    # Check for nvidia-open and handle driver selection
    local nvidia_pkg="nvidia-open-dkms"
    
    # Install packages
    local packages=(
        # Core gaming
        "steam"
        
        # NVIDIA drivers
        "$nvidia_pkg"
        "nvidia-utils"
        "nvidia-settings"
        "lib32-nvidia-utils"
        
        # Vulkan support
        "vulkan-tools"
        "vulkan-icd-loader"
        "lib32-vulkan-icd-loader"
        
        # 32-bit libraries
        "lib32-mesa"
        
        # Performance tools
        "gamemode"
        "lib32-gamemode"
        "mangohud"
        "lib32-mangohud"
    )
    
    log "Installing: ${packages[*]}"
    # sudo pacman -S --needed --noconfirm "${packages[@]}"
    yay -S --needed --noconfirm "${packages[@]}"

    # Save installed packages list
    echo "${packages[@]}" > "$BACKUP_DIR/installed_packages_$TIMESTAMP.txt"
    
    log "Core packages installed successfully"
}

# Install aur packages
install_aur_packages() {   
    log "Installing AUR packages with $aur_helper..."
    yay -S --needed --noconfirm protonup-qt goverlay
    
    echo "protonup-qt goverlay" > "$BACKUP_DIR/aur_packages_$TIMESTAMP.txt"
    log "AUR packages installed successfully"
}

# Function to configure bootloader
configure_bootloader() {
    log "Configuring bootloader..."
    
    # Detect bootloader
    local bootloader=""
    if [ -f "/boot/loader/entries/"*.conf ]; then
        bootloader="systemd-boot"
        local conf_file=$(ls /boot/loader/entries/*.conf | head -n 1)
        backup_file "$conf_file"
        
        if ! grep -q "nvidia-drm.modeset=1" "$conf_file"; then
            sudo sed -i '/^options/ s/$/ nvidia-drm.modeset=1/' "$conf_file"
            log "Added nvidia-drm.modeset=1 to $conf_file"
            echo "bootloader|systemd-boot|$conf_file" >> "$BACKUP_DIR/bootloader_changes.txt"
        else
            log "nvidia-drm.modeset=1 already present in bootloader config"
        fi
    elif [ -f "/etc/default/grub" ]; then
        bootloader="grub"
        backup_file "/etc/default/grub"
        
        if ! grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
            log "Added nvidia-drm.modeset=1 to GRUB config"
            echo "bootloader|grub|/etc/default/grub" >> "$BACKUP_DIR/bootloader_changes.txt"
        else
            log "nvidia-drm.modeset=1 already present in GRUB config"
        fi
    else
        warning "Could not detect bootloader. Please manually add 'nvidia-drm.modeset=1' to your kernel parameters"
    fi
}

# Function to configure Hyprland
configure_hyprland() {
    log "Configuring Hyprland for NVIDIA..."
    
    local hypr_conf="$HOME/.config/hypr/hyprland.conf"
    
    if [ ! -f "$hypr_conf" ]; then
        warning "Hyprland config not found at $hypr_conf. Creating it..."
        mkdir -p "$HOME/.config/hypr"
        touch "$hypr_conf"
    fi
    
    backup_file "$hypr_conf"
    
    # Check if NVIDIA env vars already exist
    if grep -q "LIBVA_DRIVER_NAME,nvidia" "$hypr_conf"; then
        log "NVIDIA environment variables already present in Hyprland config"
        return
    fi
    
    # Add NVIDIA environment variables
    cat >> "$hypr_conf" << 'EOF'

# Gaming Setup Script - NVIDIA Configuration
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1

EOF
    
    log "Added NVIDIA environment variables to Hyprland config"
    echo "hyprland|$hypr_conf" >> "$BACKUP_DIR/hyprland_changes.txt"
}

# Function to configure nvidia modules
configure_nvidia_modules() {
    log "Configuring NVIDIA kernel modules..."
    
    local mkinitcpio_conf="/etc/mkinitcpio.conf"
    backup_file "$mkinitcpio_conf"
    
    if ! grep -q "nvidia nvidia_modeset nvidia_uvm nvidia_drm" "$mkinitcpio_conf"; then
        sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$mkinitcpio_conf"
        sudo mkinitcpio -P
        log "Added NVIDIA modules to mkinitcpio"
        echo "mkinitcpio|$mkinitcpio_conf" >> "$BACKUP_DIR/mkinitcpio_changes.txt"
    else
        log "NVIDIA modules already present in mkinitcpio.conf"
    fi
    
    # Create nvidia hook
    local nvidia_hook="/etc/pacman.d/hooks/nvidia.hook"
    if [ ! -f "$nvidia_hook" ]; then
        sudo mkdir -p /etc/pacman.d/hooks
        sudo tee "$nvidia_hook" > /dev/null << 'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia
Target=linux

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF
        log "Created NVIDIA pacman hook"
        echo "nvidia_hook|$nvidia_hook" >> "$BACKUP_DIR/nvidia_hook.txt"
    fi
}

# Function to create Steam launch helper
create_steam_helper() {
    log "Creating Steam launch helper script..."
    
    local helper_script="$HOME/.local/bin/steam-game"
    mkdir -p "$HOME/.local/bin"
    
    cat > "$helper_script" << 'EOF'
#!/bin/bash
# Steam Game Launch Helper
# Usage: Add "steam-game %command%" to Steam launch options
gamemoderun mangohud "$@"
EOF
    
    chmod +x "$helper_script"
    log "Created Steam launch helper at $helper_script"
    log "To use: Add 'steam-game %command%' to game launch options in Steam"
    
    echo "steam_helper|$helper_script" >> "$BACKUP_DIR/steam_helper.txt"
}

# Main installation function
install_gaming_setup() {
    log "=== Starting Gaming Setup Installation ==="
    log "Backup directory: $BACKUP_DIR"
    
    check_root
    
    install_packages
    install_aur_packages
    configure_bootloader
    configure_nvidia_modules
    configure_hyprland
    create_steam_helper
    
    log "=== Installation Complete ==="
    log ""
    log "IMPORTANT: You must reboot for all changes to take effect!"
    log ""
    log "After reboot:"
    log "  1. Launch ProtonUp-Qt and install Proton-GE"
    log "  2. In Steam, enable Proton compatibility for all titles"
    log "  3. For individual games, add launch option: gamemoderun mangohud %command%"
    log "  4. Or use: steam-game %command%"
    log ""
    log "To revert all changes: ./gaming_setup.sh --revert"
    log "Backup location: $BACKUP_DIR"
}

# Revert function
revert_changes() {
    log "=== Starting Revert Process ==="
    
    if [ ! -d "$BACKUP_DIR" ]; then
        error "No backup directory found at $BACKUP_DIR"
        exit 1
    fi
    
    warning "This will revert all changes made by the gaming setup script."
    warning "Installed packages will NOT be removed automatically."
    echo -n "Continue? (yes/no): "
    read -r confirm
    
    if [ "$confirm" != "yes" ]; then
        log "Revert cancelled"
        exit 0
    fi
    
    # Restore backed up files
    if [ -f "$BACKUP_DIR/file_mapping.txt" ]; then
        while IFS='|' read -r original backup; do
            if [ -f "$backup" ]; then
                sudo cp "$backup" "$original"
                log "Restored: $original"
            fi
        done < "$BACKUP_DIR/file_mapping.txt"
    fi
    
    # Remove Hyprland additions
    if [ -f "$BACKUP_DIR/hyprland_changes.txt" ]; then
        while IFS='|' read -r type file; do
            if [ -f "$file" ]; then
                # Remove lines added by script
                sudo sed -i '/# Gaming Setup Script - NVIDIA Configuration/,/^$/d' "$file"
                log "Removed NVIDIA config from: $file"
            fi
        done < "$BACKUP_DIR/hyprland_changes.txt"
    fi
    
    # Remove NVIDIA hook
    if [ -f "$BACKUP_DIR/nvidia_hook.txt" ]; then
        while IFS='|' read -r type file; do
            if [ -f "$file" ]; then
                sudo rm "$file"
                log "Removed: $file"
            fi
        done < "$BACKUP_DIR/nvidia_hook.txt"
    fi
    
    # Remove Steam helper
    if [ -f "$BACKUP_DIR/steam_helper.txt" ]; then
        while IFS='|' read -r type file; do
            if [ -f "$file" ]; then
                rm "$file"
                log "Removed: $file"
            fi
        done < "$BACKUP_DIR/steam_helper.txt"
    fi
    
    # Rebuild initramfs if needed
    if [ -f "$BACKUP_DIR/mkinitcpio_changes.txt" ]; then
        sudo mkinitcpio -P
        log "Rebuilt initramfs"
    fi
    
    # Rebuild GRUB if needed
    if [ -f "$BACKUP_DIR/bootloader_changes.txt" ]; then
        if grep -q "grub" "$BACKUP_DIR/bootloader_changes.txt"; then
            sudo grub-mkconfig -o /boot/grub/grub.cfg
            log "Rebuilt GRUB configuration"
        fi
    fi
    
    # Restore nvidia-open if it was removed
    if [ -f "$BACKUP_DIR/removed_nvidia_open.txt" ]; then
        warning "Restoring nvidia-open driver..."
        sudo pacman -Rdd --noconfirm nvidia
        sudo pacman -S --noconfirm nvidia-open
        log "Restored nvidia-open driver"
    fi
    
    log "=== Revert Complete ==="
    log ""
    log "To remove installed packages, run:"
    log "  sudo pacman -Rns steam nvidia nvidia-utils lib32-nvidia-utils gamemode lib32-gamemode mangohud lib32-mangohud"
    log ""
    log "You should reboot your system for changes to take effect."
    log "Backup files are preserved in: $BACKUP_DIR"
}

# Show usage
show_usage() {
    echo "Gaming Setup Script for Arch Linux with Hyprland"
    echo ""
    echo "Usage:"
    echo "  $0              Install gaming optimizations"
    echo "  $0 --revert     Revert all changes"
    echo "  $0 --help       Show this help message"
    echo ""
    echo "All changes are backed up to: $BACKUP_DIR"
}

# Main script logic
case "${1:-}" in
    --revert)
        revert_changes
        ;;
    --help)
        show_usage
        ;;
    "")
        install_gaming_setup
        ;;
    *)
        error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
