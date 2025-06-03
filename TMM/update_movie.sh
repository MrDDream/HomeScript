#!/bin/bash

# --- Configuration ---
# Here, we define the variables that will be used throughout the script.
# It is recommended to modify these values to match your own setup.
# ---

# Set the URL for your tinyMediaManager instance
TMM_URL="http://192.168.1.1:4000"
# Set your tinyMediaManager API Key (found in Settings > General > System > HTTP API)
TMM_API_KEY="f3d9e1a0-bc47-4b2e-98a7-8e4b2a1d0c6f"

# Set the URL for your Gotify server instance
GOTIFY_URL="http://192.168.1.1:3006"
# Set your Gotify Application Key (or Client Key)
GOTIFY_API_KEY="xQz7YtLp1nGvEJq"

# --- tinyMediaManager Movie Actions ---
# This section contains the commands to interact with the tinyMediaManager API
# to manage your movie library.
# ---

# Action: Update all existing movies in the tinyMediaManager library.
# This typically refreshes metadata from NFO files and checks for new artwork/files in existing movie folders.
echo "Starting: Update all movies"
curl --location "${TMM_URL}/api/movie" \
--header "api-key: ${TMM_API_KEY}" \
--header 'Content-Type: application/json' \
--data '{
    "action": "update",
    "scope": {
        "name": "all"
    }
}'
echo -e "\nUpdate all movies command sent.\n"

# Action: Scrape unscraped movies.
# This will fetch metadata and artwork from online sources for movies that haven't been scraped yet.
echo "Starting: Scrape unscraped movies"
curl --location "${TMM_URL}/api/movie" \
--header "api-key: ${TMM_API_KEY}" \
--header 'Content-Type: application/json' \
--data '{
    "action": "scrape",
    "scope": {
        "name": "unscraped"
    }
}'
echo -e "\nScrape unscraped movies command sent.\n"

# Action: Rename all movies.
# This will rename movie files and folders according to your tinyMediaManager Naming settings.
echo "Starting: Rename all movies"
curl --location "${TMM_URL}/api/movie" \
--header "api-key: ${TMM_API_KEY}" \
--header 'Content-Type: application/json' \
--data '{
    "action": "rename",
    "scope": {
        "name": "all"
    }
}'
echo -e "\nRename all movies command sent.\n"

# --- Notification ---
# This section sends a notification via Gotify to indicate that the script
# has completed its execution.
# ---
echo "Sending Gotify notification"
curl --location "${GOTIFY_URL}/message" \
--header "X-Gotify-Key: ${GOTIFY_API_KEY}" \
--header 'Content-Type: application/json' \
--data '{
    "title": "Movie Update Script Finished",
    "message": "The tinyMediaManager movie update script has completed its tasks.",
    "priority": 5
}'
echo -e "\nGotify notification sent."
echo "Script finished."