#!/bin/bash

# NOTE: Ce script utilise des tableaux associatifs (declare -A) pour la sélection des services,
# ce qui nécessite Bash version 4.0 ou une version ultérieure.
# Les fonctions de prompt ont été modifiées pour éviter 'local -n' et améliorer
# la compatibilité avec les versions de Bash antérieures à 4.3.

# --- Couleurs (Modifiées pour une interprétation correcte par read -p) ---
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # Pas de couleur

# --- Fonctions utilitaires ---
echoinfo() {
  echo -e "${BLUE}INFO:${NC} $1"
}

echowarn() {
  echo -e "${YELLOW}ATTENTION:${NC} $1"
}

echoerror() {
  echo -e "${RED}ERREUR:${NC} $1"
}

echosuccess() {
  echo -e "${GREEN}SUCCÈS:${NC} $1"
}

is_number() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

prompt_with_default() {
  local prompt_message="$1"
  local default_value="$2"
  local result_var_name="$3" # Nom de la variable où stocker le résultat
  local input

  read -p "${CYAN}${prompt_message} [${default_value}]: ${NC}" input
  printf -v "$result_var_name" "%s" "${input:-$default_value}"
}

prompt_numeric_with_default() {
  local prompt_message="$1"
  local default_value="$2"
  local result_var_name="$3" # Nom de la variable où stocker le résultat
  local current_value

  while true; do
    prompt_with_default "$prompt_message" "$default_value" "$result_var_name"
    current_value="${!result_var_name}"

    if is_number "$current_value"; then
      break
    else
      echoerror "L'entrée doit être un nombre."
    fi
  done
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    echoerror "La commande '$1' est introuvable. Veuillez l'installer."
    exit 1
  fi
}

# Déterminer la commande docker compose à utiliser
DOCKER_COMPOSE_CMD=""
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echoerror "Ni 'docker compose' (v2) ni 'docker-compose' (v1) n'a été trouvé. Veuillez installer Docker Compose."
    exit 1
fi
echoinfo "Utilisation de la commande: $DOCKER_COMPOSE_CMD"


# --- Vérification des dépendances ---
echoinfo "Vérification des dépendances..."
check_command docker

# --- Message de bienvenue ---
echo -e "${GREEN}-------------------------------------------------------"
echo -e " Bienvenue dans l'assistant de déploiement Docker Compose "
echo -e "-------------------------------------------------------${NC}"
echo

# --- Prompt for Global Variables ---
echo -e "${YELLOW}--- Configuration Globale ---${NC}"
DEFAULT_GLOBAL_PUID=1000
DEFAULT_GLOBAL_PGID=1000
DEFAULT_GLOBAL_TZ="Europe/Paris"
DEFAULT_APP_DATA_BASE_PATH="/home/Docker"

prompt_numeric_with_default "Entrez le PUID Global" "$DEFAULT_GLOBAL_PUID" "GLOBAL_PUID"
prompt_numeric_with_default "Entrez le PGID Global" "$DEFAULT_GLOBAL_PGID" "GLOBAL_PGID"
prompt_with_default "Entrez le Fuseau Horaire (TZ) Global" "$DEFAULT_GLOBAL_TZ" "GLOBAL_TZ"
echo

echo -e "${YELLOW}--- Configuration des Chemins ---${NC}"
prompt_with_default "Entrez le chemin de base pour les données des applications" "$DEFAULT_APP_DATA_BASE_PATH" "APP_DATA_BASE_PATH"

CONFIG_EMBY_PATH="${APP_DATA_BASE_PATH}/Configurations/EmbyServer"
CONFIG_JELLYFIN_PATH="${APP_DATA_BASE_PATH}/Configurations/Jellyfin"
JELLYFIN_CACHE_PATH="${APP_DATA_BASE_PATH}/Cache/Jellyfin" # Chemin pour le cache de Jellyfin
JELLYFIN_FONTS_PATH="${APP_DATA_BASE_PATH}/Fonts/JellyfinCustom" # Chemin optionnel pour les polices custom Jellyfin

