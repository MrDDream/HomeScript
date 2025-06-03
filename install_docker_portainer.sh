#!/bin/bash

# Mettre à jour les paquets et installer les dépendances nécessaires
echo "mise à jour des paquets et installation des dépendances..."
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Ajouter la clé GPG officielle de Docker
echo "ajout de la clé GPG de Docker..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Configurer le dépôt Docker
echo "configuration du dépôt Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installer Docker Engine
echo "installation de Docker Engine..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# Vérifier l'installation de Docker
echo "vérification de l'installation de Docker..."
if sudo docker run hello-world; then
    echo "Docker installé avec succès."
else
    echo "Erreur lors de l'installation de Docker."
    exit 1
fi

# Installer Docker Compose (dernière version)
echo "installation de la dernière version de Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$DOCKER_COMPOSE_VERSION" ]; then
    echo "Impossible de récupérer la dernière version de Docker Compose. Installation de la v2.27.0 par défaut."
    DOCKER_COMPOSE_VERSION="v2.27.0" # Version de secours
fi
echo "Installation de Docker Compose version $DOCKER_COMPOSE_VERSION"
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Alternative pour les systèmes où /usr/local/bin/docker-compose ne fonctionne pas directement (ex: plugin)
# sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Vérifier l'installation de Docker Compose
echo "vérification de l'installation de Docker Compose..."
if docker-compose --version; then
    echo "Docker Compose installé avec succès."
else
    echo "Erreur lors de l'installation de Docker Compose."
    # Tentative d'installation via le plugin docker-compose-plugin si l'installation binaire a échoué
    echo "Tentative d'installation de docker-compose-plugin..."
    sudo apt-get install -y docker-compose-plugin
    if docker compose version; then # Notez l'absence du tiret pour la commande plugin
        echo "docker-compose-plugin installé avec succès."
    else
        echo "Erreur lors de l'installation de docker-compose-plugin."
        exit 1
    fi
fi


# Créer un volume pour les données persistantes de Portainer
echo "création du volume Portainer..."
sudo docker volume create portainer_data

# Installer et démarrer Portainer CE
echo "installation et démarrage de Portainer CE..."
sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

echo "Portainer CE devrait être accessible sur https://$(hostname -I | awk '{print $1'}):9443 ou https://localhost:9443"
echo "Installation terminée !"