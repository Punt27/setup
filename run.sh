#!/bin/bash

# --- KONFIGURATION ---
# Ersetze DEIN_NUTZERNAME durch deinen echten GitHub-Namen!
DOTFILES_REPO="git@github.com:DEIN_NUTZERNAME/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# Logo ausgeben
print_logo() {
    cat << "EOF"

$$$$$$$\                        $$\      $$$$$$\  $$$$$$$$\
$$  __$$\                       $$ |    $$  __$$\ \____$$  |
$$ |  $$ |$$\   $$\ $$$$$$$\ $$$$$$\    \__/  $$ |    $$  /
$$$$$$$  |$$ |  $$ |$$  __$$\\_$$  _|    $$$$$$  |   $$  /
$$  ____/ $$ |  $$ |$$ |  $$ | $$ |     $$  ____/   $$  /
$$ |      $$ |  $$ |$$ |  $$ | $$ |$$\ $$ |       $$  /
$$ |      \$$$$$$  |$$ |  $$ | \$$$$  |$$$$$$$$\ $$  /      Arch Linux System Crafting Tool
\__|       \______/ \__|  \__|  \____/ \________|\__/       von: Punt27


EOF
}

# Befehlszeilenargumente parsen
DEV_ONLY=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --dev-only) DEV_ONLY=true; shift ;;
    *) echo "Unbekannter Parameter: $1"; exit 1 ;;
  esac
done

clear
print_logo

# --- 1. SMB-SETUP (Automatisch) ---
if [ -f "./setup_smb.sh" ]; then
  echo ">>> Starte SMB-Setup..."
  chmod +x ./setup_smb.sh
  ./setup_smb.sh
fi

# --- 2. DRIVE-SETUP (Optional) ---
if [ -f "./setup_drive.sh" ]; then
  echo ""
  read -p "Möchtest du das Drive-Setup (Laufwerke) ausführen? (j/n): " choice
  case "$choice" in 
    j|J|y|Y ) chmod +x ./setup_drive.sh; ./setup_drive.sh ;;
    * ) echo ">>> Drive-Setup übersprungen." ;;
  esac
fi

# Ab hier bei Fehlern abbrechen
set -e

# Hilfsdateien prüfen
if [ ! -f "packages.conf" ] || [ ! -f "utils.sh" ]; then
    echo "Fehler: packages.conf oder utils.sh fehlt!"
    exit 1
fi
source utils.sh
source packages.conf

# --- 3. SYSTEM BASIS & SSH ---
echo ">>> Aktualisiere System und installiere Basis-Tools..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed git base-devel stow zsh xclip --noconfirm

# SSH-Key Abfrage für privates Repo
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  echo ""
  read -p "Kein SSH-Key gefunden. Jetzt einen für GitHub erstellen? (j/n): " ssh_ask
  if [[ "$ssh_ask" =~ ^[JjYy]$ ]]; then
    chmod +x ./setup_ssh.sh
    ./setup_ssh.sh
  fi
fi

# AUR Helper (yay)
if ! command -v yay &> /dev/null; then
  echo ">>> Installiere yay..."
  git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay
fi

# --- 4. OH MY ZSH, PLUGINS & POWERLEVEL10K ---
echo ">>> Richte Zsh-Umgebung ein..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Plugins & Theme klonen
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

# Shell wechseln
[ "$SHELL" != "/usr/bin/zsh" ] && sudo chsh -s /usr/bin/zsh $USER

# --- 5. PAKET-INSTALLATION ---
if [[ "$DEV_ONLY" == true ]]; then
  echo ">>> Installiere Entwickler-Setup..."
  install_packages "${SYSTEM_UTILS[@]}" "${DEV_TOOLS[@]}"
else
  echo ">>> Installiere vollständiges System..."
  install_packages "${SYSTEM_UTILS[@]}" "${DEV_TOOLS[@]}" "${MAINTENANCE[@]}" "${DESKTOP[@]}" "${OFFICE[@]}" "${MEDIA[@]}" "${FONTS[@]}"
  
  for service in "${SERVICES[@]}"; do
    sudo systemctl enable "$service" || true
  done
  [ -f "install-flatpaks.sh" ] && source install-flatpaks.sh
fi

# --- 6. DOTFILES MIT STOW ---
echo "-----------------------------------------------------"
echo ">>> Klone und verlinke Dotfiles..."
if [ ! -d "$DOTFILES_DIR" ]; then
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  cd "$DOTFILES_DIR" && git pull && cd -
fi

cd "$DOTFILES_DIR"
# Backups für Stow-Konflikte
for file in ".zshrc" ".p10k.zsh"; do
    [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ] && mv "$HOME/$file" "$HOME/${file}.bak"
done

# Alle Ordner "stowen"
for dir in */; do
    target=${dir%/}
    if [ "$target" != ".git" ]; then
        echo "Verknüpfe: $target"
        stow "$target"
    fi
done

echo "-----------------------------------------------------"
echo "SETUP ABGESCHLOSSEN!"
echo "1. Starte das Terminal neu."
echo "2. Stelle sicher, dass eine Nerd Font aktiv ist."
echo "3. Falls p10k nicht automatisch startet, gib 'p10k configure' ein."