CONFIG_JELLYSEERR_PATH="${APP_DATA_BASE_PATH}/Configurations/Jellyseerr"
CONFIG_LIDARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Lidarr"
CONFIG_PROWLARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Prowlarr"
CONFIG_QBITTORRENT_PATH="${APP_DATA_BASE_PATH}/Configurations/QbitTorrent"
CONFIG_RADARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Radarr"
CONFIG_SONARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Sonarr"

echo
echo -e "${YELLOW}--- Configuration des Chemins Médias ---${NC}"
DEFAULT_MEDIA_TV_SHOWS_PATH="${APP_DATA_BASE_PATH}/Tvshows"
DEFAULT_MEDIA_MOVIES_PATH="${APP_DATA_BASE_PATH}/Movies"
DEFAULT_MEDIA_MUSIC_PATH="${APP_DATA_BASE_PATH}/Music"
DEFAULT_DOWNLOADS_PATH="${APP_DATA_BASE_PATH}/Torrents"

prompt_with_default "Entrez le chemin pour les Séries TV" "$DEFAULT_MEDIA_TV_SHOWS_PATH" "MEDIA_TV_SHOWS_PATH"
prompt_with_default "Entrez le chemin pour les Films" "$DEFAULT_MEDIA_MOVIES_PATH" "MEDIA_MOVIES_PATH"
prompt_with_default "Entrez le chemin pour la Musique" "$DEFAULT_MEDIA_MUSIC_PATH" "MEDIA_MUSIC_PATH"
prompt_with_default "Entrez le chemin pour les Téléchargements" "$DEFAULT_DOWNLOADS_PATH" "DOWNLOADS_PATH"
echo

# --- Media Server Choice ---
echo -e "${YELLOW}--- Choix du Serveur Multimédia ---${NC}"
echo "1) Emby"
echo "2) Jellyfin"
MEDIA_SERVER_CHOICE_INPUT=""

while true; do
  read -p "${CYAN}Entrez votre choix (1 pour Emby, 2 pour Jellyfin): ${NC}" MEDIA_SERVER_CHOICE_INPUT
  # Default choice removed as prompt now enforces 1 or 2
  MEDIA_SERVER_CHOICE="${MEDIA_SERVER_CHOICE_INPUT}"
  if [[ "$MEDIA_SERVER_CHOICE" =~ ^[12]$ ]]; then
    break
  else
    echoerror "Choix invalide. Veuillez entrer 1 ou 2."
  fi
done

MEDIA_SERVER_NAME=""
if [ "$MEDIA_SERVER_CHOICE" = "1" ]; then
  MEDIA_SERVER_NAME="Emby"
  echoinfo "Emby sera configuré."
elif [ "$MEDIA_SERVER_CHOICE" = "2" ]; then
  MEDIA_SERVER_NAME="Jellyfin"
  echoinfo "Jellyfin sera configuré."
fi
echo

# --- Services à déployer ---
# Liste de base des services (sans Emby/Jellyfin initialement)
BASE_SERVICES=("Prowlarr" "Radarr" "Sonarr" "Lidarr" "Byparr" "Jellyseerr" "QbitTorrent" "Watchtower")
ORDERED_SERVICES_TO_DEPLOY=()

# Ajoute le serveur multimédia choisi au début de la liste s'il a été sélectionné
if [ -n "$MEDIA_SERVER_NAME" ]; then
  ORDERED_SERVICES_TO_DEPLOY+=("$MEDIA_SERVER_NAME")
fi
# Ajoute les autres services
ORDERED_SERVICES_TO_DEPLOY+=("${BASE_SERVICES[@]}")

# SERVICES_TO_DEPLOY est utilisé pour vérifier l'inclusion dans le résumé, etc.
SERVICES_TO_DEPLOY=("${ORDERED_SERVICES_TO_DEPLOY[@]}")

