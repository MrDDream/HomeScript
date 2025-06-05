#!/bin/bash

# NOTE: This script uses associative arrays (declare -A) for service selection,
# which requires Bash version 4.0 or later.
# The prompt functions have been modified to avoid 'local -n' and improve
# compatibility with Bash versions prior to 4.3.

# --- Colors (Modified for correct interpretation by read -p) ---
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color

# --- Utility Functions ---
echoinfo() {
  echo -e "${BLUE}INFO:${NC} $1"
}

echowarn() {
  echo -e "${YELLOW}WARNING:${NC} $1"
}

echoerror() {
  echo -e "${RED}ERROR:${NC} $1"
}

echosuccess() {
  echo -e "${GREEN}SUCCESS:${NC} $1"
}

is_number() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

prompt_with_default() {
  local prompt_message="$1"
  local default_value="$2"
  local result_var_name="$3" # Name of the variable to store the result
  local input

  read -p "${CYAN}${prompt_message} [${default_value}]: ${NC}" input
  printf -v "$result_var_name" "%s" "${input:-$default_value}"
}

prompt_numeric_with_default() {
  local prompt_message="$1"
  local default_value="$2"
  local result_var_name="$3" # Name of the variable to store the result
  local current_value

  while true; do
    prompt_with_default "$prompt_message" "$default_value" "$result_var_name"
    current_value="${!result_var_name}"

    if is_number "$current_value"; then
      break
    else
      echoerror "Input must be a number."
    fi
  done
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    echoerror "Command '$1' not found. Please install it."
    exit 1
  fi
}

# Determine the docker compose command to use
DOCKER_COMPOSE_CMD=""
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echoerror "Neither 'docker compose' (v2) nor 'docker-compose' (v1) was found. Please install Docker Compose."
    exit 1
fi
echoinfo "Using command: $DOCKER_COMPOSE_CMD"


# --- Checking dependencies ---
echoinfo "Checking dependencies..."
check_command docker

# --- Welcome Message ---
echo -e "${GREEN}--------------------------------------"
echo -e " Welcome to the Arr Deployment Wizard"
echo -e "--------------------------------------${NC}"
echo

# --- Prompt for Global Variables ---
echo -e "${YELLOW}--- Global Configuration ---${NC}"
DEFAULT_GLOBAL_PUID=1000
DEFAULT_GLOBAL_PGID=1000
DEFAULT_GLOBAL_TZ="Europe/Paris" # You might want to change this default or prompt for it if targeting international users
DEFAULT_APP_DATA_BASE_PATH="/home/Docker" # Consider making this more generic like /srv/docker or /opt/docker

prompt_numeric_with_default "Enter Global PUID" "$DEFAULT_GLOBAL_PUID" "GLOBAL_PUID"
prompt_numeric_with_default "Enter Global PGID" "$DEFAULT_GLOBAL_PGID" "GLOBAL_PGID"
prompt_with_default "Enter Global Timezone (TZ)" "$DEFAULT_GLOBAL_TZ" "GLOBAL_TZ"
echo

echo -e "${YELLOW}--- Path Configuration ---${NC}"
prompt_with_default "Enter the base path for application data" "$DEFAULT_APP_DATA_BASE_PATH" "APP_DATA_BASE_PATH"

CONFIG_EMBY_PATH="${APP_DATA_BASE_PATH}/Configurations/EmbyServer"
CONFIG_JELLYFIN_PATH="${APP_DATA_BASE_PATH}/Configurations/Jellyfin"

CONFIG_JELLYSEERR_PATH="${APP_DATA_BASE_PATH}/Configurations/Jellyseerr"
CONFIG_LIDARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Lidarr"
CONFIG_PROWLARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Prowlarr"
CONFIG_QBITTORRENT_PATH="${APP_DATA_BASE_PATH}/Configurations/QbitTorrent"
CONFIG_RADARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Radarr"
CONFIG_SONARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Sonarr"

echo
echo -e "${YELLOW}--- Media Path Configuration ---${NC}"
DEFAULT_MEDIA_TV_SHOWS_PATH="${APP_DATA_BASE_PATH}/Tvshows"
DEFAULT_MEDIA_MOVIES_PATH="${APP_DATA_BASE_PATH}/Movies"
DEFAULT_MEDIA_MUSIC_PATH="${APP_DATA_BASE_PATH}/Music"
DEFAULT_DOWNLOADS_PATH="${APP_DATA_BASE_PATH}/Torrents"

prompt_with_default "Enter the path for TV Shows" "$DEFAULT_MEDIA_TV_SHOWS_PATH" "MEDIA_TV_SHOWS_PATH"
prompt_with_default "Enter the path for Movies" "$DEFAULT_MEDIA_MOVIES_PATH" "MEDIA_MOVIES_PATH"
prompt_with_default "Enter the path for Music" "$DEFAULT_MEDIA_MUSIC_PATH" "MEDIA_MUSIC_PATH"
prompt_with_default "Enter the path for Downloads" "$DEFAULT_DOWNLOADS_PATH" "DOWNLOADS_PATH"
echo

