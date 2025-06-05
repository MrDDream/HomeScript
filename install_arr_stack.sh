#!/bin/bash

# Script to create and launch all Docker Compose configurations
# without needing external YAML files, with globalized PUID, PGID, and TZ,
# and Watchtower label enabled for all services.

# --- Global Variables ---
# Modify these values according to your needs.
# PUID (User ID) and PGID (Group ID) are often 1000 for a standard user,
# or 0 for root (although 0 is generally discouraged for security reasons
# if mapped volumes are accessible by other non-root users on the host).
# Consult the documentation for each image for specific recommendations.
GLOBAL_PUID=1000
GLOBAL_PGID=1000
GLOBAL_TZ="Europe/Paris" # Example: "America/New_York", "Asia/Tokyo", "Etc/UTC"

# --- Global Volume Paths ---
# Modify these paths according to your directory structure.
# It's recommended to use absolute paths.

# General base path for your Docker configurations and data.
# All other paths can be relative to this, or defined absolutely.
# Example: "/srv/your_drive/docker_data" or "/mnt/storage/docker"
# If using the UUID path from the original script, ensure this drive is always mounted at the same point.
APP_DATA_BASE_PATH="/srv/dev-disk-by-uuid-0ce" # MODIFY THIS TO YOUR MAIN DATA DIRECTORY

# Configuration Paths
# For Emby, original was /path/to/programdata. Adjust if ${APP_DATA_BASE_PATH}/emby_config is not suitable.
CONFIG_EMBY_PATH="${APP_DATA_BASE_PATH}/Configurations/EmbyServer"
CONFIG_JELLYSEERR_PATH="${APP_DATA_BASE_PATH}/Configurations/Jellyseerr"
# For Lidarr, original was /<host_folder_config>. Adjust if ${APP_DATA_BASE_PATH}/0.Configurations/Lidarr is not suitable.
CONFIG_LIDARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Lidarr"
CONFIG_PROWLARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Prowlarr"
CONFIG_QBITTORRENT_PATH="${APP_DATA_BASE_PATH}/Configurations/QbitTorrent"
CONFIG_RADARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Radarr"
CONFIG_SONARR_PATH="${APP_DATA_BASE_PATH}/Configurations/Sonarr"

# Media Paths
# For Emby TV, original was /path/to/tvshows.
MEDIA_TV_SHOWS_PATH="${APP_DATA_BASE_PATH}/Tvshows"
# For Emby Movies, original was /path/to/movies.
MEDIA_MOVIES_PATH="${APP_DATA_BASE_PATH}/Movies"
# For Lidarr music, original was /<host_folder_data>. This path will be mapped to /data in Lidarr.
MEDIA_MUSIC_PATH="${APP_DATA_BASE_PATH}/Music" # Or, e.g., "${APP_DATA_BASE_PATH}/Music"
# Downloads Path
DOWNLOADS_PATH="${APP_DATA_BASE_PATH}/Torrents"


echo "--- Using Global Values ---"
echo "Global PUID: ${GLOBAL_PUID}"
echo "Global PGID: ${GLOBAL_PGID}"
echo "Global TZ: ${GLOBAL_TZ}"
echo "---------------------------------------"
echo "--- Using Global Volume Paths ---"
echo "App Data Base Path: ${APP_DATA_BASE_PATH}"
echo "Emby Config Path: ${CONFIG_EMBY_PATH}"
echo "Jellyseerr Config Path: ${CONFIG_JELLYSEERR_PATH}"
echo "Lidarr Config Path: ${CONFIG_LIDARR_PATH}"
echo "Prowlarr Config Path: ${CONFIG_PROWLARR_PATH}"
echo "QbitTorrent Config Path: ${CONFIG_QBITTORRENT_PATH}"
echo "Radarr Config Path: ${CONFIG_RADARR_PATH}"
echo "Sonarr Config Path: ${CONFIG_SONARR_PATH}"
echo "Media TV Shows Path: ${MEDIA_TV_SHOWS_PATH}"
echo "Media Movies Path: ${MEDIA_MOVIES_PATH}"
echo "Media Music Path: ${MEDIA_MUSIC_PATH}"
echo "Downloads Path: ${DOWNLOADS_PATH}"
echo "---------------------------------------"
echo ""

# Make sure Docker and Docker Compose (or 'docker compose') are installed.

# --- Byparr Configuration ---
echo "Creating byparr.yaml and launching the Byparr service..."
cat << EOF > byparr.yaml
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
docker-compose -f byparr.yaml up -d
# rm byparr.yaml # Uncomment to delete the file after use

# --- Emby Configuration ---
echo "Creating emby.yaml and launching the Emby service..."
cat << EOF > emby.yaml
---
version: "2.3"
services:
  emby:
    image: emby/embyserver:latest
    container_name: EmbyServer
    labels:
      - com.centurylinklabs.watchtower.enable=true
    runtime: nvidia # Expose NVIDIA GPUs
    network_mode: host # Enable DLNA and Wake-on-Lan
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
docker-compose -f emby.yaml up -d
# rm emby.yaml # Uncomment to delete the file after use

# --- Jellyseerr Configuration ---
echo "Creating jellyseer.yaml and launching the Jellyseerr service..."
cat << EOF > jellyseer.yaml
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
docker-compose -f jellyseer.yaml up -d
# rm jellyseer.yaml # Uncomment to delete the file after use

# --- Lidarr Configuration ---
echo "Creating lidarr.yaml and launching the Lidarr service..."
cat << EOF > lidarr.yaml
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
EOF
docker-compose -f lidarr.yaml up -d
# rm lidarr.yaml # Uncomment to delete the file after use

# --- Prowlarr Configuration ---
echo "Creating prowlarr.yaml and launching the Prowlarr service..."
cat << EOF > prowlarr.yaml
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
docker-compose -f prowlarr.yaml up -d
# rm prowlarr.yaml # Uncomment to delete the file after use

# --- QbitTorrent Configuration ---
echo "Creating qbitorrent.yaml and launching the QbitTorrent service..."
cat << EOF > qbitorrent.yaml
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
docker-compose -f qbitorrent.yaml up -d
# rm qbitorrent.yaml # Uncomment to delete the file after use

# --- Radarr Configuration ---
echo "Creating radarr.yaml and launching the Radarr service..."
cat << EOF > radarr.yaml
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
      - ${MEDIA_ANIMATIONS_PATH}:/animations
      - ${DOWNLOADS_PATH}:/downloads
      - ${TMM_SCRIPTS_PATH}:/scripts #chmod +x /scripts/update_movie.sh && chmod 755 /scripts
    ports:
      - 7878:7878
    restart: unless-stopped
EOF
docker-compose -f radarr.yaml up -d
# rm radarr.yaml # Uncomment to delete the file after use

# --- Sonarr Configuration ---
echo "Creating sonarr.yaml and launching the Sonarr service..."
cat << EOF > sonarr.yaml
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
      - ${TMM_SCRIPTS_PATH}:/scripts #chmod +x /scripts/update_tvshow.sh && chmod 755 /scripts
    ports:
      - 8989:8989
    restart: unless-stopped
EOF
docker-compose -f sonarr.yaml up -d
# rm sonarr.yaml # Uncomment to delete the file after use

echo ""
echo "--- End of Script ---"
echo "All configured Docker Compose services have been launched with the Watchtower label."
echo "Note: Temporary YAML files were created and then (if uncommented) deleted."
echo "Check the logs of each container if you encounter problems (e.g., docker logs Byparr)."