echoinfo "Ce script va configurer le déploiement pour les services suivants (dans cet ordre):"
if [ ${#ORDERED_SERVICES_TO_DEPLOY[@]} -eq 0 ]; then
  echoinfo "  (Aucun service sélectionné pour le déploiement)"
else
  for service_name in "${ORDERED_SERVICES_TO_DEPLOY[@]}"; do
    echoinfo "  - $service_name"
  done
fi
echo


# --- Affichage du résumé et confirmation ---
echo -e "${YELLOW}--- RÉSUMÉ DE LA CONFIGURATION ---${NC}"
echo -e "${CYAN}Variables Globales:${NC}"
echo "  PUID Global: ${GLOBAL_PUID}"
echo "  PGID Global: ${GLOBAL_PGID}"
echo "  TZ Global: ${GLOBAL_TZ}"
echo
echo -e "${CYAN}Chemins de Configuration:${NC}"
echo "  Chemin de base des données: ${APP_DATA_BASE_PATH}"
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Emby " ]]; then echo "  Config Emby: ${CONFIG_EMBY_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Jellyfin " ]]; then echo "  Config Jellyfin: ${CONFIG_JELLYFIN_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Jellyseerr " ]]; then echo "  Config Jellyseerr: ${CONFIG_JELLYSEERR_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Lidarr " ]]; then echo "  Config Lidarr: ${CONFIG_LIDARR_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Prowlarr " ]]; then echo "  Config Prowlarr: ${CONFIG_PROWLARR_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " QbitTorrent " ]]; then echo "  Config QbitTorrent: ${CONFIG_QBITTORRENT_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Radarr " ]]; then echo "  Config Radarr: ${CONFIG_RADARR_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Sonarr " ]]; then echo "  Config Sonarr: ${CONFIG_SONARR_PATH}"; fi
echo
echo -e "${CYAN}Chemins Médias:${NC}"
echo "  Séries TV: ${MEDIA_TV_SHOWS_PATH}"
echo "  Films: ${MEDIA_MOVIES_PATH}"
echo "  Musique: ${MEDIA_MUSIC_PATH}"
echo "  Téléchargements: ${DOWNLOADS_PATH}"
echo
echo -e "${CYAN}Services à déployer:${NC}"
if [ ${#SERVICES_TO_DEPLOY[@]} -gt 0 ]; then
  services_to_deploy_sorted=($(printf '%s\n' "${SERVICES_TO_DEPLOY[@]}" | sort)) # Sorting only for display
  for service in "${services_to_deploy_sorted[@]}"; do
    echo "  - $service"
  done
else
    echo "  (Aucun)"
fi
echo

read -p "${YELLOW}Souhaitez-vous continuer avec cette configuration ? (o/N): ${NC}" confirm
if [[ ! "$confirm" =~ ^([oO][uU][iI]|[oO]|[yY][eE][sS]|[yY])$ ]]; then
  echoinfo "Opération annulée par l'utilisateur."
  exit 0
fi
echo

# --- Création du sous-répertoire compose ---
COMPOSE_DIR="compose"
echoinfo "Vérification/Création du répertoire '${COMPOSE_DIR}'..."
mkdir -p "${COMPOSE_DIR}"
echo "---------------------------------------"

# --- Fonctions de génération et de lancement ---
deploy_service() {
  local service_name_proper_case="$1"
  local yaml_content="$2"
  local yaml_file="${COMPOSE_DIR}/${service_name_proper_case,,}.yaml" # lowercase filename

  echoinfo "Création de ${yaml_file} et lancement du service ${service_name_proper_case}..."
  echo -e "$yaml_content" > "$yaml_file"

  if $DOCKER_COMPOSE_CMD -f "$yaml_file" up -d; then
    echosuccess "Service ${service_name_proper_case} démarré."
  else
    echoerror "Échec du démarrage du service ${service_name_proper_case}. Vérifiez ${yaml_file} et les logs Docker."
  fi
}

generate_and_deploy() {
  local service_name="$1"
  local yaml_content=""

  case "$service_name" in
    "Emby")
      yaml_content="---
services:
  emby:
    image: emby/embyserver:latest
    container_name: Emby
    labels:
      - com.centurylinklabs.watchtower.enable=true
    environment:
      - PUID=${GLOBAL_PUID}
      - PGID=${GLOBAL_PGID}
      - TZ=${GLOBAL_TZ}
    volumes:
      - ${CONFIG_EMBY_PATH}:/config
      - ${MEDIA_TV_SHOWS_PATH}:/mnt/tvshows
      - ${MEDIA_MOVIES_PATH}:/mnt/movies
      - ${MEDIA_MUSIC_PATH}:/mnt/music # Ajout du chemin musique pour Emby
    ports:
      - \"8096:8096\"
      - \"8920:8920\"
    restart: on-failure"
      ;;
    "Jellyfin")
      yaml_content="---
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: Jellyfin
    labels:
      - com.centurylinklabs.watchtower.enable=true
    environment:
      - PUID=${GLOBAL_PUID}
      - PGID=${GLOBAL_PGID}
      - TZ=${GLOBAL_TZ}
      # - JELLYFIN_PublishedServerUrl=http://example.com # Optionnel: à configurer dans Jellyfin ou décommenter
    volumes:
      - ${CONFIG_JELLYFIN_PATH}/config:/config
      - ${CONFIG_JELLYFIN_PATH}/cache:/cache # Corrected from JELLYFIN_CACHE_PATH to actual mount
      - ${MEDIA_TV_SHOWS_PATH}:/media/tvshows
      - ${MEDIA_MOVIES_PATH}:/media/movies
      - ${MEDIA_MUSIC_PATH}:/media/music
    ports:
      - \"8096:8096\"
      - \"8920:8920\" # Port HTTPS standard, comme Emby
    restart: unless-stopped"
      ;;
    "Prowlarr")
      yaml_content="---
services:
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: Prowlarr
    labels:
      - com.centurylinklabs.watchtower.enable=true
    environment:
      - PUID=${GLOBAL_PUID}
      - PGID=${GLOBAL_PGID}
      - TZ=${GLOBAL_TZ}
    volumes:
      - ${CONFIG_PROWLARR_PATH}:/config
    ports:
      - \"9696:9696\"
    restart: unless-stopped"
      ;;
    "Radarr")
      yaml_content="---
