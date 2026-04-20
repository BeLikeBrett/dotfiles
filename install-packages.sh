#!/usr/bin/env bash
#
# install-packages.sh — fresh-machine bootstrap for Brett's setup.
#
# Usage:  bash install-packages.sh
#
# Assumes: Arch-based system (CachyOS works) with `paru` already installed.
# If paru is missing on a new box, bootstrap it first:
#   sudo pacman -S --needed base-devel git
#   git clone https://aur.archlinux.org/paru.git /tmp/paru && cd /tmp/paru && makepkg -si
#
# `set -e` makes the script exit on the first error — you wanted to KNOW when
# something breaks instead of having it silently skipped, so this is correct.
set -e

# `paru -S --needed` installs packages from the official repos AND the AUR.
# --needed skips anything already installed, so re-running this script is safe.
# The `--` separates options from the package list (not strictly needed here,
# just good habit).

paru -S --needed -- \
    `# --- Niri compositor + shell ---` \
    niri \
    noctalia-shell \
    noctalia-qs \
    nirimod-git \
    xwayland-satellite \
    waybar \
    fuzzel \
    swaybg \
    \
    `# --- Terminals ---` \
    alacritty \
    kitty \
    \
    `# --- Shells + completions ---` \
    fish \
    bash-completion \
    blesh \
    \
    `# --- Login manager + auth prompts ---` \
    sddm \
    polkit-gnome \
    \
    `# --- Desktop portals (file pickers, screen share, etc.) ---` \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    \
    `# --- Audio stack (pipewire + jack/alsa/pulse shims) ---` \
    pipewire-alsa \
    pipewire-audio \
    pipewire-jack \
    pipewire-pulse \
    pipewire-v4l2 \
    wireplumber \
    pavucontrol \
    \
    `# --- Network (NetworkManager + iwd backend) ---` \
    networkmanager-iwd \
    iwd \
    nm-connection-editor \
    \
    `# --- Tools bound to niri hotkeys ---` \
    brightnessctl \
    wlsunset \
    cliphist \
    libnotify \
    \
    `# --- Qt theming (Noctalia is a Qt shell) ---` \
    qt5-graphicaleffects \
    qt5-quickcontrols2 \
    qt6ct \
    \
    `# --- GTK theming + icons ---` \
    papirus-icon-theme \
    adw-gtk-theme \
    adwaita-dark \
    nwg-look \
    \
    `# --- Fonts ---` \
    noto-fonts \
    ttf-dejavu \
    ttf-liberation \
    terminus-font \
    ttf-input-nerd \
    \
    `# --- File manager + basic editors ---` \
    nautilus \
    nano \
    gnome-text-editor \
    \
    `# --- System utilities ---` \
    dmemcg-booster \
    flatpak \
    \
    `# --- Gaming ---` \
    steam \
    gamemode \
    protontricks \
    mangohud \
    mangojuice \
    keyresolve-git \
    \
    `# --- Media playback + recording ---` \
    mpv \
    vlc \
    imv \
    obs-studio \
    gpu-screen-recorder \
    \
    `# --- CLI tools you use daily ---` \
    bat \
    fd \
    fzf \
    jq \
    htop \
    fastfetch \
    fsearch \
    wget \
    unzip \
    zip \
    \
    `# --- Apps ---` \
    discord \
    spotify \
    spicetify-cli \
    qbittorrent

echo ""
echo "Packages installed."
echo ""
echo "Post-install reminders (these aren't automated — do them yourself):"
echo "  * sudo systemctl enable --now sddm"
echo "  * sudo systemctl enable --now NetworkManager"
echo "  * Run 'spicetify' once, then 'sudo chmod a+wr /opt/spotify' + spotify dirs"
echo "  * Log in, pick niri at the SDDM session selector"
