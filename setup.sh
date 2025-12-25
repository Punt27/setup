#!/bin/bash

# ==============================================================================
# ARCH LINUX SYSTEM CRAFTING TOOL - VERSION 2.0
# Developed by: Punt27
# ==============================================================================

# 1. PFADE & UMGEBUNG INITIALISIEREN
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Hilfsfunktionen und Paketlisten laden
if [[ -f "$SCRIPT_DIR/utils.sh" && -f "$SCRIPT_DIR/packages.conf" ]]; then
    source "$SCRIPT_DIR/utils.sh"
    source "$SCRIPT_DIR/packages.conf"
else
    echo "Fehler: utils.sh oder packages.conf nicht im Verzeichnis gefunden!"
    exit 1
fi

# Konfiguration
DOTFILES_REPO="git@github.com:Punt27/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# 2. LOGO & START-CHECKS
clear
print_logo  # Nutzt dein originales Logo aus der utils.sh/setup.sh

check_internet  # Prüft, ob Verbindung besteht (aus utils.sh)

# Sudo-Validierung: Einmal Passwort abfragen und im Hintergrund aktiv halten
log_info "Sudo-Rechte werden für die Installation benötigt..."
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# 3. OPTIONALE MODULE (Interaktive Abfragen)

# SMB-Setup (Default: JA)
if [ -f "./setup_smb.sh" ]; then
    echo -n -e "${PURPLE}${BOLD}>>>${NC} Möchtest du das SMB-Setup ausführen? [Y/n]: "
    read choice
    if [[ -z $choice || $choice =~ ^[JjYy]$ ]]; then
        log_info "Starte SMB-Modul..."
        chmod +x ./setup_smb.sh
        ./setup_smb.sh
    fi
fi

# Drive-Setup (Default: NEIN)
if [ -f "./setup_drive.sh" ]; then
    echo -n -e "${PURPLE}${BOLD}>>>${NC} Möchtest du das Drive-Setup ausführen? [y/N]: "
    read choice
    if [[ $choice =~ ^[JjYy]$ ]]; then
        log_info "Starte Drive-Modul..."
        chmod +x ./setup_drive.sh
        ./setup_drive.sh
    fi
fi

# SSH-Setup (Default: JA - falls kein Key existiert)
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo -n -e "${PURPLE}${BOLD}>>>${NC} Kein SSH-Key gefunden. Jetzt für GitHub erstellen? [Y/n]: "
    read choice
    if [[ -z $choice || $choice =~ ^[JjYy]$ ]]; then
        chmod +x ./setup_ssh.sh
        ./setup_ssh.sh
    fi
fi

# Ab hier bei kritischen Fehlern abbrechen
set -e

# 4. BASIS INSTALLATION (CORE)
log_info "Aktualisiere Systemdatenbanken..."
sudo pacman -Syu --noconfirm

log_info "Installiere Basis-Werkzeuge..."
# CORE Pakete: git, base-devel, stow, zsh, xclip, curl, nerd-fonts
install_packages "${CORE[@]}"

# AUR Helper (yay) installieren falls nicht vorhanden
if ! command -v yay &> /dev/null; then
    log_info "Installiere yay (AUR Helper)..."
    git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay
fi

# 5. SOFTWARE-GRUPPEN INSTALLIEREN
log_info "Installiere Software-Pakete aus packages.conf..."
install_packages "${SYSTEM_UTILS[@]}"
install_packages "${DEV_TOOLS[@]}"
install_packages "${MAINTENANCE[@]}"
install_packages "${DESKTOP[@]}"
install_packages "${MEDIA[@]}"

# 6. ZSH, OH-MY-ZSH & POWERLEVEL10K
log_info "Konfiguriere Zsh-Umgebung..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Plugins und Theme klonen
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

# Standard-Shell auf Zsh umstellen
if [[ "$SHELL" != "/usr/bin/zsh" ]]; then
    log_info "Ändere Standard-Shell auf Zsh..."
    sudo chsh -s /usr/bin/zsh "$USER"
fi

# 7. DOTFILES MIT STOW VERKNÜPFEN
log_info "Lade Dotfiles von GitHub..."
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
    log_info "Dotfiles bereits vorhanden, ziehe Updates..."
    cd "$DOTFILES_DIR" && git pull && cd "$SCRIPT_DIR"
fi

log_info "Verlinke Konfigurationen mit GNU Stow..."
cd "$DOTFILES_DIR"

# Zsh-Standarddateien sichern, falls sie existieren und keine Symlinks sind
for file in ".zshrc" ".p10k.zsh"; do
    if [[ -f "$HOME/$file" && ! -L "$HOME/$file" ]]; then
        mv "$HOME/$file" "$HOME/${file}.bak"
        log_info "Backup erstellt: $file -> ${file}.bak"
    fi
done

# Alle Unterordner stowen
for dir in */; do
    target=${dir%/}
    if [[ "$target" != ".git" ]]; then
        log_info "Stowing: $target"
        stow --adopt "$target"
    fi
done

# 8. ABSCHLUSS
log_success "SYSTEM-SETUP ABGESCHLOSSEN!"
log_info "Eine Log-Datei wurde unter ~/setup_log.txt erstellt."
echo -e "\n${YELLOW}HINWEIS: Bitte starte deinen Computer oder das Terminal neu.${NC}"