services:
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: Radarr
    labels:
      - com.centurylinklabs.watchtower.enable=true
    environment:
      - PUID=${GLOBAL_PUID}
      - PGID=${GLOBAL_PGID}
      - TZ=${GLOBAL_TZ}
    volumes:
      - ${CONFIG_RADARR_PATH}:/config
      - ${MEDIA_MOVIES_PATH}:/movies
      - ${DOWNLOADS_PATH}:/downloads
    ports:
      - \"7878:7878\"
    restart: unless-stopped"
      ;;
    "Sonarr")
      yaml_content="---
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: Sonarr
    labels:
      - com.centurylinklabs.watchtower.enable=true
    environment:
      - PUID=${GLOBAL_PUID}
      - PGID=${GLOBAL_PGID}
      - TZ=${GLOBAL_TZ}
    volumes:
      - ${CONFIG_SONARR_PATH}:/config
      - ${MEDIA_TV_SHOWS_PATH}:/tv
      - ${DOWNLOADS_PATH}:/downloads
    ports:
      - \"8989:8989\"
    restart: unless-stopped"
      ;;
    "Lidarr")
      yaml_content="---
services:
  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    container_name: Lidarr
    labels:
      - com.centurylinklabs.watchtower.enable=true
    ports:
      - \"8686:8686\"
    environment:
      - PUID=${GLOBAL_PUID}
      - PGID=${GLOBAL_PGID}
      - UMASK=002
      - TZ=${GLOBAL_TZ}
    volumes:
      - ${CONFIG_LIDARR_PATH}:/config
      - ${MEDIA_MUSIC_PATH}:/music
      - ${DOWNLOADS_PATH}:/downloads
    restart: unless-stopped"
      ;;
    "Byparr")
      yaml_content="---
services:
  Byparr: # Note: 'Byparr' might be a typo for a less common service or a custom one. Name kept as is.
    image: ghcr.io/thephaseless/byparr:latest
    container_name: Byparr
    labels:
      - com.centurylinklabs.watchtower.enable=true
    environment:
      - LOG_LEVEL=\${LOG_LEVEL:-info}
      - LOG_HTML=\${LOG_HTML:-false}
      - CAPTCHA_SOLVER=\${CAPTCHA_SOLVER:-none}
      - TZ=${GLOBAL_TZ}
    ports:
      - \"8191:8191\"
    restart: unless-stopped"
      ;;
    "Jellyseerr")
      # Dynamically set JELLYFIN_TYPE based on the user's media server choice
      local selected_media_server_type_lowercase="emby" # Default to emby if somehow MEDIA_SERVER_NAME is not set
      if [ -n "$MEDIA_SERVER_NAME" ]; then
          selected_media_server_type_lowercase=$(echo "$MEDIA_SERVER_NAME" | tr '[:upper:]' '[:lower:]')
      fi

      yaml_content="---
