#!/bin/bash

INSTLOG="install.log"
CNT="[\e[1;36mINFO\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CAT="[\e[1;37mATTENTION\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"
CAC="[\e[1;33mACTION\e[0m]"

PACKAGES=(
    "hyprland"
    "hyprpaper"
    "kitty"
    "git"
    "jq"
    "fzf"
    "xdg-desktop-portal-hyprland"
    "polkit-gnome"
    "pamixer"
    "pavucontrol"
    "bluez"
    "bluez-utils"
    "blueman"
    "network-manager-applet"
    "networkmanager-openvpn"
    "openssh"
    "gvfs"
    "btop"
    "pacman-contrib"
    "ttf-jetbrains-mono-nerd"
    "noto-fonts-emoji"
    "lxappearance"
    "xfce4-settings"
    "sddm"
    "tree"
    "qt5-svg"
    "qt5-quickcontrols2"
    "qt5-graphicaleffects"
    "firefox"
    "neofetch"
    "cifs-utils"
    "zsh"
    "zsh-syntax-highlighting"
    "gtk4"
    "gtk-layer-shell"
    "gdk-pixbuf2"
    "libdbusmenu-gtk3"
    "helix"
    "thunar"
    "wofi"
    "mako"
)

clear

#### Check for package manager ####
echo -e "$CNT - Installing yay..."
ISYAY=/sbin/yay
if [ -f "$ISYAY" ]; then
    echo -e "$COK - Found yay"
else
    git clone https://aur.archlinux.org/yay.git &>>$INSTLOG
    cd yay
    makepkg -si --noconfirm &>>../$INSTLOG
    cd ..
    # update the yay database
    echo -e "$CNT - Updating the yay database..."
    yay -Suy --noconfirm &>>$INSTLOG
fi

# # Update yey database
echo -e "$CNT - Updating the yay database..."
yay -Suy --noconfirm

# function that will test for a package and if not found it will attempt to install it
install() {
    # First lets see if the package is there
    if yay -Q $1 &>>/dev/null; then
        echo -e "$COK - $1 is already installed."
    else
        # no package found so installing
        echo -e "$CNT - Now installing $1 ..."
        yay -S --noconfirm $1 &>>$INSTLOG
        # test to make sure package installed
        if yay -Q $1 &>>/dev/null; then
            echo -e "\e[1A\e[K$COK - $1 was installed."
        else
            # if this is hit then a package is missing, exit to review log
            echo -e "\e[1A\e[K$CER - $1 install failed, please check the install.log"
            exit
        fi
    fi
}

# Install all the above packages
for PKG in ${PACKAGES[@]}; do
    install $PKG
done

# Correctly set the Timezone and Locale
timedatectl set-local-rtc 1 --adjust-system-clock
sudo timedatectl set-timezone Europe/London


# Start the bluetooth service
echo -e "$CNT - Starting the Bluetooth Service..."
sudo systemctl enable --now bluetooth.service &>>$INSTLOG
sleep 2

# Start the network manager applet service
echo -e "$CNT - Starting the Network Manager Service..."
sudo systemctl enable --now NetworkManager.service

# Enable the sddm login manager service
echo -e "$CNT - Enabling the SDDM Service..."
sudo systemctl enable sddm &>>$INSTLOG
sleep 2

# Enable and start ssh-agent service
echo -e "$CNT - Enabling and starting the SSH Agent Service..."
sudo systemctl --user enable --now ssh-agent &>>$INSTLOG

# Clean out other portals
echo -e "$CNT - Cleaning out conflicting xdg portals..."
yay -R --noconfirm xdg-desktop-portal-gnome xdg-desktop-portal-gtk &>>$INSTLOG

# Copy the SDDM theme
echo -e "$CNT - Setting up the login screen."
sudo mkdir -p /usr/share/sddm/themes
sudo cp -R $PWD/Tools/sdt /usr/share/sddm/themes/
sudo chown -R $USER:$USER /usr/share/sddm/themes/sdt
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=sdt" | sudo tee -a /etc/sddm.conf.d/10-theme.conf &>>$INSTLOG
cp $PWD/Dotfiles/sddm/twinsystem.jpg /usr/share/sddm/themes/sdt/wallpaper.jpg
WLDIR=/usr/share/wayland-sessions
if [ -d "$WLDIR" ]; then
    echo -e "$COK - $WLDIR found"
else
    echo -e "$CWR - $WLDIR NOT found, creating..."
    sudo mkdir $WLDIR
fi

# Change shell to zsh
echo -e "$CNT - Changing shell to Zsh..."
sudo chsh -s $(which zsh) $(whoami) &>>$INSTLOG

# Install ohmyzsh
echo -e "$CNT - Installing Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended &>>$INSTLOG

# Install Zsh Auto-Suggestions
echo -e "$CNT - Installing Zsh Auto-Suggestions..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions &>>$INSTLOG

# Install Zsh Syntax-Highlighting
echo -e "$CNT - Installing Zsh Syntax-Highlighting..."
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting &>>$INSTLOG

# Create the config directories
echo -e "$COK - Creating Config Directories..."
CONFIG_DIRECTORIES=("gtk-4.0" "hypr" "kitty" "neofetch" "qt5ct" "xfce4" "wallpapers" "btop/themes" "helix/themes" "wofi" )
for DIR in ${CONFIG_DIRECTORIES[@]}; do
    mkdir -p ~/.config/$DIR && echo -e "$CNT - Created ~/.config/$DIR"
done

# These config directories are not in the .config directory
ROOT_DIRECTORIES=(".themes" ".scripts/non-exec" ".scripts/non-commit" ".scripts/backup" ".icons" "Pictures" "Pictures/Screenshots" ".local/share/Steam")
for DIR in ${ROOT_DIRECTORIES[@]}; do
    mkdir -p ~/$DIR && echo -e "$CNT - Created ~/$DIR"
done



# Link the configs
echo -e "$COK - Linking configurations..."
ln -sf $PWD/Dotfiles/kitty/kitty.conf ~/.config/kitty/kitty.conf
ln -sf $PWD/Themes/kitty/gruvbox_dark.conf ~/.config/kitty/theme.conf
ln -sf $PWD/Themes/GTK/Gruvbox/Gruvbox-Dark-BL-LB ~/.themes/Gruvbox-Dark-BL-LB
ln -sf $PWD/Icons/Gruvbox-Dark ~/.icons/Gruvbox-Dark
ln -sf $PWD/Dotfiles/gtk-4.0/settings.ini ~/.config/gtk-4.0/settings.ini && gsettings set org.gnome.desktop.interface gtk-theme "Gruvbox-Dark-BL-LB" && gsettings set org.gnome.desktop.wm.preferences theme "Gruvbox-Dark-BL-LB"
ln -sf $PWD/Dotfiles/hypr/hyprland.conf ~/.config/hypr/hyprland.conf
ln -sf $PWD/Dotfiles/zsh/.zshrc ~/.zshrc
ln -sf $PWD/Dotfiles/zsh/gruvbox.zsh-theme ~/.oh-my-zsh/themes/gruvbox.zsh-theme
ln -sf $PWD/Dotfiles/scripts/aliases ~/.scripts/aliases
ln -sf $PWD/Dotfiles/neofetch/config.conf ~/.config/neofetch/config.conf
ln -sf $PWD/Dotfiles/btop/btop.conf ~/.config/btop/btop.conf
ln -sf $PWD/Themes/btop/gruvbox.theme ~/.config/btop/themes/gruvbox.theme
ln -sf $PWD/Wallpapers/lantern.jpg ~/.config/wallpapers/lantern.jpg
ln -sf $PWD/Themes/helix/gruvbox.toml ~/.config/helix/themes/gruvbox.toml
ln -sf $PWD/Dotfiles/helix/config.toml ~/.config/helix/config.toml
ln -sf $PWD/Dotfiles/helix/languages.toml ~/.config/helix/languages.toml
ln -sf $PWD/Dotfiles/scripts/non-exec/random-hyprpaper.py ~/.scripts/non-exec/random-hyprpaper.py
ln -sf $PWD/Dotfiles/wofi/gruvbox.css ~/.config/wofi/style.css
ln -sf $PWD/Dotfiles/mako ~/.config/mako
ln -sf $PWD/Wallpapers ~/Pictures
ln -sf $PWD/Dotfiles/Steam/steam_dev.cfg ~/.local/share/Steam/steam_dev.cfg

echo -e "$COK - Running post install for helix-editor..."

go install github.com/go-delve/delve/cmd/dlv@latest
go install golang.org/x/tools/gopls@latest


echo -e "$COK - Installation Complete, Rebooting to Hyprland..."
# sudo reboot 0
