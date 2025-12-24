#!/bin/bash

# Farbiges Logging
INFO='\033[0;36m'
SUCCESS='\033[0;32m'
WARN='\033[1;33m'
NC='\033[0m'

install_packages() {
    local pkgs=("$@")
    echo -e "${INFO}Überprüfe und installiere Pakete: ${pkgs[*]}${NC}"
    
    for pkg in "${pkgs[@]}"; do
        if pacman -Qi "$pkg" &> /dev/null; then
            echo -e "  [${SUCCESS}OK${NC}] $pkg ist bereits installiert."
        else
            echo -e "  [${INFO}..${NC}] Installiere $pkg..."
            if sudo pacman -S --noconfirm --needed "$pkg"; then
                echo -e "  [${SUCCESS}OK${NC}] $pkg erfolgreich installiert."
            else
                # Falls pacman fehlschlägt, versuche es über yay
                if command -v yay &> /dev/null; then
                    echo -e "  [${INFO}AUR${NC}] Versuche $pkg über AUR zu installieren..."
                    yay -S --noconfirm --needed "$pkg" || echo -e "  [${WARN}WARN${NC}] Konnte $pkg nicht installieren."
                else
                    echo -e "  [${WARN}WARN${NC}] Konnte $pkg nicht finden."
                fi
            fi
        fi
    done
}
