#!/bin/bash

# --- FARBEN ---
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m'
export BOLD='\033[1m'

# --- LOGGING ---
LOG_FILE="$HOME/setup_log.txt"

log_info()    { echo -e "${CYAN}[INFO]${NC} $1"; echo "[$(date +'%T')] INFO: $1" >> "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; echo "[$(date +'%T')] SUCCESS: $1" >> "$LOG_FILE"; }
log_error()   { echo -e "${RED}[FEHLER]${NC} $1"; echo "[$(date +'%T')] ERROR: $1" >> "$LOG_FILE"; }

# --- LOGO FUNKTION ---
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

# --- INTERNET CHECK ---
check_internet() {
    log_info "Prüfe Internetverbindung..."
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        log_error "Keine Internetverbindung! Bitte prüfe dein Netzwerk."
        exit 1
    fi
}

# --- PAKET INSTALLATION ---
install_packages() {
    local pkgs=("$@")
    for pkg in "${pkgs[@]}"; do
        if pacman -Qi "$pkg" &> /dev/null; then
            log_success "$pkg ist bereits installiert."
        else
            log_info "Installiere $pkg..."
            # Versuche Pacman, falls fehlgeschlagen versuche Yay
            if sudo pacman -S --noconfirm --needed "$pkg" &>> "$LOG_FILE"; then
                log_success "$pkg erfolgreich installiert."
            else
                log_info "Nicht in Repos gefunden. Versuche AUR (yay) für $pkg..."
                if yay -S --noconfirm --needed "$pkg" &>> "$LOG_FILE"; then
                    log_success "$pkg via AUR installiert."
                else
                    log_error "Konnte $pkg nicht installieren!"
                fi
            fi
        fi
    done
}
