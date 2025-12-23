#!/bin/bash

# --- KONFIGURATION FÜR DOTFILES ---
DOTFILES_REPO="https://github.com/Punt27/dotfiles.git" # Ersetze dies durch deine URL
DOTFILES_DIR="$HOME/dotfiles"

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

# Bildschirm leeren und Logo zeigen
clear
print_logo

# --- SMB-SETUP ---
if [ -f "./setup_smb.sh" ]; then
  echo "Starte SMB-Setup..."
  chmod +x ./setup_smb.sh
  ./setup_smb.sh
else
  echo "Hinweis: setup_smb.sh wurde nicht gefunden, überspringe diesen Schritt."
fi

# Bei Fehlern abbrechen
set -e

# Hilfsfunktionen laden
source utils.sh

# Paketliste laden
if [ ! -f "packages.conf" ]; then
  echo "Fehler: packages.conf nicht gefunden!"
  exit 1
fi

source packages.conf

if [[ "$DEV_ONLY" == true ]]; then
  echo "Starte reines Entwicklungs-Setup..."
else
  echo "Starte vollständiges System-Setup..."
fi

# System zuerst aktualisieren
echo "Aktualisiere System..."
sudo pacman -Syu --noconfirm

# Installiere yay (AUR Helper), falls nicht vorhanden
if ! command -v yay &> /dev/null; then
  echo "Installiere yay AUR Helper..."
  sudo pacman -S --needed git base-devel --noconfirm
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd ..
  rm -rf yay
fi

# Installation der Pakete nach Kategorien
# (Zusätzlich stow installieren, falls nicht in packages.conf)
sudo pacman -S --needed stow --noconfirm

if [[ "$DEV_ONLY" == true ]]; then
  echo "Installiere System-Utilities..."
  install_packages "${SYSTEM_UTILS[@]}"
  echo "Installiere Entwicklungswerkzeuge..."
  install_packages "${DEV_TOOLS[@]}"
else
  echo "Installiere alle Paketgruppen..."
  install_packages "${SYSTEM_UTILS[@]}" "${DEV_TOOLS[@]}" "${MAINTENANCE[@]}" "${DESKTOP[@]}" "${OFFICE[@]}" "${MEDIA[@]}" "${FONTS[@]}"
  
  # Dienste aktivieren
  echo "Konfiguriere Dienste..."
  for service in "${SERVICES[@]}"; do
    if ! systemctl is-enabled "$service" &> /dev/null; then
      echo "Aktiviere $service..."
      sudo systemctl enable "$service"
    fi
  done

  # Flatpaks
  if [ -f "install-flatpaks.sh" ]; then
    echo "Installiere Flatpaks..."
    source install-flatpaks.sh
  fi
fi

# --- DOTFILES MIT STOW ---
echo "------------------------------------------"
echo "Starte Dotfiles-Einrichtung..."

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Klone Dotfiles von GitHub..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  echo "Dotfiles-Ordner existiert bereits. Überspringe Klonen."
fi

cd "$DOTFILES_DIR"
echo "Wende Stow an..."

# Hier werden alle Unterordner in ~/dotfiles per Symlink in dein Home-Verzeichnis verknüpft
# Beispiel: ~/dotfiles/nvim/ wird zu ~/.config/nvim/
for dir in */; do
    # Entferne den Slash am Ende für den stow Befehl
    target=${dir%/}
    echo "Verknüpfe Konfiguration für: $target"
    stow "$target"
done

cd ~
echo "------------------------------------------"
echo "Setup abgeschlossen! Bitte starte dein System neu."
