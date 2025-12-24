#!/bin/bash

# Script-Verzeichnis ermitteln
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- FARBEN ---
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Konfiguration (Bitte anpassen!)
DOTFILES_REPO="git@github.com:Punt27/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

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

# 1. Start-Checks
clear
print_logo

if [[ $EUID -eq 0 ]]; then
   echo "Bitte starte dieses Skript NICHT als root/sudo. Es wird nach Passwörtern fragen, wenn nötig."
   exit 1
fi

# 2. SMB & DRIVE MODULE (Optional/Interaktiv)
if [ -f "./setup_smb.sh" ]; then
    read -p "SMB-Setup ausführen? (j/n): " smb_c
    [[ "$smb_c" =~ ^[JjYy]$ ]] && chmod +x ./setup_smb.sh && ./setup_smb.sh
fi

if [ -f "./setup_drive.sh" ]; then
    read -p "Laufwerke (Drive) konfigurieren? (j/n): " drive_c
    [[ "$drive_c" =~ ^[JjYy]$ ]] && chmod +x ./setup_drive.sh && ./setup_drive.sh
fi

set -e
source utils.sh
source packages.conf

# 3. BASIS INSTALLATION
echo -e "\n${CYAN}>>> System-Update und Basis-Installation...${NC}"
sudo pacman -Syu --noconfirm
sudo pacman -S --needed git base-devel stow zsh xclip curl --noconfirm

# SSH Check/Setup
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    chmod +x ./setup_ssh.sh
    ./setup_ssh.sh
fi

# AUR Helper
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay
fi

# 4. ZSH & THEME SETUP
echo -e "${CYAN}>>> Richte Oh-My-Zsh & Powerlevel10k ein...${NC}"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
# Plugins & Theme klonen falls nicht vorhanden
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

# 5. PAKETE INSTALLIEREN
echo -e "${CYAN}>>> Installiere Paketgruppen aus packages.conf...${NC}"
install_packages "${SYSTEM_UTILS[@]}" "${DEV_TOOLS[@]}" "${MAINTENANCE[@]}"
# ... hier weitere Gruppen hinzufügen ...

# 6. DOTFILES (Der krönende Abschluss)
echo -e "\n${PURPLE}>>> Verknüpfe Dotfiles mit Stow...${NC}"
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"
# Verhindere Stow-Konflikte durch automatische Backups
for dir in */; do
    target=${dir%/}
    if [ "$target" != ".git" ]; then
        echo "Stowing $target..."
        stow --adopt "$target" # --adopt integriert bestehende Configs ins Repo oder überschreibt sie
    fi
done

echo -e "\n${GREEN}Fertig! Bitte starte deine Shell neu (zsh).${NC}"
