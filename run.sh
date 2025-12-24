#!/bin/bash

# --- KONFIGURATION FÜR DOTFILES ---
# Bitte hier deine GitHub-URL und den Zielordner anpassen
DOTFILES_REPO="https://github.com/DEIN_NUTZERNAME/dotfiles.git"
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

# --- 1. AKTION: SMB-SETUP ---
if [ -f "./setup_smb.sh" ]; then
  echo ">>> Starte SMB-Setup..."
  chmod +x ./setup_smb.sh
  ./setup_smb.sh
else
  echo "Hinweis: setup_smb.sh wurde nicht gefunden."
fi

# --- 2. AKTION: DRIVE-SETUP ---
if [ -f "./setup_drive.sh" ]; then
  echo ">>> Starte Drive-Setup (Laufwerke)..."
  chmod +x ./setup_drive.sh
  ./setup_drive.sh
else
  echo "Hinweis: setup_drive.sh wurde nicht gefunden."
fi

# Ab hier bei Fehlern abbrechen
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
  echo "Modus: Reines Entwicklungs-Setup"
else
  echo "Modus: Vollständiges System-Setup"
fi

# System aktualisieren
echo "Aktualisiere System-Datenbanken..."
sudo pacman -Syu --noconfirm

# Grundlegende Tools installieren (inkl. stow für später)
echo "Installiere Basis-Tools (git, stow, base-devel)..."
sudo pacman -S --needed git base-devel stow --noconfirm

# Installiere yay (AUR Helper), falls nicht vorhanden
if ! command -v yay &> /dev/null; then
  echo "Installiere yay AUR Helper..."
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd ..
  rm -rf yay
fi

# Installation der Pakete nach Kategorien
if [[ "$DEV_ONLY" == true ]]; then
  echo "Installiere System-Utilities & Dev-Tools..."
  install_packages "${SYSTEM_UTILS[@]}"
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

# --- 3. AKTION: DOTFILES MIT STOW ---
echo "------------------------------------------"
echo "Einrichtung der Dotfiles..."

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Klone Dotfiles von: $DOTFILES_REPO"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  echo "Dotfiles-Ordner bereits vorhanden. Ziehe Updates..."
  cd "$DOTFILES_DIR" && git pull && cd -
fi

cd "$DOTFILES_DIR"
echo "Verknüpfe Konfigurationen mit GNU Stow..."

# Gehe durch alle Top-Level Verzeichnisse im Dotfiles-Ordner
for dir in */; do
    target=${dir%/}
    # Ignoriere den .git Ordner
    if [ "$target" != ".git" ]; then
        echo "Stowing: $target"
        # --adopt überschreibt lokale Dateien mit den Links aus dem Repo 
        # (Vorsicht: Falls du lokale Änderungen hast, die nicht im Repo sind!)
        stow "$target"
    fi
done

cd ~
echo "------------------------------------------"
echo "Setup erfolgreich abgeschlossen!"
echo "Tipp: Starte dein System neu, um alle Änderungen zu übernehmen."
