#!/bin/bash

# --- Configuration ---
# Here, we define the variables that will be used throughout the script.
# It is recommended to modify these values to match your own setup.
# ---

# Set the URL for your tinyMediaManager instance (for TV Shows)
TMM_TV_URL="http://192.168.1.1:4000"
# Set your tinyMediaManager API Key (found in Settings > General > System > HTTP API)
TMM_TV_API_KEY="f3d9e1a0-bc47-4b2e-98a7-8e4b2a1d0c6f"

# Set the URL for your Gotify server instance
GOTIFY_URL="http://192.168.1.1:3006"
# Set your Gotify Application Key (or Client Key)
GOTIFY_API_KEY="xQz7YtLp1nGvEJq"

# --- tinyMediaManager TV Show Actions ---
# This section contains the commands to interact with the tinyMediaManager API
# to manage your TV show library.
# ---

# Action: Update all existing TV shows in the tinyMediaManager library.
# This typically refreshes metadata from NFO files and checks for new artwork/files in existing TV show folders.
echo "Starting: Update all TV shows"
curl --location "${TMM_TV_URL}/api/tvshow" \
--header "api-key: ${TMM_TV_API_KEY}" \
--header 'Content-Type: application/json' \
--data '{
    "action": "update",
    "scope": {
        "name": "all"
    }
}'
echo -e "\nUpdate all TV shows command sent.\n"

# Action: Scrape unscraped TV shows.
# This will fetch metadata and artwork from online sources for TV shows (and their episodes)
# that haven't been scraped yet.
echo "Starting: Scrape unscraped TV shows"
curl --location "${TMM_TV_URL}/api/tvshow" \
--header "api-key: ${TMM_TV_API_KEY}" \
--header 'Content-Type: application/json' \
--data '{
    "action": "scrape",
    "scope": {
        "name": "unscraped"
    }
}'
echo -e "\nScrape unscraped TV shows command sent.\n"

# Action: Rename all TV shows.
# This will rename TV show folders, season folders, and episode files
# according to your tinyMediaManager Naming settings.
echo "Starting: Rename all TV shows"
curl --location "${TMM_TV_URL}/api/tvshow" \
--header "api-key: ${TMM_TV_API_KEY}" \
--header 'Content-Type: application/json' \
--data '{
    "action": "rename",
    "scope": {
        "name": "all"
    }
}'
echo -e "\nRename all TV shows command sent.\n"

# --- Notification ---
# This section sends a notification via Gotify to indicate that the script
# has completed its execution.
# ---
echo "Sending Gotify notification"
curl --location "${GOTIFY_URL}/message" \
--header "X-Gotify-Key: ${GOTIFY_API_KEY}" \
--header 'Content-Type: application/json' \
--data '{
    "title": "TV Show Update Script Finished",
    "message": "The tinyMediaManager TV show update script has completed its tasks.",
    "priority": 5
}'
echo -e "\nGotify notification sent."
echo "Script finished."