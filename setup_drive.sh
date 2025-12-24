#!/bin/bash

# --- KONFIGURATION ---
UUID="3da892eb-673b-411b-b5a3-ed746be2fd9a"
MOUNT_POINT="/mnt/Games"
FSTAB_PATH="/etc/fstab"

# 1. Sicherstellen, dass das Script mit sudo ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte starte das Script mit sudo: sudo ./setup_drive.sh"
  exit
fi

echo "Starte Konfiguration für Festplatte $UUID..."

# 2. Mount-Punkt erstellen, falls er nicht existiert
if [ ! -d "$MOUNT_POINT" ]; then
  echo "Erstelle Mount-Punkt $MOUNT_POINT..."
  mkdir -p "$MOUNT_POINT"
fi

# 3. Dateisystem-Typ automatisch erkennen
# Wir suchen den Typ (FSTYPE) basierend auf der UUID
FS_TYPE=$(blkid -s TYPE -o value UUID="$UUID")

if [ -z "$FS_TYPE" ]; then
  echo "FEHLER: Festplatte mit UUID $UUID wurde nicht gefunden!"
  echo "Ist die Platte angeschlossen?"
  exit 1
fi

echo "Erkanntes Dateisystem: $FS_TYPE"

# 4. Prüfen, ob die UUID bereits in der fstab steht
if grep -q "$UUID" "$FSTAB_PATH"; then
  echo "Hinweis: UUID ist bereits in $FSTAB_PATH vorhanden. Überspringe Eintrag."
else
  # Backup der fstab erstellen
  cp "$FSTAB_PATH" "${FSTAB_PATH}.bak_$(date +%F_%H-%M-%S)"

  # Eintrag hinzufügen
  echo "Füge Eintrag zu $FSTAB_PATH hinzu..."
  echo "UUID=$UUID  $MOUNT_POINT  $FS_TYPE  defaults,nofail  0  2" >> "$FSTAB_PATH"
fi

# 5. Alles mounten
echo "Mounte alle Partitionen..."
mount -a

# 6. Berechtigungen anpassen (für den aktuellen User, der sudo aufgerufen hat)
# Wir nutzen die Variable $SUDO_USER, um den echten User zu finden
if [ -n "$SUDO_USER" ]; then
  echo "Passe Berechtigungen für Benutzer $SUDO_USER an..."
  chown -R "$SUDO_USER":"$SUDO_USER" "$MOUNT_POINT"
fi

echo "Fertig! Deine Festplatte ist unter $MOUNT_POINT einsatzbereit."
