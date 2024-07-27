#!/usr/bin/env bash
#                       calibre-portable-mac.sh
#                       Version: 1.0.1
#                       ¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬
#
# Shell script to manage a portable Calibre configuration on macOS.
# This script provides explicit control over the location of:
#  - Calibre app location
#  - Calibre library files
#  - Calibre config files
#  - Calibre metadata database
#  - Calibre temporary files
#
# Use cases:
#  - Run a "portable Calibre" from a USB stick.
#  - Network installation with a local metadata database for performance,
#    and books stored on a network share.
#  - Local installation using customized settings.
#
# Features:
#  - Detailed logging and debugging options.
#  - Dry-run mode to preview changes without applying them.
#
# More information on the environment variables used by Calibre can be found at:
# https://manual.calibre-ebook.com/customize.html#environment-variables
#
# Options:
#  -u, --upgrade-install   Upgrade or install the portable Calibre binaries
#  -h, --help              Show usage message and exit
#  -v, --verbose           Enable detailed logging of the script's actions
#  -V, --very-verbose      Enable highly detailed logging, including variable values and detailed descriptions of each action
#  -d, --debug             Step through the script interactively, allowing the user to continue or quit at each step
#  -r, --dry-run           Output the changes that would be made without actually making them
#  -c, --create-launcher   Create a command launcher for starting Calibre
#  -s, --silent            Suppress output except for necessary prompts
#  -S, --very-silent       Suppress all output and prompts

set -euo pipefail  # Enable strict mode

# Variables for logging levels and modes
log_verbose=0
log_dry_run=0
log_debug=0
log_silent=0
log_very_silent=0

# Initialize configuration variables
CALIBRE_CONFIG_DIRECTORY=""
CALIBRE_LIBRARY_DIRECTORIES=()
CALIBRE_LIBRARY_DIRECTORY=""
CALIBRE_OVERRIDE_DATABASE_PATH=""
CALIBRE_BINARY_DIRECTORY=""
CALIBRE_TEMP_DIR=""
CALIBRE_OVERRIDE_LANG=""
calibre_no_confirm_start=0
calibre_no_cleanup=0

# Function to log messages
log() {
    if [[ $log_verbose -ge 1 && $log_silent -eq 0 ]]; then
        echo "$@"
    fi
}

# Function to log detailed debug messages
log_debug() {
    if [[ $log_verbose -ge 2 && $log_silent -eq 0 ]]; then
        echo "$@"
    fi
}

# Function to handle dry-run mode
log_dry_run() {
    if [[ $log_dry_run -eq 1 ]]; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

# Function for interactive debugging
debug_step() {
    if [[ $log_debug -eq 1 ]]; then
        read -rp "Continue? (Y/n) " choice
        case "$choice" in 
            y|Y|"" ) echo "Continuing...";;
            * ) echo "Exiting."; exit;;
        esac
    fi
}

