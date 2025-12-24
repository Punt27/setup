#!/bin/bash

# --- KONFIGURATION ---
DOTFILES_REPO="https://github.com/DEIN_NUTZERNAME/dotfiles.git"
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

# --- 1. SMB-SETUP ---
if [ -f "./setup_smb.sh" ]; then
  echo ">>> Starte SMB-Setup..."
  chmod +x ./setup_smb.sh
  ./setup_smb.sh
fi

# --- 2. OPTIONALES DRIVE-SETUP ---
if [ -f "./setup_drive.sh" ]; then
  echo ""
  read -p "Möchtest du das Drive-Setup (Laufwerke) ausführen? (j/n): " choice
  case "$choice" in 
    j|J|y|Y ) chmod +x ./setup_drive.sh; ./setup_drive.sh ;;
    * ) echo ">>> Drive-Setup übersprungen." ;;
  esac
fi

set -e
source utils.sh
source packages.conf

# System Update & Basis-Tools
echo ">>> Bereite System vor..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed git base-devel stow zsh --noconfirm

# Installiere yay
if ! command -v yay &> /dev/null; then
  echo ">>> Installiere yay..."
  git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay
fi

# --- 3. OH MY ZSH, PLUGINS & POWERLEVEL10K ---
echo ">>> Richte Oh My Zsh Framework ein..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo ">>> Installiere Zsh-Plugins und Powerlevel10k..."
# Plugins
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# Powerlevel10k Theme
[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

# Standard-Shell auf Zsh ändern
if [ "$SHELL" != "/usr/bin/zsh" ]; then
  echo ">>> Ändere Standard-Shell auf Zsh..."
  sudo chsh -s /usr/bin/zsh $USER
fi

# --- 4. PAKET INSTALLATION ---
if [[ "$DEV_ONLY" == true ]]; then
  install_packages "${SYSTEM_UTILS[@]}" "${DEV_TOOLS[@]}"
else
  install_packages "${SYSTEM_UTILS[@]}" "${DEV_TOOLS[@]}" "${MAINTENANCE[@]}" "${DESKTOP[@]}" "${OFFICE[@]}" "${MEDIA[@]}" "${FONTS[@]}"
  for service in "${SERVICES[@]}"; do
    sudo systemctl enable "$service" || true
  done
  [ -f "install-flatpaks.sh" ] && source install-flatpaks.sh
fi

# --- 5. DOTFILES MIT STOW ---
echo "------------------------------------------"
echo ">>> Verknüpfe Dotfiles mit Stow..."
if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Klone Dotfiles..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"

# Backup von Standard-Configs, damit Stow linken kann
# Wir sichern .zshrc und .p10k.zsh falls sie als echte Dateien existieren
for file in ".zshrc" ".p10k.zsh"; do
    if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
        echo "Sichere existierende $file nach $file.bak"
        mv "$HOME/$file" "$HOME/$file.bak"
    fi
done

# Stow ausführen für alle Ordner
for dir in */; do
    target=${dir%/}
    if [ "$target" != ".git" ]; then
        echo "Stowing: $target"
        stow "$target"
    fi
done

cd ~
echo "------------------------------------------"
echo "Setup abgeschlossen! Alles bereit."
echo "WICHTIG: Stelle sicher, dass eine 'Nerd Font' in deinem Terminal aktiv ist!"
echo "Nach dem Neustart des Terminals startet ggf. der p10k-Konfigurator."
