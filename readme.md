
# HomeScript

A collection of shell scripts to automate common tasks, primarily focused on media server setup and management.

## Features

- 🔥 Automated installation of Docker and Portainer.
- 🚀 Streamlined setup of *arr stack applications (Sonarr, Radarr, etc.).
- 🛠️ Simplified Zsh configuration with Oh My Zsh.
- 📦 Utilities for updating applications and managing tinyMediaManager.

## Tech Stack

| Category | Technologies |
|----------|-------------|
| OS       | Debian/Ubuntu |
| Scripting | Bash          |
| Containerization | Docker |
| Shell      | Zsh, Oh My Zsh |

## Installation & Setup

### Prerequisites

- A Debian/Ubuntu-based system.
- Root or sudo privileges.
- `apt` package manager.
- Basic understanding of shell scripting.

### Step-by-step Installation

1.  **Clone the repository:**

    ```bash
    git clone <repository_url>
    cd HomeScript
    ```

2.  **Install Docker and Portainer:**

    ```bash
    chmod +x install_docker_portainer.sh
    ./install_docker_portainer.sh
    ```
    This script will prompt you to install missing dependencies if any are detected.

3.  **Install the *arr stack:**

    ```bash
    chmod +x install_arr_stack.sh
    ./install_arr_stack.sh
    ```
    Follow the prompts to configure your desired applications.

4.  **Install Zsh and configure Oh My Zsh:**

    ```bash
    chmod +x install_zsh.sh
    ./install_zsh.sh
    ```
    This script sets Zsh as the default shell and configures Oh My Zsh with a personalized `.zshrc` file.

5. **Update Applications**
   ```bash
   chmod +x update_app.sh
   ./update_app.sh
   ```
   This script updates the package list and upgrades installed packages.

### Environment Variables

The `install_arr_stack.sh` script utilizes several environment variables to configure the *arr stack applications. These variables are set interactively during the script execution.

-   `GLOBAL_PUID`: User ID for the Docker containers.
-   `GLOBAL_PGID`: Group ID for the Docker containers.
-   `GLOBAL_TZ`: Timezone for the Docker containers.
-   `APP_DATA_BASE_PATH`: Base path for application data.
-   `MEDIA_TV_SHOWS_PATH`: Path for TV shows.
-   `MEDIA_MOVIES_PATH`: Path for Movies.
-   `MEDIA_MUSIC_PATH`: Path for Music.
-   `DOWNLOADS_PATH`: Path for Downloads.

The `tinyMediaManager/update_movie.sh` and `tinyMediaManager/update_tvshow.sh` scripts also use environment variables.

- `TMM_URL`: The URL of your tinyMediaManager instance.
- `TMM_API_KEY`: Your tinyMediaManager API key.
- `GOTIFY_URL`: The URL of your Gotify server instance.
- `GOTIFY_API_KEY`: Your Gotify Application key.

## Usage

### Running Scripts

Each script is designed to be executed directly from the command line. Ensure the script has execute permissions before running.

### Example: Updating tinyMediaManager Movies

1.  Modify the `tinyMediaManager/update_movie.sh` script to match your tinyMediaManager and Gotify configuration.

2.  Run the script:

    ```bash
    chmod +x tinyMediaManager/update_movie.sh
    ./tinyMediaManager/update_movie.sh
    ```

## Project Structure

```
HomeScript/
├── .zshrc
├── install_arr_stack.sh
├── install_docker_portainer.sh
├── install_zsh.sh
├── readme.md
├── tinyMediaManager/
│   ├── update_movie.sh
│   └── update_tvshow.sh
└── update_app.sh
```

## API Documentation

The `tinyMediaManager/update_movie.sh` and `tinyMediaManager/update_tvshow.sh` scripts interact with the tinyMediaManager API. Refer to the tinyMediaManager documentation for details on the available API endpoints and parameters.

## Screenshots

<!-- Add screenshots here -->

## Contributing

1.  Fork the repository.
2.  Create a new branch for your feature or bug fix.
3.  Make your changes and commit them with descriptive messages.
4.  Submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

MrDDream - *add contact info here*

## Thanks + Attribution

Thanks to the open-source community for providing the tools and resources that made this project possible.

This README was generated using [GitRead](https://git-read.vercel.app)
```
