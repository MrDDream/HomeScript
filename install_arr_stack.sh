#!/bin/bash

# Script to create and launch all Docker Compose configurations
# without needing external YAML files, with globalized PUID, PGID, and TZ,
# and Watchtower label enabled for all services.

# --- Prompt for Global Variables ---
echo "--- Global Variables Configuration ---"

# Default values
DEFAULT_GLOBAL_PUID=1000
DEFAULT_GLOBAL_PGID=1000
DEFAULT_GLOBAL_TZ="Europe/Paris"
DEFAULT_APP_DATA_BASE_PATH="/srv/dev-disk-by-uuid-0ce" # MODIFY THIS if necessary for the default value

read -p "Enter Global PUID [${DEFAULT_GLOBAL_PUID}]: " input_puid
GLOBAL_PUID=${input_puid:-$DEFAULT_GLOBAL_PUID}

read -p "Enter Global PGID [${DEFAULT_GLOBAL_PGID}]: " input_pgid
GLOBAL_PGID=${input_pgid:-$DEFAULT_GLOBAL_PGID}

read -p "Enter Global Timezone (TZ) [${DEFAULT_GLOBAL_TZ}]: " input_tz
GLOBAL_TZ=${input_tz:-$DEFAULT_GLOBAL_TZ}

echo "---------------------------------------"
echo "--- Path Configuration ---"

read -p "Enter Base Path for Application Data (APP_DATA_BASE_PATH) [${DEFAULT_APP_DATA_BASE_PATH}]: " input_app_data_base_path
APP_DATA_BASE_PATH=${input_app_data_base_path:-$DEFAULT_APP_DATA_BASE_PATH}

# --- Configuration Paths (derived from APP_DATA_BASE_PATH) ---
# These paths are defined AFTER APP_DATA_BASE_PATH is set.
# User will not be prompted for these individually unless further specified.
CONFIG_EMBY_PATH="${APP_DATA_BASE_PATH}/Configurations/EmbyServer"
CONFIG_JELLYSEERR_PATH="${APP_DATA_BASE_PATH}/Configurations/Jellyseerr"
CONFIG_LIDARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Lidarr"
CONFIG_PROWLARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Prowlarr"
CONFIG_QBITTORRENT_PATH="${APP_DATA_BASE_PATH}/Configurations/QbitTorrent"
CONFIG_RADARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Radarr"
CONFIG_SONARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Sonarr"

# --- Prompt for Media Paths ---
# Default media paths are suggested based on APP_DATA_BASE_PATH, but can be overridden.
DEFAULT_MEDIA_TV_SHOWS_PATH="${APP_DATA_BASE_PATH}/Tvshows"
read -p "Enter path for TV Shows (MEDIA_TV_SHOWS_PATH) [${DEFAULT_MEDIA_TV_SHOWS_PATH}]: " input_media_tv
MEDIA_TV_SHOWS_PATH=${input_media_tv:-$DEFAULT_MEDIA_TV_SHOWS_PATH}

DEFAULT_MEDIA_MOVIES_PATH="${APP_DATA_BASE_PATH}/Movies"
read -p "Enter path for Movies (MEDIA_MOVIES_PATH) [${DEFAULT_MEDIA_MOVIES_PATH}]: " input_media_movies
MEDIA_MOVIES_PATH=${input_media_movies:-$DEFAULT_MEDIA_MOVIES_PATH}

DEFAULT_MEDIA_MUSIC_PATH="${APP_DATA_BASE_PATH}/Music"
read -p "Enter path for Music (MEDIA_MUSIC_PATH) [${DEFAULT_MEDIA_MUSIC_PATH}]: " input_media_music
MEDIA_MUSIC_PATH=${input_media_music:-$DEFAULT_MEDIA_MUSIC_PATH}

DEFAULT_DOWNLOADS_PATH="${APP_DATA_BASE_PATH}/Torrents"
read -p "Enter path for Downloads (DOWNLOADS_PATH) [${DEFAULT_DOWNLOADS_PATH}]: " input_downloads
DOWNLOADS_PATH=${input_downloads:-$DEFAULT_DOWNLOADS_PATH}

echo "---------------------------------------"
echo ""

# --- Create compose subdirectory ---
COMPOSE_DIR="compose"
echo "Ensuring '${COMPOSE_DIR}' directory exists..."
mkdir -p "${COMPOSE_DIR}"
echo "---------------------------------------"