# --- Media Server Choice ---
echo -e "${YELLOW}--- Media Server Choice ---${NC}"
echo "1) Emby"
echo "2) Jellyfin"
MEDIA_SERVER_CHOICE_INPUT=""

while true; do
  read -p "${CYAN}Enter your choice: ${NC}" MEDIA_SERVER_CHOICE_INPUT
  MEDIA_SERVER_CHOICE="${MEDIA_SERVER_CHOICE_INPUT}"
  if [[ "$MEDIA_SERVER_CHOICE" =~ ^[12]$ ]]; then
    break
  else
    echoerror "Invalid choice. Please enter 1 or 2."
  fi
done

MEDIA_SERVER_NAME=""
if [ "$MEDIA_SERVER_CHOICE" = "1" ]; then
  MEDIA_SERVER_NAME="Emby"
  echoinfo "Emby will be configured."
elif [ "$MEDIA_SERVER_CHOICE" = "2" ]; then
  MEDIA_SERVER_NAME="Jellyfin"
  echoinfo "Jellyfin will be configured."
fi
echo

# --- Services to deploy ---
# Base list of services (initially without Emby/Jellyfin)
BASE_SERVICES=("Prowlarr" "Radarr" "Sonarr" "Lidarr" "Byparr" "Jellyseerr" "QbitTorrent" "Watchtower")
ORDERED_SERVICES_TO_DEPLOY=()

# Adds the chosen media server to the beginning of the list if selected
if [ -n "$MEDIA_SERVER_NAME" ]; then
  ORDERED_SERVICES_TO_DEPLOY+=("$MEDIA_SERVER_NAME")
fi
# Adds the other services
ORDERED_SERVICES_TO_DEPLOY+=("${BASE_SERVICES[@]}")

# SERVICES_TO_DEPLOY is used to check inclusion in the summary, etc.
SERVICES_TO_DEPLOY=("${ORDERED_SERVICES_TO_DEPLOY[@]}")