services:
  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: Jellyseerr
    labels:
      - com.centurylinklabs.watchtower.enable=true
    environment:
      - LOG_LEVEL=info
      - TZ=${GLOBAL_TZ}
      - PORT=5055 # Jellyseerr uses PORT for its internal port
      - JELLYFIN_TYPE=${selected_media_server_type_lowercase} # Dynamically set
    ports:
      - \"5055:5055\" # Expose the port defined by PORT env var
    volumes:
      - ${CONFIG_JELLYSEERR_PATH}:/app/config
    restart: unless-stopped"
      ;;
    "QbitTorrent")
      yaml_content="---
services:
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: QbitTorrent
    labels:
      - com.centurylinklabs.watchtower.enable=true
    environment:
      - PUID=${GLOBAL_PUID}
      - PGID=${GLOBAL_PGID}
      - TZ=${GLOBAL_TZ}
      - WEBUI_PORT=8080
      - TORRENTING_PORT=6881
    volumes:
      - ${CONFIG_QBITTORRENT_PATH}:/config
      - ${DOWNLOADS_PATH}:/downloads
    ports:
      - \"8080:8080\"
      - \"6881:6881\"
      - \"6881:6881/udp\"
    restart: unless-stopped"
      ;;
    "Watchtower")
      yaml_content="---
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: Watchtower
    environment:
      - TZ=${GLOBAL_TZ}
      # - WATCHTOWER_CLEANUP=true
      # - WATCHTOWER_SCHEDULE=\"0 0 4 * * *\" # Check every day at 4 AM
      # - WATCHTOWER_POLL_INTERVAL=3600 # Check every hour (alternative to cron)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped"
      ;;
    *)
      echowarn "Aucune configuration YAML définie pour le service : $service_name"
      return
      ;;
  esac

  if [ -n "$yaml_content" ]; then
    # Create necessary config directories before deploying
    if [[ "$service_name" == "Emby" ]] && [ ! -d "${CONFIG_EMBY_PATH}" ]; then mkdir -p "${CONFIG_EMBY_PATH}"; fi
    if [[ "$service_name" == "Jellyfin" ]]; then
        if [ ! -d "${CONFIG_JELLYFIN_PATH}/config" ]; then mkdir -p "${CONFIG_JELLYFIN_PATH}/config"; fi # Ensure config subfolder exists
        if [ ! -d "${CONFIG_JELLYFIN_PATH}/cache" ]; then mkdir -p "${CONFIG_JELLYFIN_PATH}/cache"; fi   # Ensure cache subfolder exists
        # User should create JELLYFIN_FONTS_PATH if they intend to use it
    fi
    if [[ "$service_name" == "Jellyseerr" ]] && [ ! -d "${CONFIG_JELLYSEERR_PATH}" ]; then mkdir -p "${CONFIG_JELLYSEERR_PATH}"; fi
    if [[ "$service_name" == "Lidarr" ]] && [ ! -d "${CONFIG_LIDARR_PATH}" ]; then mkdir -p "${CONFIG_LIDARR_PATH}"; fi
    if [[ "$service_name" == "Prowlarr" ]] && [ ! -d "${CONFIG_PROWLARR_PATH}" ]; then mkdir -p "${CONFIG_PROWLARR_PATH}"; fi
    if [[ "$service_name" == "QbitTorrent" ]] && [ ! -d "${CONFIG_QBITTORRENT_PATH}" ]; then mkdir -p "${CONFIG_QBITTORRENT_PATH}"; fi
    if [[ "$service_name" == "Radarr" ]] && [ ! -d "${CONFIG_RADARR_PATH}" ]; then mkdir -p "${CONFIG_RADARR_PATH}"; fi
    if [[ "$service_name" == "Sonarr" ]] && [ ! -d "${CONFIG_SONARR_PATH}" ]; then mkdir -p "${CONFIG_SONARR_PATH}"; fi
    
    # Create media directories if they don't exist
    if [ ! -d "${MEDIA_TV_SHOWS_PATH}" ]; then mkdir -p "${MEDIA_TV_SHOWS_PATH}"; fi
    if [ ! -d "${MEDIA_MOVIES_PATH}" ]; then mkdir -p "${MEDIA_MOVIES_PATH}"; fi
    if [ ! -d "${MEDIA_MUSIC_PATH}" ]; then mkdir -p "${MEDIA_MUSIC_PATH}"; fi
    if [ ! -d "${DOWNLOADS_PATH}" ]; then mkdir -p "${DOWNLOADS_PATH}"; fi

    deploy_service "$service_name" "$yaml_content"
  fi
}