echo "--- Global Values Used ---"
echo "Global PUID: ${GLOBAL_PUID}"
echo "Global PGID: ${GLOBAL_PGID}"
echo "Global TZ: ${GLOBAL_TZ}"
echo "---------------------------------------"
echo "--- Configuration Paths Used ---"
echo "Application Data Base Path: ${APP_DATA_BASE_PATH}"
echo "Emby Config Path: ${CONFIG_EMBY_PATH}"
echo "Jellyseerr Config Path: ${CONFIG_JELLYSEERR_PATH}"
echo "Lidarr Config Path: ${CONFIG_LIDARR_PATH}"
echo "Prowlarr Config Path: ${CONFIG_PROWLARR_PATH}"
echo "QbitTorrent Config Path: ${CONFIG_QBITTORRENT_PATH}"
echo "Radarr Config Path: ${CONFIG_RADARR_PATH}"
echo "Sonarr Config Path: ${CONFIG_SONARR_PATH}"
echo "---------------------------------------"
echo "--- Media Paths Used ---"
echo "Media TV Shows Path: ${MEDIA_TV_SHOWS_PATH}"
echo "Media Movies Path: ${MEDIA_MOVIES_PATH}"
echo "Media Music Path: ${MEDIA_MUSIC_PATH}"
echo "Downloads Path: ${DOWNLOADS_PATH}"
echo "---------------------------------------"
echo ""

# Make sure Docker and Docker Compose (or 'docker compose') are installed.

# --- Byparr Configuration ---
echo "Creating ${COMPOSE_DIR}/byparr.yaml and launching the Byparr service..."
cat << EOF > "${COMPOSE_DIR}/byparr.yaml"
---
version: "2.1"
services:
  Byparr:
    image: ghcr.io/thephaseless/byparr:latest
    container_name: Byparr
    labels:
      - com.centurylinklabs.watchtower.enable=true
    environment:
      - LOG_LEVEL=\${LOG_LEVEL:-info} # Docker Compose will handle this variable
      - LOG_HTML=\${LOG_HTML:-false} # Docker Compose will handle this variable
      - CAPTCHA_SOLVER=\${CAPTCHA_SOLVER:-none} # Docker Compose will handle this variable
      - TZ=${GLOBAL_TZ}
    ports:
      - 8191:8191
    restart: unless-stopped
EOF
docker-compose -f "${COMPOSE_DIR}/byparr.yaml" up -d
# rm "${COMPOSE_DIR}/byparr.yaml" # Uncomment to delete the file after use

# --- Emby Configuration ---
echo "Creating ${COMPOSE_DIR}/emby.yaml and launching the Emby service..."
cat << EOF > "${COMPOSE_DIR}/emby.yaml"
---
version: "2.3"
services:
  emby:
    image: emby/embyserver:latest
    container_name: EmbyServer
    labels:
      - com.centurylinklabs.watchtower.enable=true
    environment:
      - PUID=${GLOBAL_PUID}
      - PGID=${GLOBAL_PGID}
      - TZ=${GLOBAL_TZ}
    volumes:
      - ${CONFIG_EMBY_PATH}:/config # Configuration directory
      - ${MEDIA_TV_SHOWS_PATH}:/mnt/tvshows # Media directory for TV Shows
      - ${MEDIA_MOVIES_PATH}:/mnt/movies # Media directory for Movies
    ports:
      - 8096:8096 # HTTP port
      - 8920:8920 # HTTPS port
    restart: on-failure
EOF
docker-compose -f "${COMPOSE_DIR}/emby.yaml" up -d
# rm "${COMPOSE_DIR}/emby.yaml" # Uncomment to delete the file after use

# --- Jellyseerr Configuration ---
echo "Creating ${COMPOSE_DIR}/jellyseer.yaml and launching the Jellyseerr service..."
cat << EOF > "${COMPOSE_DIR}/jellyseer.yaml"
---
services:
  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: Jellyseerr
    labels:
      - com.centurylinklabs.watchtower.enable=true
    environment:
      - LOG_LEVEL=debug
      - TZ=${GLOBAL_TZ}
      - PORT=5055 #optional
      - JELLYFIN_TYPE=emby
    ports:
      - 5055:5055
    volumes:
      - ${CONFIG_JELLYSEERR_PATH}:/app/config
    restart: unless-stopped
EOF
docker-compose -f "${COMPOSE_DIR}/jellyseer.yaml" up -d
# rm "${COMPOSE_DIR}/jellyseer.yaml" # Uncomment to delete the file after use

# --- Lidarr Configuration ---
echo "Creating ${COMPOSE_DIR}/lidarr.yaml and launching the Lidarr service..."
cat << EOF > "${COMPOSE_DIR}/lidarr.yaml"
services:
  lidarr:
    image: ghcr.io/hotio/lidarr:latest
    container_name: Lidarr
    labels:
      - com.centurylinklabs.watchtower.enable=true
    ports:
      - "8686:8686"
    environment:
      - PUID=${GLOBAL_PUID}
      - PGID=${GLOBAL_PGID}
      - UMASK=002 # You can also globalize UMASK if necessary
      - TZ=${GLOBAL_TZ}
    volumes:
      - ${CONFIG_LIDARR_PATH}:/config
      - ${MEDIA_MUSIC_PATH}:/data # This is where Lidarr will manage music files
    restart: unless-stopped # Added restart policy for consistency
EOF
docker-compose -f "${COMPOSE_DIR}/lidarr.yaml" up -d
# rm "${COMPOSE_DIR}/lidarr.yaml" # Uncomment to delete the file after use

