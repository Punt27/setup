#!/bin/bash

KEY_FILE="$HOME/.ssh/id_ed25519"

echo ">>> SSH Setup"
if [ -f "$KEY_FILE" ]; then
    echo "Key existiert bereits."
else
    read -p "GitHub E-Mail Adresse: " USER_EMAIL
    ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$KEY_FILE" -N ""
fi

eval "$(ssh-agent -s)"
ssh-add "$KEY_FILE"

echo "-----------------------------------------------------"
cat "${KEY_FILE}.pub"
echo "-----------------------------------------------------"

if command -v xclip &> /dev/null; then
    cat "${KEY_FILE}.pub" | xclip -sel clip
    echo "Kopiert in Zwischenablage!"
fi

echo "Bitte füge den Key bei GitHub hinzu."
echo "Drücke eine Taste, wenn du fertig bist..."
read -n 1 -s