# --- Boucle de déploiement principale ---
if [ ${#ORDERED_SERVICES_TO_DEPLOY[@]} -gt 0 ]; then
  echoinfo "Déploiement des services configurés..."
  for service_to_run in "${ORDERED_SERVICES_TO_DEPLOY[@]}"; do
    generate_and_deploy "$service_to_run"
    echo "---------------------------------------"
  done
else
    echoinfo "Aucun service n'a été sélectionné pour le déploiement."
fi


# --- Nettoyage optionnel des fichiers YAML ---
if [ ${#ORDERED_SERVICES_TO_DEPLOY[@]} -gt 0 ]; then
    echo
    read -p "${CYAN}Souhaitez-vous supprimer les fichiers YAML générés dans le répertoire '${COMPOSE_DIR}' ? (o/N): ${NC}" cleanup_choice
    if [[ "$cleanup_choice" =~ ^([oO][uU][iI]|[oO]|[yY][eE][sS]|[yY])$ ]]; then
    echoinfo "Suppression des fichiers YAML..."
    if rm -rf "${COMPOSE_DIR}"; then
        echosuccess "Répertoire '${COMPOSE_DIR}' et ses fichiers YAML supprimés."
    else
        echoerror "Échec de la suppression du répertoire '${COMPOSE_DIR}'."
    fi
    else
    echoinfo "Les fichiers YAML sont conservés dans le répertoire '${COMPOSE_DIR}'."
    fi
fi

# --- État Simplifié des Conteneurs Docker ---
if [ ${#ORDERED_SERVICES_TO_DEPLOY[@]} -gt 0 ]; then
  echo
  echoinfo "--- État Simplifié des Conteneurs Docker Déployés ---"
  for service_name_status in "${ORDERED_SERVICES_TO_DEPLOY[@]}"; do
    # Le nom du conteneur est supposé être le même que le nom du service (ex: Emby, Prowlarr)
    # car container_name est défini ainsi dans les fichiers YAML.
    container_state=$(docker inspect --format='{{.State.Status}}' "${service_name_status}" 2>/dev/null)
    exit_code_inspect=$? # Récupère le code de sortie de la commande docker inspect

    if [ $exit_code_inspect -eq 0 ]; then # Si docker inspect a réussi
      if [ "$container_state" == "running" ]; then
        echo -e "${CYAN}Statut pour ${service_name_status}:${NC} ${GREEN}SUCCESS (Up)${NC}"
      else
        # Les autres états (exited, created, restarting, paused, dead) sont considérés comme FAILED
        echo -e "${CYAN}Statut pour ${service_name_status}:${NC} ${RED}FAILED (État: ${container_state})${NC}"
      fi
    else
      # Si docker inspect échoue, le conteneur n'est probablement pas trouvé ou une autre erreur s'est produite.
      echo -e "${CYAN}Statut pour ${service_name_status}:${NC} ${RED}FAILED (Non trouvé ou erreur lors de l'inspection)${NC}"
    fi
  done
  echo "---------------------------------------"
fi

echo
echosuccess "--- Fin du Script ---"
if [ ${#ORDERED_SERVICES_TO_DEPLOY[@]} -gt 0 ]; then
  echoinfo "Les services Docker Compose configurés ont été traités."
  echoinfo "Vérifiez les logs de chaque conteneur si vous rencontrez des problèmes (ex: docker logs NomDuConteneur)."
  echoinfo "Exemple pour Watchtower: docker logs Watchtower"
else
  echoinfo "Aucun service n'a été configuré pour le déploiement."
fi