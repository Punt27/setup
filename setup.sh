#!/bin/bash

# --- FARBEN ---
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# --- KONFIGURATION ---
# Ersetze DEIN_NUTZERNAME durch deinen echten GitHub-Namen
DOTFILES_REPO="git@github.com:Punt27/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# Logo ausgeben
print_logo() {
    echo -e "${BLUE}${BOLD}"
    cat << "EOF"
$$$$$$$\                        $$\      $$$$$$\  $$$$$$$$\
$$  __$$\                       $$ |    $$  __$$\ \____$$  |
$$ |  $$ |$$\   $$\ $$$$$$$\ $$$$$$\    \__/  $$ |    $$  /
$$$$$$$  |$$ |  $$ |$$  __$$\\_$$  _|    $$$$$$  |   $$  /
$$  ____/ $$ |  $$ |$$ |  $$ | $$ |     $$  ____/   $$  /
$$ |      $$ |  $$ |$$ |  $$ | $$ |$$\ $$ |       $$  /
$$ |      \$$$$$$  |$$ |  $$ | \$$$$  |$$$$$$$$\ $$  /      Arch Linux System Crafting Tool
\__|       \______/ \__|  \__|  \____/ \________|\__/       by: Punt27
EOF
    echo -e "${NC}"
}

# Skript-Verzeichnis festlegen
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

clear
print_logo

# --- 1. SMB-SETUP (Default: Y) ---
if [ -f "./setup_smb.sh" ]; then
    echo -n -e "${PURPLE}Möchtest du das SMB-Setup ausführen? [Y/n]: ${NC}"
    read choice
    if [[ -z $choice || $choice =~ ^[JjYy]$ ]]; then
        chmod +x ./setup_smb.sh
        ./setup_smb.sh
    fi
fi

# --- 2. DRIVE-SETUP (Default: N) ---
if [ -f "./setup_drive.sh" ]; then
    echo -n -e "${PURPLE}Möchtest du das Drive-Setup (Laufwerke) ausführen? [y/N]: ${NC}"
    read choice
    if [[ $choice =~ ^[JjYy]$ ]]; then
        chmod +x ./setup_drive.sh
        ./setup_drive.sh
    fi
fi

set -e # Ab hier Abbruch bei Fehlern
source utils.sh
source packages.conf

# --- 3. BASIS INSTALLATION & SSH ---
echo -e "\n${CYAN}>>> Bereite System vor...${NC}"
sudo pacman -Syu --noconfirm
sudo pacman -S --needed git base-devel stow zsh xclip curl --noconfirm

# SSH-Key Abfrage (Default: Y)
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo -n -e "${PURPLE}Kein SSH-Key gefunden. Jetzt einen für GitHub erstellen? [Y/n]: ${NC}"
    read choice
    if [[ -z $choice || $choice =~ ^[JjYy]$ ]]; then
        chmod +x ./setup_ssh.sh
        ./setup_ssh.sh
    fi
fi

# AUR Helper
if ! command -v yay &> /dev/null; then
    echo -e "${CYAN}>>> Installiere yay...${NC}"
    git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay
fi

# --- 4. ZSH & POWERLEVEL10K ---
echo -e "${CYAN}>>> Richte Oh-My-Zsh & Powerlevel10k ein...${NC}"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

[ "$SHELL" != "/usr/bin/zsh" ] && sudo chsh -s /usr/bin/zsh $USER

# --- 5. PAKET INSTALLATION ---
echo -e "${CYAN}>>> Installiere Software-Pakete...${NC}"
install_packages "${SYSTEM_UTILS[@]}" "${DEV_TOOLS[@]}" "${MAINTENANCE[@]}" "${FONTS[@]}"
# Dienste aktivieren
for service in "${SERVICES[@]}"; do
    sudo systemctl enable "$service" || true
done

# --- 6. DOTFILES (STOW) ---
echo -e "\n${PURPLE}>>> Verknüpfe Dotfiles via SSH...${NC}"
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"
# Backups für Zsh-Dateien, damit Stow nicht blockiert
for file in ".zshrc" ".p10k.zsh"; do
    [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ] && mv "$HOME/$file" "$HOME/${file}.bak"
done

# Alle Ordner im Dotfiles-Verzeichnis stowen
for dir in */; do
    target=${dir%/}
    if [ "$target" != ".git" ]; then
        stow "$target"
    fi
done

echo -e "\n${GREEN}>>> SETUP ERFOLGREICH BEENDET!${NC}"
echo