# Cleanup function to handle exit
cleanup() {
    log_debug "Starting cleanup function"
    if [[ "${calibre_no_cleanup}" -eq 1 ]]; then
        log_debug "Skipping cleanup as calibre_no_cleanup is set to 1"
        return
    fi
    log_debug "Cleanup function completed"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Function to display usage information
usage() {
    cat <<-_EOF_
        Usage: calibre-portable-mac.sh [OPTIONS]
        Run a portable instance of Calibre.

        OPTIONS
          -u, --upgrade-install     Upgrade or install the portable Calibre binaries
          -h, --help                Show this usage message then exit
          -v, --verbose             Enable detailed logging of the script's actions
          -V, --very-verbose        Enable highly detailed logging, including variable values and detailed descriptions of each action
          -d, --debug               Step through the script interactively, allowing the user to continue or quit at each step
          -r, --dry-run             Output the changes that would be made without actually making them
          -s, --silent              Suppress output except for necessary prompts
          -S, --very-silent         Suppress all output and prompts
          -c, --create-launcher     Create a command launcher for starting Calibre
_EOF_
}

# Function to upgrade or install Calibre on macOS
upgrade_calibre() {
    log_debug "Starting upgrade_calibre function"
    local temp_dir dmg_path latest_dmg_url volume_path temp_calibre_app_path

    if [[ $log_dry_run -eq 1 ]]; then
        echo "[DRY-RUN] Create a temporary directory for download"
        echo "[DRY-RUN] Download the latest Calibre DMG"
        echo "[DRY-RUN] Mount the DMG and copy calibre.app"
        echo "[DRY-RUN] Move the app"
        echo "[DRY-RUN] Unmount the DMG and clean up"
        return
    fi

    # Making the temp dmg download directory
    temp_dir="$(pwd)/calibre_temp"
    log_debug "TEMP_DIR=${temp_dir}"
    log_dry_run mkdir -p "$temp_dir"
    debug_step

    # Getting the current dmg download url
    dmg_path="$temp_dir/calibre-latest.dmg"
    log_debug "DMG_PATH=${dmg_path}"
    latest_dmg_url=$(curl -s https://calibre-ebook.com/download_osx | grep -o 'https://[^"]*\.dmg' | head -1)
    log_debug "LATEST_DMG_URL=${latest_dmg_url}"
    debug_step

    if [[ -z "$latest_dmg_url" ]]; then
        echo "Failed to retrieve the latest Calibre DMG URL."
        log_dry_run rm -rf "$temp_dir"
        exit 1
    fi

    # Downloading the current dmg
    curl_command=("curl" "-L" "-o" "$dmg_path" "$latest_dmg_url")
    log_debug "CURL_COMMAND=${curl_command[*]}"
    debug_step
    log_dry_run "${curl_command[@]}"
    if [[ $? -ne 0 || ! -f "$dmg_path" ]]; then
        echo "Failed to download Calibre DMG."
        log_dry_run rm -rf "$temp_dir"
        exit 1
    fi

    # Mounting the dmg
    volume_path=$(hdiutil attach "$dmg_path" | grep "/Volumes/" | awk '{print $3}')
    log_debug "VOLUME_PATH=${volume_path}"
    debug_step

    if [[ -z "$volume_path" ]]; then
        echo "Failed to mount Calibre DMG."
        log_dry_run rm -rf "$temp_dir"
        exit 1
    fi

    if [[ -d "$volume_path/calibre.app" ]]; then
        temp_calibre_app_path="$temp_dir/calibre.app"
        # Copying the calibre.app from the mounted dmg to the temp directory
        cp_command=("ditto" "$volume_path/calibre.app" "$temp_calibre_app_path")
        log_debug "CP_COMMAND=${cp_command[*]}"
        debug_step
        log_dry_run "${cp_command[@]}"

        log_dry_run rm -rf "${CALIBRE_BINARY_DIRECTORY}/calibre.app"
        move_calibre_app "$temp_calibre_app_path"
        echo "Calibre has been upgraded/installed successfully."

        # Unmounting the dmg
        log_dry_run hdiutil detach "$volume_path"
    else
        echo "Failed to find calibre.app in the mounted DMG."
        log_dry_run hdiutil detach "$volume_path"
        log_dry_run rm -rf "$temp_dir"
        exit 1
    fi

    # Removing the temporary directory
    log_dry_run rm -rf "$temp_dir"
    log_debug "upgrade_calibre function completed"
}

# Function to create command launcher
create_command_launcher() {
    log_debug "Starting create_command_launcher function"
    if [[ $log_dry_run -eq 1 ]]; then
        echo "[DRY-RUN] cat <<-_EOF_ > \"$(pwd)/Calibre Portable Mac.command\""
        echo "[DRY-RUN] #!/usr/bin/env bash"
        echo "[DRY-RUN] source \"$(pwd)/calibre-portable.conf\""
        echo "[DRY-RUN] nohup \"$(pwd)/calibre-portable-mac.sh\" &>/dev/null &"
        echo "[DRY-RUN] _EOF_"
        echo "[DRY-RUN] chmod +x \"$(pwd)/Calibre Portable Mac.command\""
    else
        cat <<-_EOF_ > "$(pwd)/Calibre Portable Mac.command"
#!/usr/bin/env bash
source "$(pwd)/calibre-portable.conf"
nohup "$(pwd)/calibre-portable-mac.sh" &>/dev/null &
_EOF_
        chmod +x "$(pwd)/Calibre Portable Mac.command"
        echo "Created 'Calibre Portable Mac.command' launcher."
    fi
    log_debug "create_command_launcher function completed"
}

# Function to move calibre.app to the desired directory
move_calibre_app() {
    local temp_calibre_app_path="${1}"
    read -rp "Would you like to create the 'CalibreBin' directory and move 'calibre.app' there? (Y/n) " choice
    choice="${choice:-y}"
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        CALIBRE_BINARY_DIRECTORY="$(pwd)/CalibreBin"
        if [[ ! -d "$CALIBRE_BINARY_DIRECTORY" ]]; then
            log_dry_run mkdir -p "$CALIBRE_BINARY_DIRECTORY"
        fi
        log_dry_run mv "$temp_calibre_app_path" "$CALIBRE_BINARY_DIRECTORY/calibre.app"
        log_dry_run chmod 755 "$CALIBRE_BINARY_DIRECTORY"
        echo "Moved 'calibre.app' to 'CalibreBin' directory."
    else
        CALIBRE_BINARY_DIRECTORY="$(pwd)"
        log_dry_run mv "$temp_calibre_app_path" "$CALIBRE_BINARY_DIRECTORY/calibre.app"
        echo "Moved 'calibre.app' to the current directory."
    fi
    log_debug "CALIBRE_BINARY_DIRECTORY=${CALIBRE_BINARY_DIRECTORY}"
}

# Function to perform initial setup
initial_setup() {
    log_debug "Starting initial_setup function"
    echo "Initial setup detected. Performing basic setup..."

    read -rp "Would you like to create the default CalibreConfig directory? (Y/n) " choice
    choice="${choice:-y}"
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        log_dry_run mkdir -p "$(pwd)/CalibreConfig"
        log_dry_run chmod 755 "$(pwd)/CalibreConfig"
        echo "Created CalibreConfig directory."
    fi
    log_debug "CALIBRE_CONFIG_DIRECTORY=$(pwd)/CalibreConfig"

    read -rp "Would you like to create the default CalibreLibrary directory? (Y/n) " choice
    choice="${choice:-y}"
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        log_dry_run mkdir -p "$(pwd)/CalibreLibrary"
        log_dry_run chmod 755 "$(pwd)/CalibreLibrary"
        echo "Created CalibreLibrary directory."
    fi
    log_debug "CALIBRE_LIBRARY_DIRECTORIES[0]=$(pwd)/CalibreLibrary"

    read -rp "Would you like to create the default CalibreTemp directory? (Y/n) " choice
    choice="${choice:-y}"
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        log_dry_run mkdir -p "$(pwd)/CalibreTemp"
        log_dry_run chmod 755 "$(pwd)/CalibreTemp"
        echo "Created CalibreTemp directory."
    fi
    log_debug "CALIBRE_TEMP_DIR=$(pwd)/CalibreTemp"

    if [[ ! -d "$(pwd)/CalibreBin/calibre.app" && ! -d "$(pwd)/calibre.app" ]]; then
        read -rp "No calibre.app found. Would you like to download it? (Y/n) " choice
        choice="${choice:-y}"
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            upgrade_calibre
        else
            echo "Skipping calibre.app download."
        fi
    fi

    if [[ -d "$(pwd)/calibre.app" ]]; then
        read -rp "Would you like to move calibre.app to the CalibreBin directory? (Y/n) " choice
        choice="${choice:-y}"
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            log_dry_run mkdir -p "$(pwd)/CalibreBin"
            log_dry_run mv "$(pwd)/calibre.app" "$(pwd)/CalibreBin/"
            log_dry_run chmod 755 "$(pwd)/CalibreBin"
            CALIBRE_BINARY_DIRECTORY="$(pwd)/CalibreBin/calibre.app/Contents/MacOS"
            echo "Moved calibre.app to CalibreBin directory."
        fi
    fi

    read -rp "Would you like to create the 'Calibre Portable Mac.command' launcher? (Y/n) " choice
    choice="${choice:-y}"
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        create_command_launcher
    fi

    if [[ $log_dry_run -eq 1 ]]; then
        echo "[DRY-RUN] cat <<-_EOF_ > \"$(pwd)/calibre-portable.conf\""
        echo "[DRY-RUN] # Configuration file for calibre-portable. Generated on $(date)"
        echo "[DRY-RUN] # Settings in here will override the defaults specified in the portable launcher."
        echo "[DRY-RUN] "
        echo "[DRY-RUN] #CALIBRE_CONFIG_DIRECTORY=\"$(pwd)/CalibreConfig\""
        echo "[DRY-RUN] #CALIBRE_LIBRARY_DIRECTORIES[0]=\"$(pwd)/CalibreLibrary\""
        echo "[DRY-RUN] #CALIBRE_LIBRARY_DIRECTORIES[1]=\"/path/to/second/CalibreLibrary\""
        echo "[DRY-RUN] #CALIBRE_LIBRARY_DIRECTORIES[2]=\"/path/to/third/CalibreLibrary\""
        echo "[DRY-RUN] #CALIBRE_OVERRIDE_DATABASE_PATH=\"$(pwd)/CalibreMetadata\""
        echo "[DRY-RUN] #CALIBRE_BINARY_DIRECTORY=\"${CALIBRE_BINARY_DIRECTORY:-$(pwd)/calibre.app/Contents/MacOS}\""
        echo "[DRY-RUN] #CALIBRE_TEMP_DIR=\"$(pwd)/CalibreTemp\""
        echo "[DRY-RUN] #CALIBRE_OVERRIDE_LANG=\"EN\""
        echo "[DRY-RUN] #calibre_no_confirm_start=0"
        echo "[DRY-RUN] #calibre_no_cleanup=0"
        echo "[DRY-RUN] _EOF_"
    else
        cat <<-_EOF_ > "$(pwd)/calibre-portable.conf"
# Configuration file for calibre-portable. Generated on $(date)
# Settings in here will override the defaults specified in the portable launcher.

#CALIBRE_CONFIG_DIRECTORY="$(pwd)/CalibreConfig"
#CALIBRE_LIBRARY_DIRECTORIES[0]="$(pwd)/CalibreLibrary"
#CALIBRE_LIBRARY_DIRECTORIES[1]="/path/to/second/CalibreLibrary"
#CALIBRE_LIBRARY_DIRECTORIES[2]="/path/to/third/CalibreLibrary"
#CALIBRE_OVERRIDE_DATABASE_PATH="$(pwd)/CalibreMetadata"
#CALIBRE_BINARY_DIRECTORY="${CALIBRE_BINARY_DIRECTORY:-$(pwd)/calibre.app/Contents/MacOS}"
#CALIBRE_TEMP_DIR="$(pwd)/CalibreTemp"
#CALIBRE_OVERRIDE_LANG="EN"
#calibre_no_confirm_start=0
#calibre_no_cleanup=0
_EOF_
        echo "Generated default configuration file at $(pwd)/calibre-portable.conf"
    fi
    log_debug "initial_setup function completed"
}

# Parse command line options
while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
        -u|--upgrade-install)
            shift
            upgrade_calibre
            exit
            ;;
        -h|--help)
            usage
            exit
            ;;
        -v|--verbose)
            log_verbose=1
            shift
            ;;
        -V|--very-verbose)
            log_verbose=2
            shift
            ;;
        -d|--debug)
            log_debug=1
            shift
            ;;
        -r|--dry-run)
            log_dry_run=1
            shift
            ;;
        -s|--silent)
            log_silent=1
            shift
            ;;
        -S|--very-silent)
            log_silent=1
            log_very_silent=1
            shift
            ;;
        -c|--create-launcher)
            create_command_launcher
            exit
            ;;
        *)
            echo "calibre-portable-mac.sh: unrecognized option '${1}'"
            echo "Try 'calibre-portable-mac.sh --help' for more information."
            exit 1
            ;;
    esac
