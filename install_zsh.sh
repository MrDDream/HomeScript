#!/bin/bash

# S'assurer que le script est exécuté en tant que root
if [ "$(id -u)" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root ou avec sudo." >&2
  exit 1
fi

# Mettre à jour les paquets et installer les dépendances nécessaires
echo "Mise à jour des paquets et installation de zsh, wget et git..."
apt-get update && apt-get install -y zsh wget git

# Installation de Oh My Zsh
echo "Installation de Oh My Zsh..."
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)" "" --unattended

# Récupérer la configuration .zshrc personnalisée
echo "Téléchargement de la configuration .zshrc personnalisée..."
wget -O /root/.zshrc https://git.dwcloud.fr/MrDDream/Scripts/raw/branch/main/.zshrc

# Définir ZSH comme shell par défaut pour root
echo "Définition de ZSH comme shell par défaut pour l'utilisateur root..."
chsh -s "$(which zsh)" root

# Configurer le .zshrc pour les nouveaux utilisateurs
echo "Configuration de ZSH pour les nouveaux utilisateurs..."
cp /root/.zshrc /etc/skel/

# Appliquer la configuration ZSH à tous les utilisateurs existants (UID >= 1000)
echo "Application de la configuration ZSH à tous les utilisateurs existants..."
for user in $(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}'); do
    echo "Configuration pour l'utilisateur : $user"

    # Définir ZSH comme shell par défaut
    chsh -s "$(which zsh)" "$user"

    # Copier la configuration .zshrc dans le répertoire personnel de l'utilisateur
    cp "/root/.zshrc" "/home/$user/.zshrc"

    # S'assurer que l'utilisateur est le propriétaire du fichier
    chown "$user:$user" "/home/$user/.zshrc"

    # Installer Oh My Zsh pour l'utilisateur
    sudo -u "$user" sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)" "" --unattended
done

echo "L'installation et la configuration de ZSH et Oh My Zsh sont terminées pour tous les utilisateurs."
echo "Veuillez vous déconnecter et vous reconnecter pour que les changements prennent effet."