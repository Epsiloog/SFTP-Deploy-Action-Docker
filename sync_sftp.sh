#!/bin/sh

# === Vérification des variables d’environnement ===
if [ -z "$SFTP_USER" ] || [ -z "$SFTP_HOST" ] || [ -z "$SFTP_REMOTE_DIR" ]; then
    echo "[ERROR] 🚨 Variables SFTP manquantes ! Vérifie tes secrets GitHub."
    exit 1
fi

# Variables de connexion
SFTP_PORT=${SFTP_PORT:-22}  # Valeur par défaut : 22
USE_SSH_PASS=false  # Par défaut, on utilise la clé SSH

# Vérifier si le mot de passe SFTP est défini (sshpass)
if [ -n "$SFTP_PASSWORD" ]; then
    USE_SSH_PASS=true
fi

# Vérification de la clé privée GitHub avec la clé publique du serveur
if [ -n "$GITHUB_PRIVATE_KEY" ]; then
    echo "[INFO] 🔑 Vérification de la clé SSH GitHub..."
    echo "$GITHUB_PRIVATE_KEY" > /tmp/github_key.pem
    chmod 600 /tmp/github_key.pem

    PUB_KEY=$(ssh -o StrictHostKeyChecking=no -i /tmp/github_key.pem "$SFTP_USER@$SFTP_HOST" "cat ~/.ssh/id_rsa.pub" 2>/dev/null)
    LOCAL_PUB_KEY=$(ssh-keygen -y -f /tmp/github_key.pem 2>/dev/null)

    if [ "$LOCAL_PUB_KEY" = "$PUB_KEY" ]; then
        echo "[INFO] ✅ Clés SSH validées."
    else
        echo "[WARNING] ❌ Les clés ne correspondent pas !"
        exit 1
    fi
fi

# Construction de la commande rsync
RSYNC_CMD="rsync -avz --progress --delete"

# Vérifier si un fichier d’exclusion existe
if [ -f "./exclude.txt" ]; then
    RSYNC_CMD+=" --exclude-from=./exclude.txt"
    echo "[INFO] 📂 Exclusions appliquées depuis exclude.txt"
fi

# Exécuter rsync avec sshpass ou clé SSH
if [ "$USE_SSH_PASS" = true ]; then
    echo "[INFO] 🔑 Connexion via sshpass..."
    RSYNC_CMD="sshpass -p \"$SFTP_PASSWORD\" $RSYNC_CMD -e 'ssh -p $SFTP_PORT' ./ $SFTP_USER@$SFTP_HOST:$SFTP_REMOTE_DIR"
else
    echo "[INFO] 🔑 Connexion via clé SSH..."
    RSYNC_CMD="$RSYNC_CMD -e 'ssh -p $SFTP_PORT -i /tmp/github_key.pem' ./ $SFTP_USER@$SFTP_HOST:$SFTP_REMOTE_DIR"
fi

# Exécuter la synchronisation
echo "[INFO] 🚀 Démarrage de la synchronisation..."
eval $RSYNC_CMD

# Vérifier si rsync a réussi
if [ $? -eq 0 ]; then
    echo "[SUCCESS] ✅ Synchronisation terminée avec succès."
else
    echo "[ERROR] ❌ Échec de la synchronisation."
    exit 1
fi