# --- Prowlarr Configuration ---
echo "Creating ${COMPOSE_DIR}/prowlarr.yaml and launching the Prowlarr service..."
cat << EOF > "${COMPOSE_DIR}/prowlarr.yaml"
---
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
      - 9696:9696
    restart: unless-stopped
EOF
docker-compose -f "${COMPOSE_DIR}/prowlarr.yaml" up -d
# rm "${COMPOSE_DIR}/prowlarr.yaml" # Uncomment to delete the file after use

# --- QbitTorrent Configuration ---
echo "Creating ${COMPOSE_DIR}/qbitorrent.yaml and launching the QbitTorrent service..."
cat << EOF > "${COMPOSE_DIR}/qbitorrent.yaml"
---
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
      - 8080:8080
      - 6881:6881
      - 6881:6881/udp
    restart: unless-stopped
EOF
docker-compose -f "${COMPOSE_DIR}/qbitorrent.yaml" up -d
# rm "${COMPOSE_DIR}/qbitorrent.yaml" # Uncomment to delete the file after use

# --- Radarr Configuration ---
# Note: MEDIA_ANIMATIONS_PATH and TMM_SCRIPTS_PATH are used below.
# Ensure they are defined in the "Global Volume Paths" section or as environment variables if you uncomment them.
echo "Creating ${COMPOSE_DIR}/radarr.yaml and launching the Radarr service..."
cat << EOF > "${COMPOSE_DIR}/radarr.yaml"
---
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
      # - ${MEDIA_ANIMATIONS_PATH}:/animations # Uncomment if MEDIA_ANIMATIONS_PATH is defined
      - ${DOWNLOADS_PATH}:/downloads
      # - ${TMM_SCRIPTS_PATH}:/scripts # Uncomment if TMM_SCRIPTS_PATH is defined. chmod +x /scripts/update_movie.sh && chmod 755 /scripts
    ports:
      - 7878:7878
    restart: unless-stopped
EOF
docker-compose -f "${COMPOSE_DIR}/radarr.yaml" up -d
# rm "${COMPOSE_DIR}/radarr.yaml" # Uncomment to delete the file after use

# --- Sonarr Configuration ---
# Note: TMM_SCRIPTS_PATH is used below.
# Ensure it is defined in the "Global Volume Paths" section or as an environment variable if you uncomment it.
echo "Creating ${COMPOSE_DIR}/sonarr.yaml and launching the Sonarr service..."
cat << EOF > "${COMPOSE_DIR}/sonarr.yaml"
---
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
      # - ${TMM_SCRIPTS_PATH}:/scripts # Uncomment if TMM_SCRIPTS_PATH is defined. chmod +x /scripts/update_tvshow.sh && chmod 755 /scripts
    ports:
      - 8989:8989
    restart: unless-stopped
EOF
docker-compose -f "${COMPOSE_DIR}/sonarr.yaml" up -d
# rm "${COMPOSE_DIR}/sonarr.yaml" # Uncomment to delete the file after use

# --- Watchtower Configuration ---
echo "Creating ${COMPOSE_DIR}/watchtower.yaml and launching the Watchtower service..."
cat << EOF > "${COMPOSE_DIR}/watchtower.yaml"
---
version: "3.8" # Using a common recent version for Docker Compose features
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: Watchtower # Capitalized for consistency with other container names in this script
    environment:
      - TZ=${GLOBAL_TZ}
      # - WATCHTOWER_CLEANUP=true  # Uncomment to remove old images after update
      # - WATCHTOWER_SCHEDULE="0 0 4 * * *" # Uncomment to specify a cron schedule (e.g., 4 AM daily)
                                          # Default: checks every 24 hours from when it was started.
                                          # Ensure your TZ is correct for cron interpretation if not UTC.
      # - WATCHTOWER_POLL_INTERVAL=3600 # Uncomment to change polling interval (in seconds, e.g., 3600 for 1 hour)
                                        # Default is 86400 (24 hours).
                                        # Use this OR WATCHTOWER_SCHEDULE, not both typically.
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # Essential for Watchtower to interact with Docker
    restart: unless-stopped
    # No 'com.centurylinklabs.watchtower.enable=true' label is strictly needed for Watchtower to update itself,
    # as it updates itself by default unless configured otherwise.
    # It will monitor all other containers that DO have this label set to true.
EOF
docker-compose -f "${COMPOSE_DIR}/watchtower.yaml" up -d
# rm "${COMPOSE_DIR}/watchtower.yaml" # Uncomment to delete the file after use

echo ""
echo "--- End of Script ---"
echo "All configured Docker Compose services have been launched."
echo "YAML files were created in the '${COMPOSE_DIR}' subdirectory."
echo "Watchtower has also been started and will monitor labeled containers for updates."
echo "Note: Temporary YAML files were created in '${COMPOSE_DIR}' and then (if uncommented) deleted."
echo "Check the logs of each container if you encounter problems (e.g., docker logs Watchtower)."