done

# Function to print a divider line
print_divider() {
    width=$(tput cols)
    printf '%*s\n' "$width" '' | tr ' ' '-'
}

# Load or create the configuration file
config_file="$(pwd)/calibre-portable.conf"
if [[ -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
else
    initial_setup
fi

# Set configuration directory
CALIBRE_CONFIG_DIRECTORY="${CALIBRE_CONFIG_DIRECTORY:-$(pwd)/CalibreConfig}"

if [[ -d "${CALIBRE_CONFIG_DIRECTORY}" ]]; then
    export CALIBRE_CONFIG_DIRECTORY
    echo "CONFIG FILES:       ${CALIBRE_CONFIG_DIRECTORY}"
else
    echo -e "\033[0;31mCONFIG FILES:       Not found\033[0m"
fi
print_divider

# Set temporary directory
CALIBRE_TEMP_DIR="${CALIBRE_TEMP_DIR:-$(pwd)/CalibreTemp}"

if [[ -d "${CALIBRE_TEMP_DIR}" ]]; then
    export CALIBRE_TEMP_DIR
    export CALIBRE_CACHE_DIRECTORY="${CALIBRE_TEMP_DIR}"
    echo "TEMPORARY FILES:    ${CALIBRE_TEMP_DIR}"
else
    echo -e "\033[0;31mTEMPORARY FILES:    Not found\033[0m"
fi
print_divider

# Set library directories
CALIBRE_LIBRARY_DIRECTORIES=(
    "${CALIBRE_LIBRARY_DIRECTORIES[0]:-/path/to/first/CalibreLibrary}"
    "${CALIBRE_LIBRARY_DIRECTORIES[1]:-/path/to/second/CalibreLibrary}"
    "${CALIBRE_LIBRARY_DIRECTORIES[2]:-$(pwd)/CalibreLibrary}"
)

for library_dir in "${CALIBRE_LIBRARY_DIRECTORIES[@]}"; do
    if [[ -d "${library_dir}" ]]; then
        CALIBRE_LIBRARY_DIRECTORY="${library_dir}"
        echo "LIBRARY FILES:      ${CALIBRE_LIBRARY_DIRECTORY}"
        break
    fi
done

[[ -z "${CALIBRE_LIBRARY_DIRECTORY}" ]] && echo -e "\033[0;31mLIBRARY FILES:      Not found\033[0m"
print_divider

# Set metadata directory
CALIBRE_OVERRIDE_DATABASE_PATH="${CALIBRE_OVERRIDE_DATABASE_PATH:-$(pwd)/CalibreMetadata}"

if [[ -f "${CALIBRE_OVERRIDE_DATABASE_PATH}/metadata.db" && "${CALIBRE_LIBRARY_DIRECTORY}" != "${CALIBRE_OVERRIDE_DATABASE_PATH}" ]]; then
    export CALIBRE_OVERRIDE_DATABASE_PATH
    echo "DATABASE:        ${CALIBRE_OVERRIDE_DATABASE_PATH}/metadata.db"
    echo
    echo -e "\033[0;31m***CAUTION*** Library Switching will be disabled\033[0m"
    echo
    print_divider
fi

# Set binary directory
if [[ -d "$(pwd)/CalibreBin/calibre.app/Contents/MacOS" ]]; then
    CALIBRE_BINARY_DIRECTORY="$(pwd)/CalibreBin/calibre.app/Contents/MacOS"
elif [[ -d "$(pwd)/calibre.app/Contents/MacOS" ]]; then
    CALIBRE_BINARY_DIRECTORY="$(pwd)/calibre.app/Contents/MacOS"
else
    CALIBRE_BINARY_DIRECTORY=""
fi

if [[ -n "$CALIBRE_BINARY_DIRECTORY" ]]; then
    calibre_executable="${CALIBRE_BINARY_DIRECTORY}/calibre"
    echo "PROGRAM FILES:      ${CALIBRE_BINARY_DIRECTORY}"
else
    calibre_executable="calibre"
    echo "PROGRAM FILES:      No portable copy found."
    echo "To install a portable copy, run './calibre-portable-mac.sh --upgrade-install'"
    echo -e "\033[0;31m*** Using system search path instead***\033[0m"
fi
print_divider

# Set interface language
CALIBRE_OVERRIDE_LANG="${CALIBRE_OVERRIDE_LANG:-}"

if [[ -n "${CALIBRE_OVERRIDE_LANG}" ]]; then
    export CALIBRE_OVERRIDE_LANG
    echo "INTERFACE LANGUAGE: ${CALIBRE_OVERRIDE_LANG}"
    print_divider
fi

# Confirm start
if [[ "${calibre_no_confirm_start}" != "1" && $log_very_silent -ne 1 ]]; then
    echo
    read -rp "Start Calibre? (Y/n) " choice
    choice="${choice:-y}"
    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        echo "Exiting."
        exit 0
    fi
fi

# Start Calibre
if [[ $log_silent -ne 1 ]]; then
    echo "Starting up calibre from portable directory \"$(pwd)\""
fi
log_dry_run "$calibre_executable" --with-library "${CALIBRE_LIBRARY_DIRECTORY}"

###EOF
