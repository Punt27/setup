#!/bin/bash

# --- KONFIGURATION ---
USER_NAME="Yannick"
SMB_CRED_FILE="/root/.smbServer"

# Hier kannst du beliebig viele Verzeichnisse hinzufügen.
# Format: "Netzwerk-Pfad Lokal-Mount-Punkt"
SHARES=(
    "//192.168.178.6/home /mnt/NAS"
    "//192.168.178.6/RAW\040Bilder /mnt/RAW"
    "//192.168.178.6/home/Photos/Darktable /mnt/Darktable"
)
# ---------------------

# Prüfen, ob das Skript als root ausgeführt wird
if [ "$EUID" -ne 0 ]; then 
  echo "Fehler: Bitte mit sudo oder als root ausführen!"
  exit 1
fi

# Passwort abfragen
echo -n "Bitte das Passwort für Benutzer '$USER_NAME' eingeben: "
read -s PASSWORD
echo "" # Neue Zeile nach der passwortlosen Eingabe

# 1. Credentials-Datei im Root-Verzeichnis erstellen
echo "Erstelle Anmeldedaten in $SMB_CRED_FILE..."
cat <<EOF > "$SMB_CRED_FILE"
username=$USER_NAME
password=$PASSWORD
EOF

# Sicherheit: Nur Root darf die Datei lesen
chmod 600 "$SMB_CRED_FILE"

# 2. Verzeichnisse verarbeiten
for share_info in "${SHARES[@]}"; do
    # Den Eintrag in Pfad und Mountpoint teilen
    read -r REMOTE_PATH MOUNT_POINT <<< "$share_info"

    echo "Verarbeite: $REMOTE_PATH -> $MOUNT_POINT"

    # Mount-Punkt erstellen, falls nicht vorhanden
    if [ ! -d "$MOUNT_POINT" ]; then
        mkdir -p "$MOUNT_POINT"
        echo "  [+] Mount-Punkt $MOUNT_POINT wurde erstellt."
    fi

    # Prüfen, ob der Pfad bereits in der fstab steht
    if grep -q "$REMOTE_PATH" /etc/fstab; then
        echo "  [!] Eintrag existiert bereits in /etc/fstab. Überspringe..."
    else
        # Die fstab-Zeile zusammenbauen
        FSTAB_LINE="$REMOTE_PATH $MOUNT_POINT cifs credentials=$SMB_CRED_FILE,iocharset=utf8,vers=3.0,_netdev 0 0"
        
        echo "  [+] Füge Eintrag zu /etc/fstab hinzu..."
        echo "$FSTAB_LINE" >> /etc/fstab
    fi
done

# 3. Mounten testen
echo "Versuche, alle neuen Freigaben zu mounten..."
mount -a

echo "----------------------------------------------------"
echo "Fertig! Alle Verzeichnisse wurden konfiguriert."