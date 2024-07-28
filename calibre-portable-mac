#!/usr/bin/env bash
#                       calibre-portable-mac.sh
#                           By: Pidockmedia
#                       ¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬
#
# Shell script to manage a portable Calibre configuration on macOS.
#
# This script started as a fork of the calibre-portable.sh script by
# eschwartz, which was based on the calibre-portable.sh script by itimpi
#
# The script has been modified to work on macOS and to provide additional
# features and options for managing a portable Calibre configuration.
# The script is designed to be run from the command line and provides
# options for upgrading or installing the Calibre binaries, creating a
# command launcher for starting Calibre, and setting detailed logging
# levels for debugging and troubleshooting.
#
# Bash code has been heavily modified using AI. It was a personal challenge
# to see how much I could improve the script without personally writing
# a single line of code.
#
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
#  -s, --silent            Suppress all output except errors and the start prompt
#  -S, --very-silent       Suppress all output including the start prompt
#
# Script Overview:
# 1. Initialize script with strict mode and set default variables.
# 2. Define logging and debugging functions.
# 3. Define cleanup function to handle script exit.
# 4. Define function to display usage information.
# 5. Define function to upgrade or install Calibre.
# 6. Define function to create command launcher.
# 7. Define function to move calibre.app to the desired directory.
# 8. Define function for initial setup.
# 9. Parse command line options and set corresponding flags and variables.
# 10. Load or create the configuration file.
# 11. Set environment variables based on configuration file.
# 12. Set library directories and check their existence.
# 13. Set binary directory and check its existence.
# 14. Set temporary directory and check its existence.
# 15. Set interface language if specified.
# 16. Confirm start if not set to auto-start and run Calibre.

set -euo pipefail  # Enable strict mode

# Variables for logging levels and modes
log_verbose=0
log_dry_run=0
log_debug=0
log_silent=0
log_very_silent=0

# Initialize configuration variables
# shellcheck disable=SC2034
CALIBRE_LIBRARY_DIRECTORY=""
# shellcheck disable=SC2034
CALIBRE_OVERRIDE_DATABASE_PATH=""
CALIBRE_BINARY_DIRECTORY=""
CALIBRE_TEMP_DIR=""
CALIBRE_OVERRIDE_LANG=""
calibre_no_confirm_start=0
calibre_no_cleanup=0

# Function to log messages
output() {
    if [[ $log_silent -eq 0 ]]; then
        echo "$@"
    fi
}

# Function to log detailed debug messages
output_debug() {
    if [[ $log_verbose -ge 1 && $log_silent -eq 0 ]]; then
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
    output_debug "Starting cleanup function"
    if [[ "${calibre_no_cleanup}" -eq 1 ]]; then
        output_debug "Skipping cleanup as calibre_no_cleanup is set to 1"
        return
    fi
    output_debug "Cleanup function completed"
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
          -c, --create-launcher     Create a command launcher for starting Calibre
          -s, --silent              Suppress all output except errors and the start prompt
          -S, --very-silent         Suppress all output including the start prompt
_EOF_
}

