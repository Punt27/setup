#!/bin/bash

# ==============================================================================
# ARCH LINUX SYSTEM CRAFTING TOOL - VERSION 2.1
# ==============================================================================

# 1. PFADE & UMGEBUNG
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Lade deine spezifischen Daten aus der packages.conf und die Logik aus utils.sh
if [[ -f "$SCRIPT_DIR/utils.sh" && -f "$SCRIPT_DIR/packages.conf" ]]; then
    source "$SCRIPT_DIR/utils.sh"
    source "$SCRIPT_DIR/packages.conf"
else
    echo "Kritischer Fehler: utils.sh oder packages.conf fehlt!"
    exit 1
fi

# Dynamische Konfiguration
DOTFILES_REPO="git@github.com:Punt27/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# 2. START-SETUP & SICHERHEIT
clear
print_logo # Dein Logo aus der utils.sh

check_internet # Internet-Check aus der utils.sh

log_info "Sudo-Rechte werden vorbereitet..."
sudo -v
# Hält die Sudo-Session im Hintergrund aktiv
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# 3. INTERAKTIVE MODULE

# SMB-Setup (Default: JA)
if [ -f "./setup_smb.sh" ]; then
    echo -n -e "${PURPLE}${BOLD}>>>${NC} SMB-Setup ausführen? [Y/n]: "
    read choice
    if [[ -z $choice || $choice =~ ^[JjYy]$ ]]; then
        log_info "Starte SMB-Modul..."
        chmod +x ./setup_smb.sh
        ./setup_smb.sh
    fi
fi

# Drive-Setup (Default: NEIN)
if [ -f "./setup_drive.sh" ]; then
    echo -n -e "${PURPLE}${BOLD}>>>${NC} Drive-Setup ausführen? [y/N]: "
    read choice
    if [[ $choice =~ ^[JjYy]$ ]]; then
        log_info "Starte Drive-Modul..."
        chmod +x ./setup_drive.sh
        ./setup_drive.sh
    fi
fi

# SSH-Setup (Default: JA)
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo -n -e "${PURPLE}${BOLD}>>>${NC} SSH-Key für GitHub erstellen? [Y/n]: "
    read choice
    if [[ -z $choice || $choice =~ ^[JjYy]$ ]]; then
        chmod +x ./setup_ssh.sh
        ./setup_ssh.sh
    fi
fi

# 4. INSTALLATIONSPROZESS
log_info "System-Update wird durchgeführt..."
sudo pacman -Syu --noconfirm

# Installiert deine Gruppen genau so, wie sie in deiner packages.conf heißen
log_info "Installiere Software-Pakete..."
install_packages "${CORE[@]}"
install_packages "${SYSTEM_UTILS[@]}"
install_packages "${DEV_TOOLS[@]}"
install_packages "${MAINTENANCE[@]}"
install_packages "${DESKTOP[@]}"
install_packages "${OFFICE[@]}"
install_packages "${MEDIA[@]}"
install_packages "${FONTS[@]}"

# AUR Helper (yay) Check
if ! command -v yay &> /dev/null; then
    log_info "Installiere yay..."
    git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay
fi

# 5. ZSH & THEME KONFIGURATION
log_info "Richte Zsh & Powerlevel10k ein..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Plugins & Theme klonen
log_info "Klone Zsh-Erweiterungen..."
git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" --quiet
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" --quiet
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" --quiet

# Shell wechseln
if [[ "$SHELL" != "/usr/bin/zsh" ]]; then
    sudo chsh -s /usr/bin/zsh "$USER"
fi

# 6. DOTFILES (GNU STOW)
log_info "Synchronisiere Dotfiles..."
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
    cd "$DOTFILES_DIR" && git pull && cd "$SCRIPT_DIR"
fi

cd "$DOTFILES_DIR"
# Zsh Config-Backups
for f in ".zshrc" ".p10k.zsh"; do
    [[ -f "$HOME/$f" && ! -L "$HOME/$f" ]] && mv "$HOME/$f" "$HOME/${f}.bak"
done

# Stow-Verknüpfung
for dir in */; do
    target=${dir%/}
    if [[ "$target" != ".git" ]]; then
        log_info "Stowing: $target"
        stow --adopt "$target"
    fi
done

# 7. SERVICES AKTIVIEREN
log_info "Aktiviere System-Dienste..."
for service in "${SERVICES[@]}"; do
    sudo systemctl enable "$service" || true
done

log_success "SETUP ABGESCHLOSSEN! Log: ~/setup_log.txt"
