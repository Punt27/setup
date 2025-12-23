#!/bin/bash

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

# --- Ausführung der setup_smb.sh ---
if [ -f "./setup_smb.sh" ]; then
  echo "Starte SMB-Setup..."
  chmod +x ./setup_smb.sh
  ./setup_smb.sh
else
  echo "Hinweis: setup_smb.sh wurde nicht gefunden, überspringe diesen Schritt."
fi
# ----------------------------------------

# Bei Fehlern abbrechen
set -e

# Hilfsfunktionen laden
if [ -f "utils.sh" ]; then
  source utils.sh
else
  echo "Fehler: utils.sh nicht gefunden!"
  exit 1
fi

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
  if [[ ! -d "yay" ]]; then
    echo "Klone yay Repository..."
  else
    echo "yay Verzeichnis existiert bereits, es wird entfernt..."
    rm -rf yay
  fi

  git clone https://aur.archlinux.org/yay.git
  cd yay
  echo "Kompiliere yay... gleich fertig!"
  makepkg -si --noconfirm
  cd ..
  rm -rf yay
else
  echo "yay ist bereits installiert."
fi

# Installation der Pakete nach Kategorien
if [[ "$DEV_ONLY" == true ]]; then
  # Nur essenzielle Entwicklungspakete installieren
  echo "Installiere System-Utilities..."
  install_packages "${SYSTEM_UTILS[@]}"
  
  echo "Installiere Entwicklungswerkzeuge..."
  install_packages "${DEV_TOOLS[@]}"
else
  # Alle Pakete installieren
  echo "Installiere System-Utilities..."
  install_packages "${SYSTEM_UTILS[@]}"
  
  echo "Installiere Entwicklungswerkzeuge..."
  install_packages "${DEV_TOOLS[@]}"
  
  echo "Installiere Wartungs-Tools..."
  install_packages "${MAINTENANCE[@]}"
  
  echo "Installiere Desktop-Umgebung..."
  install_packages "${DESKTOP[@]}"
  
  echo "Installiere Office-Pakete..."
  install_packages "${OFFICE[@]}"
  
  echo "Installiere Multimedia-Pakete..."
  install_packages "${MEDIA[@]}"
  
  echo "Installiere Schriftarten..."
  install_packages "${FONTS[@]}"
  
  # Dienste aktivieren
  echo "Konfiguriere Dienste..."
  for service in "${SERVICES[@]}"; do
    if ! systemctl is-enabled "$service" &> /dev/null; then
      echo "Aktiviere $service..."
      sudo systemctl enable "$service"
    else
      echo "$service ist bereits aktiviert."
    fi
  done

  # Flatpaks installieren (z.B. Discord/Spotify)
  if [ -f "install-flatpaks.sh" ]; then
    echo "Installiere Flatpaks (wie Discord und Spotify)..."
    source install-flatpaks.sh
  fi
fi

echo "Setup abgeschlossen! Bitte starte dein System neu."
