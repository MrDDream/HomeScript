#!/bin/bash

# S'assurer que le script est exécuté en tant que root
if [ "$(id -u)" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root ou avec sudo." >&2
  exit 1
fi

# Mettre à jour les paquets et installer les dépendances nécessaires
echo "Mise à jour des paquets et installation de zsh, git et wget..."
apt-get update && apt-get install -y zsh git wget

# --- Installation centralisée de Oh My Zsh ---
if [ -d "/opt/oh-my-zsh" ]; then
  echo "Le répertoire /opt/oh-my-zsh existe déjà. Mise à jour..."
  (cd /opt/oh-my-zsh && git pull)
else
  echo "Clonage de Oh My Zsh dans /opt/oh-my-zsh pour une installation centralisée..."
  git clone https://github.com/ohmyzsh/ohmyzsh.git /opt/oh-my-zsh
fi

# Récupérer la configuration .zshrc personnalisée dans un fichier temporaire
echo "Téléchargement de la configuration .zshrc personnalisée..."
wget -O /tmp/zshrc_template https://raw.githubusercontent.com/MrDDream/HomeScript/refs/heads/main/.zshrc

# Adapter le .zshrc pour pointer vers l'installation de /opt
# Ceci remplace la ligne 'export ZSH="$HOME/.oh-my-zsh"' par la version centralisée
echo "Adaptation du .zshrc pour l'installation centralisée..."
sed -i 's|export ZSH="\$HOME/\.oh-my-zsh"|export ZSH="/opt/oh-my-zsh"|g' /tmp/zshrc_template

# Définir ZSH comme shell par défaut et copier la config pour root
echo "Configuration pour l'utilisateur root..."
chsh -s "$(which zsh)" root
cp /tmp/zshrc_template /root/.zshrc
chown root:root /root/.zshrc

# Configurer le .zshrc pour les nouveaux utilisateurs
echo "Configuration de ZSH pour les nouveaux utilisateurs via /etc/skel..."
cp /tmp/zshrc_template /etc/skel/.zshrc

# Appliquer la configuration ZSH à tous les utilisateurs existants (UID >= 1000)
echo "Application de la configuration ZSH à tous les utilisateurs humains existants..."
for user in $(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}'); do
    # Vérifier si le répertoire personnel existe
    user_home=$(getent passwd "$user" | cut -d: -f6)
    if [ ! -d "$user_home" ]; then
        echo "Le répertoire personnel pour l'utilisateur $user ($user_home) n'existe pas. On l'ignore."
        continue
    fi
    
    echo "Configuration pour l'utilisateur : $user"

    # Définir ZSH comme shell par défaut
    chsh -s "$(which zsh)" "$user"

    # Copier la configuration .zshrc dans le répertoire personnel de l'utilisateur
    cp /tmp/zshrc_template "$user_home/.zshrc"

    # S'assurer que l'utilisateur est le propriétaire du fichier
    chown "$user:$user" "$user_home/.zshrc"
done

# Nettoyer le fichier temporaire
rm /tmp/zshrc_template

echo "L'installation et la configuration de ZSH et Oh My Zsh sont terminées."
echo "Veuillez vous déconnecter et vous reconnecter pour que les changements prennent effet."