echoinfo "This script will configure deployment for the following services (in this order):"
if [ ${#ORDERED_SERVICES_TO_DEPLOY[@]} -eq 0 ]; then
  echoinfo "  (No service selected for deployment)"
else
  for service_name in "${ORDERED_SERVICES_TO_DEPLOY[@]}"; do
    echoinfo "  - $service_name"
  done
fi
echo


# --- CONFIGURATION SUMMARY ---
echo -e "${YELLOW}--- CONFIGURATION SUMMARY ---${NC}"
echo -e "${CYAN}Global Variables:${NC}"
echo "  Global PUID: ${GLOBAL_PUID}"
echo "  Global PGID: ${GLOBAL_PGID}"
echo "  Global TZ: ${GLOBAL_TZ}"
echo
echo -e "${CYAN}Configuration Paths:${NC}"
echo "  Base data path: ${APP_DATA_BASE_PATH}"
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Emby " ]]; then echo "  Emby Config: ${CONFIG_EMBY_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Jellyfin " ]]; then echo "  Jellyfin Config: ${CONFIG_JELLYFIN_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Jellyseerr " ]]; then echo "  Jellyseerr Config: ${CONFIG_JELLYSEERR_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Lidarr " ]]; then echo "  Lidarr Config: ${CONFIG_LIDARR_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Prowlarr " ]]; then echo "  Prowlarr Config: ${CONFIG_PROWLARR_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " QbitTorrent " ]]; then echo "  QbitTorrent Config: ${CONFIG_QBITTORRENT_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Radarr " ]]; then echo "  Radarr Config: ${CONFIG_RADARR_PATH}"; fi
if [[ " ${SERVICES_TO_DEPLOY[@]} " =~ " Sonarr " ]]; then echo "  Sonarr Config: ${CONFIG_SONARR_PATH}"; fi
echo
echo -e "${CYAN}Media Paths:${NC}"
echo "  TV Shows: ${MEDIA_TV_SHOWS_PATH}"
echo "  Movies: ${MEDIA_MOVIES_PATH}"
echo "  Music: ${MEDIA_MUSIC_PATH}"
echo "  Downloads: ${DOWNLOADS_PATH}"
echo
echo -e "${CYAN}Services to deploy:${NC}"
if [ ${#SERVICES_TO_DEPLOY[@]} -gt 0 ]; then
  services_to_deploy_sorted=($(printf '%s\n' "${SERVICES_TO_DEPLOY[@]}" | sort)) # Sorting only for display
  for service in "${services_to_deploy_sorted[@]}"; do
    echo "  - $service"
  done
else
    echo "  (None)"
fi
echo

read -p "${YELLOW}Do you want to continue with this configuration? (y/N): ${NC}" confirm
if [[ ! "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echoinfo "Operation cancelled by the user."
  exit 0
fi
echo

# --- Creating compose subdirectory ---
COMPOSE_DIR="compose"
echoinfo "Checking/Creating directory '${COMPOSE_DIR}'..."
mkdir -p "${COMPOSE_DIR}"
echo "---------------------------------------"

# --- Generation and Launch Functions ---
deploy_service() {
  local service_name_proper_case="$1"
  local yaml_content="$2"
  local yaml_file="${COMPOSE_DIR}/${service_name_proper_case,,}.yaml" # lowercase filename

  echoinfo "Creating ${yaml_file} and starting service ${service_name_proper_case}..."
  echo -e "$yaml_content" > "$yaml_file"

  if $DOCKER_COMPOSE_CMD -f "$yaml_file" up -d; then
    echosuccess "Service ${service_name_proper_case} started."
  else
    echoerror "Failed to start service ${service_name_proper_case}. Check ${yaml_file} and Docker logs."
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
      - ${MEDIA_MUSIC_PATH}:/mnt/music # Added music path for Emby
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
      # - JELLYFIN_PublishedServerUrl=http://example.com # Optional: configure in Jellyfin or uncomment
    volumes:
      - ${CONFIG_JELLYFIN_PATH}/config:/config
      - ${CONFIG_JELLYFIN_PATH}/cache:/cache # Corrected from JELLYFIN_CACHE_PATH to actual mount
      - ${MEDIA_TV_SHOWS_PATH}:/media/tvshows
      - ${MEDIA_MOVIES_PATH}:/media/movies
      - ${MEDIA_MUSIC_PATH}:/media/music
    ports:
      - \"8096:8096\"
      - \"8920:8920\" # Standard HTTPS port, like Emby
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
      echowarn "No YAML configuration defined for service: $service_name"
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

# --- Main Deployment Loop ---
if [ ${#ORDERED_SERVICES_TO_DEPLOY[@]} -gt 0 ]; then
  echoinfo "Deploying configured services..."
  for service_to_run in "${ORDERED_SERVICES_TO_DEPLOY[@]}"; do
    generate_and_deploy "$service_to_run"
    echo "---------------------------------------"
  done
else
    echoinfo "No services were selected for deployment."
fi


# --- Optional YAML File Cleanup ---
if [ ${#ORDERED_SERVICES_TO_DEPLOY[@]} -gt 0 ]; then
    echo
    read -p "${CYAN}Do you want to delete the generated YAML files in the '${COMPOSE_DIR}' directory? (y/N): ${NC}" cleanup_choice
    if [[ "$cleanup_choice" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echoinfo "Deleting YAML files..."
    if rm -rf "${COMPOSE_DIR}"; then
        echosuccess "Directory '${COMPOSE_DIR}' and its YAML files deleted."
    else
        echoerror "Failed to delete directory '${COMPOSE_DIR}'."
    fi
    else
    echoinfo "YAML files are kept in the '${COMPOSE_DIR}' directory."
    fi
fi

# --- Simplified Docker Container Status ---
if [ ${#ORDERED_SERVICES_TO_DEPLOY[@]} -gt 0 ]; then
  echo
  echoinfo "--- Simplified Status of Deployed Docker Containers ---"
  for service_name_status in "${ORDERED_SERVICES_TO_DEPLOY[@]}"; do
    # The container name is assumed to be the same as the service name (e.g., Emby, Prowlarr)
    # as container_name is defined this way in the YAML files.
    container_state=$(docker inspect --format='{{.State.Status}}' "${service_name_status}" 2>/dev/null)
    exit_code_inspect=$? # Get the exit code of the docker inspect command

    if [ $exit_code_inspect -eq 0 ]; then # If docker inspect succeeded
      if [ "$container_state" == "running" ]; then
        echo -e "${CYAN}Status for ${service_name_status}:${NC} ${GREEN}SUCCESS (Up)${NC}"
      else
        # Other states (exited, created, restarting, paused, dead) are considered FAILED
        echo -e "${CYAN}Status for ${service_name_status}:${NC} ${RED}FAILED (State: ${container_state})${NC}"
      fi
    else
      # If docker inspect fails, the container is likely not found or another error occurred.
      echo -e "${CYAN}Status for ${service_name_status}:${NC} ${RED}FAILED (Not found or error during inspection)${NC}"
    fi
  done
  echo "---------------------------------------"
fi

echo
echosuccess "--- End of Script ---"
if [ ${#ORDERED_SERVICES_TO_DEPLOY[@]} -gt 0 ]; then
  echoinfo "Configured Docker Compose services have been processed."
  echoinfo "Check the logs of each container if you encounter problems (Example for Watchtower: docker logs Watchtower)."
else
  echoinfo "No services were configured for deployment."
fi