# Function to upgrade or install Calibre on macOS
upgrade_calibre() {
    output_debug "Starting upgrade_calibre function"
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
    output_debug "TEMP_DIR=${temp_dir}"
    log_dry_run mkdir -p "$temp_dir"
    debug_step

    # Getting the current dmg download url
    dmg_path="$temp_dir/calibre-latest.dmg"
    output_debug "DMG_PATH=${dmg_path}"
    latest_dmg_url=$(curl -s https://calibre-ebook.com/download_osx | grep -o 'https://[^"]*\.dmg' | head -1)
    output_debug "LATEST_DMG_URL=${latest_dmg_url}"
    debug_step

    if [[ -z "$latest_dmg_url" ]]; then
        output "Failed to retrieve the latest Calibre DMG URL."
        log_dry_run rm -rf "$temp_dir"
        exit 1
    fi

    # Downloading the current dmg
    curl_command=("curl" "-L" "-o" "$dmg_path" "$latest_dmg_url")
    output_debug "CURL_COMMAND=${curl_command[*]}"
    debug_step
    log_dry_run "${curl_command[@]}"
    if [[ $? -ne 0 || ! -f "$dmg_path" ]]; then
        output "Failed to download Calibre DMG."
        log_dry_run rm -rf "$temp_dir"
        exit 1
    fi

    # Mounting the dmg
    volume_path=$(hdiutil attach "$dmg_path" | grep "/Volumes/" | awk '{print $3}')
    output_debug "VOLUME_PATH=${volume_path}"
    debug_step

    if [[ -z "$volume_path" ]]; then
        output "Failed to mount Calibre DMG."
        log_dry_run rm -rf "$temp_dir"
        exit 1
    fi

    if [[ -d "$volume_path/calibre.app" ]]; then
        temp_calibre_app_path="$temp_dir/calibre.app"
        # Copying the calibre.app from the mounted dmg to the temp directory
        cp_command=("ditto" "$volume_path/calibre.app" "$temp_calibre_app_path")
        output_debug "CP_COMMAND=${cp_command[*]}"
        debug_step
        log_dry_run "${cp_command[@]}"

        log_dry_run rm -rf "${CALIBRE_BINARY_DIRECTORY}/calibre.app"
        move_calibre_app "$temp_calibre_app_path"
        output "Calibre has been upgraded/installed successfully."

        # Unmounting the dmg
        log_dry_run hdiutil detach "$volume_path"
    else
        output "Failed to find calibre.app in the mounted DMG."
        log_dry_run hdiutil detach "$volume_path"
        log_dry_run rm -rf "$temp_dir"
        exit 1
    fi

    # Removing the temporary directory
    log_dry_run rm -rf "$temp_dir"
    output_debug "upgrade_calibre function completed"
}

# Function to create command launcher
create_command_launcher() {
    output_debug "Starting create_command_launcher function"
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
# Launcher for portable Calibre
PORTABLE_DIR="\$(dirname "\$0")"
# Default directories
CALIBRE_CONFIG_DIRECTORY="\${PORTABLE_DIR}/CalibreConfig"
CALIBRE_LIBRARY_DIRECTORIES[0]="\${PORTABLE_DIR}/CalibreLibrary"
CALIBRE_OVERRIDE_DATABASE_PATH="\${PORTABLE_DIR}/CalibreMetadata"
CALIBRE_BINARY_DIRECTORY="\${PORTABLE_DIR}/calibre.app/Contents/MacOS"
CALIBRE_TEMP_DIR="\${PORTABLE_DIR}/CalibreTemp"
CALIBRE_OVERRIDE_LANG="EN"
# Load user configuration
if [[ -f "\${PORTABLE_DIR}/calibre-portable.conf" ]]; then
    source "\${PORTABLE_DIR}/calibre-portable.conf"
fi
"\${CALIBRE_BINARY_DIRECTORY}/calibre" --with-library "\${CALIBRE_LIBRARY_DIRECTORIES[0]}" &
_EOF_
        chmod +x "$(pwd)/Calibre Portable Mac.command"
        [[ $log_silent -eq 0 ]] && output "Created 'Calibre Portable Mac.command' launcher."
    fi
    output_debug "create_command_launcher function completed"
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
        output "Moved 'calibre.app' to 'CalibreBin' directory."
    else
        CALIBRE_BINARY_DIRECTORY="$(pwd)"
        log_dry_run mv "$temp_calibre_app_path" "$CALIBRE_BINARY_DIRECTORY/calibre.app"
        output "Moved 'calibre.app' to the current directory."
    fi
    output_debug "CALIBRE_BINARY_DIRECTORY=${CALIBRE_BINARY_DIRECTORY}"
}

# Function to perform initial setup
initial_setup() {
    output_debug "Starting initial_setup function"
    output "Initial setup detected. Performing basic setup..."

    if [[ $log_silent -eq 0 ]]; then
        read -rp "Would you like to create the default CalibreConfig directory? (Y/n) " choice
        choice="${choice:-y}"
    else
        choice="y"
    fi
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        log_dry_run mkdir -p "$(pwd)/CalibreConfig"
        log_dry_run chmod 755 "$(pwd)/CalibreConfig"
        output "Created CalibreConfig directory."
    fi
    output_debug "CALIBRE_CONFIG_DIRECTORY=$(pwd)/CalibreConfig"

    if [[ $log_silent -eq 0 ]]; then
        read -rp "Would you like to create the default CalibreLibrary directory? (Y/n) " choice
        choice="${choice:-y}"
    else
        choice="y"
    fi
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        log_dry_run mkdir -p "$(pwd)/CalibreLibrary"
        log_dry_run chmod 755 "$(pwd)/CalibreLibrary"
        output "Created CalibreLibrary directory."
    fi
    output_debug "CALIBRE_LIBRARY_DIRECTORIES[0]=$(pwd)/CalibreLibrary"

    if [[ $log_silent -eq 0 ]]; then
        read -rp "Would you like to create the default CalibreTemp directory? (Y/n) " choice
        choice="${choice:-y}"
    else
        choice="y"
    fi
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        log_dry_run mkdir -p "$(pwd)/CalibreTemp"
        log_dry_run chmod 755 "$(pwd)/CalibreTemp"
        output "Created CalibreTemp directory."
    fi
    output_debug "CALIBRE_TEMP_DIR=$(pwd)/CalibreTemp"

    if [[ ! -d "$(pwd)/CalibreBin/calibre.app" && ! -d "$(pwd)/calibre.app" ]]; then
        if [[ $log_silent -eq 0 ]]; then
            read -rp "No calibre.app found. Would you like to download it? (Y/n) " choice
            choice="${choice:-y}"
        else
            choice="y"
        fi
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            upgrade_calibre
        else
            output "Skipping calibre.app download."
        fi
    fi

    if [[ -d "$(pwd)/calibre.app" ]]; then
        if [[ $log_silent -eq 0 ]]; then
            read -rp "Would you like to move calibre.app to the CalibreBin directory? (Y/n) " choice
            choice="${choice:-y}"
        else
            choice="y"
        fi
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            log_dry_run mkdir -p "$(pwd)/CalibreBin"
            log_dry_run mv "$(pwd)/calibre.app" "$(pwd)/CalibreBin/"
            log_dry_run chmod 755 "$(pwd)/CalibreBin"
            CALIBRE_BINARY_DIRECTORY="$(pwd)/CalibreBin/calibre.app/Contents/MacOS"
            output "Moved calibre.app to CalibreBin directory."
        fi
    fi

    if [[ $log_silent -eq 0 ]]; then
        read -rp "Would you like to create the 'Calibre Portable Mac.command' launcher? (Y/n) " choice
        choice="${choice:-y}"
    else
        choice="y"
    fi
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
        output "Generated default configuration file at $(pwd)/calibre-portable.conf"
    fi
    output_debug "initial_setup function completed"
}

# Function to print divider
print_divider() {
    [[ $log_silent -eq 0 ]] && printf '%*s\n' "${width:-$(tput cols)}" '' | tr ' ' '-'
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
            output "calibre-portable-mac.sh: unrecognized option '${1}'"
            output "Try 'calibre-portable-mac.sh --help' for more information."
            exit 1
            ;;
    esac
done

# Load or create the configuration file
config_file="$(pwd)/calibre-portable.conf"
if [[ -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
else
    initial_setup
fi

# Set environment variables based on configuration file
export CALIBRE_CONFIG_DIRECTORY="${CALIBRE_CONFIG_DIRECTORY:-$(pwd)/CalibreConfig}"

if [[ -d "${CALIBRE_CONFIG_DIRECTORY}" ]]; then
    [[ $log_very_silent -eq 0 ]] && output "CONFIG FILES:       ${CALIBRE_CONFIG_DIRECTORY}"
else
    [[ $log_very_silent -eq 0 ]] && output -e "\033[0;31mCONFIG FILES:       Not found\033[0m"
fi
print_divider

# Set library directories and check their existence
CALIBRE_LIBRARY_DIRECTORIES=(
    "${CALIBRE_LIBRARY_DIRECTORIES[0]:-/path/to/first/CalibreLibrary}"
    "${CALIBRE_LIBRARY_DIRECTORIES[1]:-/path/to/second/CalibreLibrary}"
    "${CALIBRE_LIBRARY_DIRECTORIES[2]:-$(pwd)/CalibreLibrary}"
)

for library_dir in "${CALIBRE_LIBRARY_DIRECTORIES[@]}"; do
    if [[ -d "${library_dir}" ]]; then
        CALIBRE_LIBRARY_DIRECTORY="${library_dir}"
        [[ $log_very_silent -eq 0 ]] && output "LIBRARY FILES:      ${CALIBRE_LIBRARY_DIRECTORY}"
        break
    fi
done

[[ -z "${CALIBRE_LIBRARY_DIRECTORY}" ]] && [[ $log_very_silent -eq 0 ]] && output -e "\033[0;31mLIBRARY FILES:      Not found\033[0m"
print_divider

# Set temporary directory
export CALIBRE_TEMP_DIR="${CALIBRE_TEMP_DIR:-$(pwd)/CalibreTemp}"

if [[ -d "${CALIBRE_TEMP_DIR}" ]]; then
    export CALIBRE_CACHE_DIRECTORY="${CALIBRE_TEMP_DIR}"
    [[ $log_very_silent -eq 0 ]] && output "TEMPORARY FILES:    ${CALIBRE_TEMP_DIR}"
else
    [[ $log_very_silent -eq 0 ]] && output -e "\033[0;31mTEMPORARY FILES:    Not found\033[0m"
fi
print_divider

# Set binary directory and check its existence
if [[ -d "$(pwd)/CalibreBin/calibre.app/Contents/MacOS" ]]; then
    CALIBRE_BINARY_DIRECTORY="$(pwd)/CalibreBin/calibre.app/Contents/MacOS"
elif [[ -d "$(pwd)/calibre.app/Contents/MacOS" ]]; then
    CALIBRE_BINARY_DIRECTORY="$(pwd)/calibre.app/Contents/MacOS"
else
    CALIBRE_BINARY_DIRECTORY=""
fi

if [[ -n "$CALIBRE_BINARY_DIRECTORY" ]]; then
    calibre_executable="${CALIBRE_BINARY_DIRECTORY}/calibre"
    [[ $log_very_silent -eq 0 ]] && output "PROGRAM FILES:      ${CALIBRE_BINARY_DIRECTORY}"
else
    calibre_executable="calibre"
    [[ $log_very_silent -eq 0 ]] && output "PROGRAM FILES:      No portable copy found."
    [[ $log_very_silent -eq 0 ]] && output "To install a portable copy, run './calibre-portable-mac.sh --upgrade-install'"
    [[ $log_very_silent -eq 0 ]] && output -e "\033[0;31m*** Using system search path instead***\033[0m"
fi
print_divider

# Set interface language if specified
if [[ -n "${CALIBRE_OVERRIDE_LANG}" ]]; then
    export CALIBRE_OVERRIDE_LANG
    [[ $log_very_silent -eq 0 ]] && output "INTERFACE LANGUAGE: ${CALIBRE_OVERRIDE_LANG}"
fi

# Confirm start if not set to auto-start and run Calibre
if [[ "${calibre_no_confirm_start}" != "1" && $log_very_silent -eq 0 ]]; then
    read -rp "Start Calibre? (Y/n) " choice
    case "$choice" in
        y|Y|"" ) ;;
        * ) output "Exiting."; exit;;
    esac
fi

if [[ $log_very_silent -eq 1 ]]; then
    log_dry_run "$calibre_executable" --with-library "${CALIBRE_LIBRARY_DIRECTORY}" &
else
    output "Starting up calibre from portable directory \"$(pwd)\""
    log_dry_run "$calibre_executable" --with-library "${CALIBRE_LIBRARY_DIRECTORY}" &
fi

###EOF
