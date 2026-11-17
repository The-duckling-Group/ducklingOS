#!/usr/bin/env bash
# ==============================================================================
# ducklingOS - Standalone Installer
# ==============================================================================
# Theme: Omarchy Minimalist Pixel-TUI
# Colors:
#   - Background: Dark Violet (#160b24)
#   - Logo / Brand: Vibrant Yellow (#f5e042)
#   - Accents: Lilac (#c084fc), Lavender (#a78bfa), Soft Gray (#e2e8f0)
# Alignment:
#   - Fully centered both horizontally and vertically across any terminal resolution
# Desktop: KDE Plasma 6 (Wayland)
# Bootloader: Limine
# Mode: Live, --installation or --dev simulation
# ==============================================================================

set -eo pipefail

# ------------------------------------------------------------------------------
# System State & Configuration
# ------------------------------------------------------------------------------
export DISTRO_NAME="ducklingOS"
export DISTRO_VERSION="1"
export DISTRO_CODENAME="Obsidian"
export DISTRO_FULL_NAME="${DISTRO_NAME}"

export DEV_MODE=0
export TEST_PRESET=0
export INSTALLATION_MODE=0
export DUCKLINGOS_REPO="the-duckling-group/ducklingOS"
export DUCKLINGOS_BRANCH="main"
export MANIFEST_RAW_URL="https://raw.githubusercontent.com/${DUCKLINGOS_REPO}/${DUCKLINGOS_BRANCH}/system-update.json"
export MANIFEST_RELEASE_API="https://api.github.com/repos/${DUCKLINGOS_REPO}/releases/latest"
export UPDATE_SCRIPT_RAW_URL="https://raw.githubusercontent.com/${DUCKLINGOS_REPO}/${DUCKLINGOS_BRANCH}/update.sh"
export REMOTE_RELEASE_JSON=""

export PREVIEW_DIR="/tmp/ducklingos-dev-preview"

# Localization Defaults
export SYSTEM_KEYMAP="us"
export SYSTEM_LOCALE="en_US.UTF-8"
export SYSTEM_TIMEZONE="Europe/Berlin"

# Network Defaults
export SYSTEM_HOSTNAME="ducklingos"

# Primary User Defaults
export USER_NAME=""
export USER_REALNAME=""
export USER_PASSWORD=""
export ROOT_PASSWORD=""
export ROOT_PASSWORD_SAME_AS_USER=1

# Extra Users Array (format: username:fullname:sudo:password)
export EXTRA_USERS=()

# Storage Defaults
export TARGET_DISK=""
export TARGET_PARTITION_MODE="auto" # auto or manual
export TARGET_FILESYSTEM="btrfs"    # btrfs or ext4
export BTRFS_SUBVOLUMES=1
export SWAP_TYPE="zram"             # zram, swapfile-4g, swapfile-8g, none
export SWAP_SIZE="4G"
export MOUNT_POINT="/mnt"

# Software & Hardware Defaults
export SYSTEM_KERNEL="linux-zen"    # linux-zen (default), linux, linux-lts
export SYSTEM_PROFILE="kde"         # KDE Plasma 6
export SYSTEM_BOOTLOADER="limine"   # Limine
export INSTALL_DEV_TOOLS=1
export INSTALL_BLUETOOTH=1
export INSTALL_GAMING=1

# ------------------------------------------------------------------------------
# Color Palette: Dark Violet & Bright Yellow
# ------------------------------------------------------------------------------
export OMARCHY_BG="#160b24"         # Deep Dark Violet Background
export OMARCHY_YELLOW="#f5e042"     # Vibrant ducklingOS Yellow (Signature)
export OMARCHY_HEADER="#c084fc"     # Lavender/Lilac Header Text
export OMARCHY_ITEM="#e2e8f0"       # Light Crisp Menu Item Text
export OMARCHY_CURSOR="#facc15"     # Yellow Cursor/Selected Accent
export OMARCHY_MUTED="#7e6c99"      # Dimmed helper / keybinds text
export OMARCHY_TRACK="#2a1745"      # Dark Violet Track for progress bar
export OMARCHY_BAR="#f5e042"        # Yellow Filled Progress Block
export OMARCHY_DANGER="#f87171"     # Soft Red for warnings
export OMARCHY_WARN="#fbbf24"       # Warm Amber

# ------------------------------------------------------------------------------
# Dynamic Geometry & Centering Helpers
# ------------------------------------------------------------------------------
get_term_size() {
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)
    TERM_LINES=$(tput lines 2>/dev/null || echo 24)
}

# Calculate left padding spaces to center content of a given width
get_left_pad() {
    local content_width="${1:-68}"
    get_term_size
    local pad_count=$(( (TERM_COLS - content_width) / 2 ))
    if [ "$pad_count" -lt 0 ]; then pad_count=0; fi
    printf "%*s" "$pad_count" ""
}

# Add top padding newlines to center content vertically
ui_vertical_pad() {
    local content_height="${1:-16}"
    get_term_size
    local pad_lines=$(( (TERM_LINES - content_height) / 2 ))
    if [ "$pad_lines" -gt 0 ]; then
        for ((i = 0; i < pad_lines; i++)); do
            echo ""
        done
    fi
}

check_gum_installed() {
    if ! command -v gum &>/dev/null; then
        echo -e "\033[38;2;245;224;66m[!] 'gum' is required for the ducklingOS installer.\033[0m"
        if [ "$DEV_MODE" -eq 1 ] && [ "$EUID" -ne 0 ]; then
            echo -e "\033[38;2;248;113;113mPlease install 'gum' using: sudo pacman -S gum\033[0m"
            exit 1
        elif command -v pacman &>/dev/null && [ "$EUID" -eq 0 ]; then
            echo -e "\033[38;2;192;132;252m[*] Installing 'gum' via pacman...\033[0m"
            pacman -Sy --noconfirm gum || {
                echo -e "\033[38;2;248;113;113mFailed to install gum. Aborting.\033[0m"
                exit 1
            }
        else
            echo -e "\033[38;2;248;113;113mError: gum is missing and cannot be installed automatically.\033[0m"
            exit 1
        fi
    fi
}

ui_clear() {
    clear 2>/dev/null || true
    # Set dark violet background color in supported terminal emulators
    printf "\033]11;%s\007" "$OMARCHY_BG" 2>/dev/null || true
}

# Center-aligned Yellow Pixel Wordmark Logo (ducklingOS ANSI Block)
ui_logo() {
    get_term_size
    gum style \
        --foreground "$OMARCHY_YELLOW" \
        --bold \
        --align center \
        --width "$TERM_COLS" \
        "██████╗ ██╗   ██╗ ██████╗██╗  ██╗██╗     ██╗███╗   ██╗ ██████╗  ██████╗ ███████╗" \
        "██╔══██╗██║   ██║██╔════╝██║ ██╔╝██║     ██║████╗  ██║██╔════╝ ██╔═══██╗██╔════╝" \
        "██║  ██║██║   ██║██║     █████╔╝ ██║     ██║██╔██╗ ██║██║  ███╗██║   ██║███████╗" \
        "██║  ██║██║   ██║██║     ██╔═██╗ ██║     ██║██║╚██╗██║██║   ██║██║   ██║╚════██║" \
        "██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║██║ ╚████║╚██████╔╝╚██████╔╝███████║" \
        "╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚══════╝"
    echo ""
}

ui_dev_badge() {
    if [ "$DEV_MODE" -eq 1 ]; then
        get_term_size
        gum style \
            --foreground "$OMARCHY_WARN" \
            --align center \
            --width "$TERM_COLS" \
            "⚡ DEV / DRY-RUN SIMULATION MODE (NO STORAGE MODIFICATIONS) ⚡"
        echo ""
    fi
}

ui_screen_header() {
    local title="$1"
    local est_height="${2:-18}"
    ui_clear
    ui_vertical_pad "$est_height"
    ui_logo
    ui_dev_badge
    if [ -n "$title" ]; then
        get_term_size
        gum style \
            --foreground "$OMARCHY_HEADER" \
            --align center \
            --width "$TERM_COLS" \
            "$title"
        echo ""
    fi
}

ui_footer_hint() {
    local hint="${1:-↑/↓ navigate  ·  enter submit}"
    get_term_size
    echo ""
    gum style \
        --foreground "$OMARCHY_TRACK" \
        --align center \
        --width "$TERM_COLS" \
        "................................................................"
    gum style \
        --foreground "$OMARCHY_MUTED" \
        --align center \
        --width "$TERM_COLS" \
        "$hint"
}

# Centered Choose Menu aligned with the left edge of the logo
ui_choose() {
    local header="$1"
    shift
    local lpad
    lpad=$(get_left_pad 71)

    gum choose \
        --header="${lpad}${header}" \
        --header.foreground="$OMARCHY_HEADER" \
        --cursor="${lpad}> " \
        --cursor.foreground="$OMARCHY_CURSOR" \
        --selected.foreground="$OMARCHY_CURSOR" \
        --item.foreground="$OMARCHY_ITEM" \
        --height=11 \
        "$@"
}

# Centered Input
ui_input() {
    local prompt="$1"
    local placeholder="$2"
    local default_val="$3"
    local lpad
    lpad=$(get_left_pad 71)

    gum input \
        --prompt="${lpad}${prompt} " \
        --prompt.foreground="$OMARCHY_HEADER" \
        --placeholder="$placeholder" \
        --placeholder.foreground="$OMARCHY_MUTED" \
        --value="$default_val" \
        --cursor.foreground="$OMARCHY_CURSOR" \
        --width=70
}

# Centered Password Input
ui_password() {
    local prompt="$1"
    local placeholder="$2"
    local lpad
    lpad=$(get_left_pad 71)

    gum input \
        --password \
        --prompt="${lpad}${prompt} " \
        --prompt.foreground="$OMARCHY_HEADER" \
        --placeholder="$placeholder" \
        --placeholder.foreground="$OMARCHY_MUTED" \
        --cursor.foreground="$OMARCHY_CURSOR" \
        --width=70
}

# Centered Confirm Dialog
ui_confirm() {
    local prompt="$1"
    local affirmative="${2:-Yes}"
    local negative="${3:-No}"
    local lpad
    lpad=$(get_left_pad 71)

    gum confirm \
        --prompt.foreground="$OMARCHY_HEADER" \
        --selected.background="$OMARCHY_YELLOW" \
        --selected.foreground="#160b24" \
        --unselected.background="$OMARCHY_TRACK" \
        --unselected.foreground="$OMARCHY_ITEM" \
        --affirmative="$affirmative" \
        --negative="$negative" \
        "${lpad}${prompt}"
}

ui_info() {
    local lpad
    lpad=$(get_left_pad 71)
    gum style --foreground "$OMARCHY_HEADER" "${lpad}ℹ $1"
}

ui_success() {
    local lpad
    lpad=$(get_left_pad 71)
    gum style --foreground "$OMARCHY_YELLOW" --bold "${lpad}✔ $1"
}

ui_warn() {
    local lpad
    lpad=$(get_left_pad 71)
    gum style --foreground "$OMARCHY_WARN" --bold "${lpad}⚠ $1"
}

ui_error() {
    local lpad
    lpad=$(get_left_pad 71)
    gum style --foreground "$OMARCHY_DANGER" --bold "${lpad}✖ $1"
}

# Centered Progress Bar (Omarchy Style in Dark Violet & Yellow)
ui_progress_bar() {
    local current="$1"
    local total="$2"
    local status_text="$3"
    local tip_text="${4:-Tip: Super + K shows all the key bindings}"

    local width=42
    local percent=$(( current * 100 / total ))
    local filled=$(( width * current / total ))
    local empty=$(( width - filled ))

    get_term_size
    ui_clear
    ui_vertical_pad 15
    ui_logo
    ui_dev_badge

    # Status line centered
    gum style \
        --foreground "$OMARCHY_HEADER" \
        --align center \
        --width "$TERM_COLS" \
        "$status_text"
    echo ""

    # Progress track & block centered
    local filled_spaces="" empty_str=""
    if [ "$filled" -gt 0 ]; then
        printf -v filled_spaces "%*s" "$filled" ""
    fi
    local filled_str="${filled_spaces// /█}"
    if [ "$empty" -gt 0 ]; then
        printf -v empty_str "%*s" "$empty" ""
    fi

    local bar_lpad
    bar_lpad=$(get_left_pad "$width")
    echo -e "${bar_lpad}\033[48;2;42;23;69m\033[38;2;245;224;66m${filled_str}${empty_str}\033[0m"
    echo ""

    # Shortcut Tip centered
    gum style \
        --foreground "$OMARCHY_YELLOW" \
        --align center \
        --width "$TERM_COLS" \
        "$tip_text"
    echo ""
}

ui_cmd() {
    local cmd_desc="$1"
    shift
    local cmd=("$@")
    local lpad
    lpad=$(get_left_pad 64)

    if [ "$DEV_MODE" -eq 1 ]; then
        echo -e "${lpad}\033[38;2;192;132;252m❯ [SIMULATION]\033[0m \033[38;2;226;232;240m$cmd_desc\033[0m"
        echo -e "${lpad}  \033[38;2;126;108;153m${cmd[*]}\033[0m"
        mkdir -p "$PREVIEW_DIR"
        sleep 0.15 2>/dev/null || true
        return 0
    else
        echo -e "${lpad}\033[38;2;245;224;66m❯\033[0m \033[38;2;226;232;240m$cmd_desc\033[0m"
        "${cmd[@]}"
        local status=$?
        if [ $status -ne 0 ]; then
            ui_error "Failed with exit code $status: ${cmd[*]}"
            return $status
        fi
        return 0
    fi
}

# Fetch latest release metadata and update.sh from GitHub
fetch_latest_release_metadata() {
    REMOTE_RELEASE_JSON=""
    LOCAL_UPDATE_SCRIPT="${BASH_SOURCE[0]%/*}/update.sh"

    # 1. Fetch update.sh from GitHub if available, or fall back to local script
    if [ "$DEV_MODE" -ne 1 ]; then
        ui_info "Checking GitHub repository for latest update.sh..."
        local tmp_update="/tmp/ducklingos-update-download.sh"
        if curl -fsSL "$UPDATE_SCRIPT_RAW_URL" -o "$tmp_update" 2>/dev/null && [ -s "$tmp_update" ]; then
            chmod +x "$tmp_update"
            LOCAL_UPDATE_SCRIPT="$tmp_update"
            ui_success "Fetched latest update.sh from GitHub (${DUCKLINGOS_REPO})!"
        elif [ -f "${BASH_SOURCE[0]%/*}/update.sh" ]; then
            LOCAL_UPDATE_SCRIPT="${BASH_SOURCE[0]%/*}/update.sh"
            ui_info "Using local update.sh bundled with installer."
        else
            ui_warn "No local update.sh found. Will attempt GitHub fetch during installation phase."
        fi
    fi

    if [ "$DEV_MODE" -eq 1 ]; then
        REMOTE_RELEASE_JSON='{
  "os_name": "ducklingOS",
  "big_version": 1,
  "big_version_name": "Obsidian",
  "mini_version": "1.1.0",
  "codename": "Obsidian 1.1",
  "release_date": "2026-11-16",
  "packages": {
    "pacman": {
      "system_upgrade": true,
      "apps": {
        "ghostty": "latest",
        "fastfetch": "latest",
        "firefox": "latest",
        "mpv": "latest",
        "btop": "latest",
        "micro": "latest"
      }
    },
    "aur": {
      "apps": {}
    }
  }
}'
    else
        local api_resp
        api_resp=$(curl -fsSL -H "Accept: application/vnd.github+json" "$MANIFEST_RELEASE_API" 2>/dev/null || true)
        if [ -n "$api_resp" ]; then
            local asset_url
            asset_url=$(echo "$api_resp" | grep -Po '"browser_download_url":\s*"\K[^"]*system-update\.json' | head -n 1 || echo "")
            if [ -n "$asset_url" ]; then
                REMOTE_RELEASE_JSON=$(curl -fsSL "$asset_url" 2>/dev/null || true)
            fi
        fi
        if [ -z "$REMOTE_RELEASE_JSON" ]; then
            REMOTE_RELEASE_JSON=$(curl -fsSL "$MANIFEST_RAW_URL" 2>/dev/null || true)
        fi
    fi

    if [ -n "$REMOTE_RELEASE_JSON" ]; then
        DISTRO_NAME=$(python3 -c "import json; d=json.loads('''${REMOTE_RELEASE_JSON}'''); print(d.get('os_name', 'ducklingOS'))" 2>/dev/null || echo "ducklingOS")
        DISTRO_VERSION=$(python3 -c "import json; d=json.loads('''${REMOTE_RELEASE_JSON}'''); print(d.get('big_version', '1'))" 2>/dev/null || echo "1")
        DISTRO_CODENAME=$(python3 -c "import json; d=json.loads('''${REMOTE_RELEASE_JSON}'''); print(d.get('big_version_name', 'Obsidian'))" 2>/dev/null || echo "Obsidian")
        DISTRO_MINI_VERSION=$(python3 -c "import json; d=json.loads('''${REMOTE_RELEASE_JSON}'''); print(d.get('mini_version', '1.0.0'))" 2>/dev/null || echo "1.0.0")
    else
        DISTRO_NAME="ducklingOS"
        DISTRO_VERSION="1"
        DISTRO_CODENAME="Obsidian"
        DISTRO_MINI_VERSION="1.0.0"
        REMOTE_RELEASE_JSON='{"os_name":"ducklingOS","big_version":1,"big_version_name":"Obsidian","mini_version":"1.0.0"}'
    fi
    DISTRO_FULL_NAME="${DISTRO_NAME}"
}

# ------------------------------------------------------------------------------
# Step 1: Welcome Screen
# ------------------------------------------------------------------------------
step_welcome() {
    ui_screen_header "System Diagnostics" 20
    fetch_latest_release_metadata

    if [ -d "/sys/firmware/efi/efivars" ]; then
        ui_success "Boot Mode: UEFI (Optimal for Limine)"
    else
        ui_warn "Boot Mode: BIOS / Legacy CSM"
    fi

    local total_ram
    total_ram=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
    if [ -n "$total_ram" ]; then
        ui_info "Memory: $total_ram detected"
    fi

    if ping -c 1 -W 2 archlinux.org &>/dev/null; then
        ui_success "Network: Active internet connection verified"
    else
        if [ "$DEV_MODE" -eq 1 ]; then
            ui_warn "Network: Offline (Simulating in Dev Mode)"
        else
            ui_warn "Network: No active internet connection found."
        fi
    fi

    ui_info "Target Release: ${DISTRO_NAME} (v${DISTRO_MINI_VERSION} \"${DISTRO_CODENAME}\")"
    ui_info "Desktop Environment: KDE Plasma 6"
    ui_info "Bootloader: Limine"

    ui_footer_hint "enter continue  ·  ctrl+c exit"

    if [ "$TEST_PRESET" -eq 1 ]; then
        ui_info "Preset enabled: Proceeding automatically."
        return 0
    fi

    echo ""
    if ! ui_confirm "Ready to configure ${DISTRO_NAME}?"; then
        ui_warn "Installation cancelled by user."
        exit 0
    fi
}

# ------------------------------------------------------------------------------
# Step 2: Localization
# ------------------------------------------------------------------------------
step_localization() {
    ui_screen_header "Regional & Localization Setup" 18

    if [ "$TEST_PRESET" -eq 1 ]; then
        SYSTEM_KEYMAP="us"
        SYSTEM_LOCALE="en_US.UTF-8"
        SYSTEM_TIMEZONE="Europe/Berlin"
        return 0
    fi

    local keymap_choice
    keymap_choice=$(ui_choose "Keyboard Layout" \
        "us (US English)" \
        "de-latin1 (German QWERTZ)" \
        "uk (UK English)" \
        "fr (French AZERTY)" \
        "es (Spanish)" \
        "it (Italian)" \
        "ch (Swiss German/French)" \
        "Custom layout...")

    case "$keymap_choice" in
        "de-latin1"*) SYSTEM_KEYMAP="de-latin1" ;;
        "us"*)        SYSTEM_KEYMAP="us" ;;
        "uk"*)        SYSTEM_KEYMAP="uk" ;;
        "fr"*)        SYSTEM_KEYMAP="fr" ;;
        "es"*)        SYSTEM_KEYMAP="es" ;;
        "it"*)        SYSTEM_KEYMAP="it" ;;
        "ch"*)        SYSTEM_KEYMAP="sg-latin1" ;;
        "Custom"*)
            SYSTEM_KEYMAP=$(ui_input "Console keymap:" "us, de-latin1" "us")
            ;;
        *) SYSTEM_KEYMAP="us" ;;
    esac

    if [ "$DEV_MODE" -eq 0 ] && command -v loadkeys &>/dev/null; then
        loadkeys "$SYSTEM_KEYMAP" &>/dev/null || true
    fi

    local locale_choice
    locale_choice=$(ui_choose "System Locale" \
        "en_US.UTF-8 (English - United States)" \
        "de_DE.UTF-8 (German - Germany)" \
        "en_GB.UTF-8 (English - Great Britain)" \
        "fr_FR.UTF-8 (French - France)" \
        "es_ES.UTF-8 (Spanish - Spain)" \
        "Custom locale...")

    case "$locale_choice" in
        "de_DE"*) SYSTEM_LOCALE="de_DE.UTF-8" ;;
        "en_US"*) SYSTEM_LOCALE="en_US.UTF-8" ;;
        "en_GB"*) SYSTEM_LOCALE="en_GB.UTF-8" ;;
        "fr_FR"*) SYSTEM_LOCALE="fr_FR.UTF-8" ;;
        "es_ES"*) SYSTEM_LOCALE="es_ES.UTF-8" ;;
        "Custom"*)
            SYSTEM_LOCALE=$(ui_input "Locale string:" "en_US.UTF-8" "en_US.UTF-8")
            ;;
        *) SYSTEM_LOCALE="en_US.UTF-8" ;;
    esac

    local tz_choice
    tz_choice=$(ui_choose "Timezone" \
        "Europe/Berlin" \
        "UTC" \
        "Europe/London" \
        "Europe/Paris" \
        "Europe/Vienna" \
        "Europe/Zurich" \
        "America/New_York" \
        "America/Chicago" \
        "America/Los_Angeles" \
        "Asia/Tokyo" \
        "Custom Timezone...")

    case "$tz_choice" in
        "Custom"*)
            SYSTEM_TIMEZONE=$(ui_input "Timezone:" "Region/City" "UTC")
            ;;
        *)
            SYSTEM_TIMEZONE="$tz_choice"
            ;;
    esac

    ui_footer_hint
}

# ------------------------------------------------------------------------------
# Step 3: Network & Hostname
# ------------------------------------------------------------------------------
step_network() {
    ui_screen_header "Network & Hostname Configuration" 16

    if [ "$TEST_PRESET" -eq 1 ]; then
        SYSTEM_HOSTNAME="ducklingos"
        return 0
    fi

    while true; do
        SYSTEM_HOSTNAME=$(ui_input "Hostname:" "e.g. ducklingos, my-pc" "$SYSTEM_HOSTNAME")
        if [[ "$SYSTEM_HOSTNAME" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*[a-zA-Z0-9]$ ]] || [[ "$SYSTEM_HOSTNAME" =~ ^[a-zA-Z0-9]$ ]]; then
            break
        else
            ui_error "Invalid hostname. Letters, digits, and hyphens only."
        fi
    done

    ui_footer_hint
}

# ------------------------------------------------------------------------------
# Step 4: User Accounts & Extra Users
# ------------------------------------------------------------------------------
step_users() {
    ui_screen_header "User Accounts & Security" 18

    if [ "$TEST_PRESET" -eq 1 ]; then
        USER_NAME="duckling"
        USER_REALNAME="Duckling User"
        USER_PASSWORD="devpassword123"
        ROOT_PASSWORD="devpassword123"
        ROOT_PASSWORD_SAME_AS_USER=1
        EXTRA_USERS=("guest:Guest User:no:guest123")
        return 0
    fi

    while true; do
        USER_NAME=$(ui_input "Primary Username:" "e.g. duckling, obsidian, user" "")
        if [[ "$USER_NAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            if [ "$USER_NAME" = "root" ]; then
                ui_error "Primary user cannot be 'root'."
            else
                break
            fi
        else
            ui_error "Invalid username. Lowercase alphanumeric only."
        fi
    done

    USER_REALNAME=$(ui_input "Full Name / Display Name:" "e.g. ducklingOS User" "$USER_NAME")

    while true; do
        echo ""
        USER_PASSWORD=$(ui_password "Password for '$USER_NAME':" "Enter strong password")
        if [ -z "$USER_PASSWORD" ]; then
            ui_error "Password cannot be empty."
            continue
        fi

        local pass_confirm
        pass_confirm=$(ui_password "Confirm Password:" "Re-type password")

        if [ "$USER_PASSWORD" = "$pass_confirm" ]; then
            ui_success "Password confirmed for '$USER_NAME'."
            break
        else
            ui_error "Passwords do not match. Please try again."
        fi
    done

    echo ""
    if ui_confirm "Use the same password for 'root' (Superuser)?"; then
        ROOT_PASSWORD_SAME_AS_USER=1
        ROOT_PASSWORD="$USER_PASSWORD"
        ui_success "Root will share the password with '$USER_NAME'."
    else
        ROOT_PASSWORD_SAME_AS_USER=0
        while true; do
            ROOT_PASSWORD=$(ui_password "Root Password:" "Enter root password")
            if [ -z "$ROOT_PASSWORD" ]; then
                ui_error "Root password cannot be empty."
                continue
            fi
            local root_confirm
            root_confirm=$(ui_password "Confirm Root Password:" "Re-type root password")
            if [ "$ROOT_PASSWORD" = "$root_confirm" ]; then
                ui_success "Root password verified."
                break
            else
                ui_error "Passwords do not match."
            fi
        done
    fi

    EXTRA_USERS=()
    echo ""
    while true; do
        if ! ui_confirm "Would you like to add an extra user?" "Yes" "No"; then
            break
        fi

        local ex_user=""
        local ex_fullname=""
        local ex_pass=""
        local ex_sudo="no"

        while true; do
            ex_user=$(ui_input "Extra Username:" "e.g. guest, work" "")
            if [[ "$ex_user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                if [ "$ex_user" = "$USER_NAME" ] || [ "$ex_user" = "root" ]; then
                    ui_error "Username '$ex_user' already exists or is reserved."
                else
                    break
                fi
            else
                ui_error "Invalid username. Lowercase alphanumeric only."
            fi
        done

        ex_fullname=$(ui_input "Display Name:" "Full Name for $ex_user" "$ex_user")

        while true; do
            ex_pass=$(ui_password "Password for '$ex_user':" "Enter password")
            local ex_confirm
            ex_confirm=$(ui_password "Confirm Password:" "Re-type password")
            if [ "$ex_pass" = "$ex_confirm" ] && [ -n "$ex_pass" ]; then
                break
            else
                ui_error "Passwords do not match."
            fi
        done

        if ui_confirm "Grant administrator (sudo) privileges to '$ex_user'?" "Yes" "No"; then
            ex_sudo="yes"
        else
            ex_sudo="no"
        fi

        EXTRA_USERS+=("${ex_user}:${ex_fullname}:${ex_sudo}:${ex_pass}")
        ui_success "Added extra user: $ex_user (sudo: $ex_sudo)"
        echo ""
    done

    ui_footer_hint
}

# ------------------------------------------------------------------------------
# Step 5: Storage & Target Installation
# ------------------------------------------------------------------------------
step_storage() {
    ui_screen_header "Target Installation Storage" 18

    local disk_list=()
    local disk_map=()

    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local devname size model
            devname=$(echo "$line" | awk '{print $1}')
            size=$(echo "$line" | awk '{print $2}')
            model=$(echo "$line" | cut -d' ' -f3-)
            disk_list+=("$devname ($size - $model)")
            disk_map+=("$devname")
        fi
    done < <(lsblk -d -n -p -o PATH,SIZE,MODEL -e 7,11 2>/dev/null)

    if [ ${#disk_list[@]} -eq 0 ]; then
        if [ "$DEV_MODE" -eq 1 ]; then
            disk_list+=("/dev/nvme0n1 (512.0G - ducklingOS Dev NVMe Drive)" "/dev/sda (1000.0G - Secondary Dev SSD)")
            disk_map+=("/dev/nvme0n1" "/dev/sda")
        else
            ui_error "No eligible target storage devices found!"
            exit 1
        fi
    fi

    if [ "$TEST_PRESET" -eq 1 ]; then
        TARGET_DISK="${disk_map[0]}"
        TARGET_PARTITION_MODE="auto"
        TARGET_FILESYSTEM="btrfs"
        SWAP_TYPE="zram"
        return 0
    fi

    local selected_entry
    selected_entry=$(ui_choose "Target Disk" "${disk_list[@]}" "Manual Target (Use already mounted /mnt)")

    if [[ "$selected_entry" == *"Manual Target"* ]]; then
        TARGET_PARTITION_MODE="manual"
        TARGET_DISK="manual"
        ui_info "Using pre-mounted filesystem at $MOUNT_POINT."
    else
        TARGET_PARTITION_MODE="auto"
        for i in "${!disk_list[@]}"; do
            if [ "${disk_list[$i]}" = "$selected_entry" ]; then
                TARGET_DISK="${disk_map[$i]}"
                break
            fi
        done
        ui_success "Target installation disk: $TARGET_DISK"
    fi

    if [ "$TARGET_PARTITION_MODE" = "auto" ]; then
        local fs_choice
        fs_choice=$(ui_choose "Filesystem" \
            "btrfs (Recommended - Subvolumes, Snapshots, zstd compression)" \
            "ext4 (Standard Classic Linux Filesystem)")

        if [[ "$fs_choice" == *"btrfs"* ]]; then
            TARGET_FILESYSTEM="btrfs"
            BTRFS_SUBVOLUMES=1
        else
            TARGET_FILESYSTEM="ext4"
            BTRFS_SUBVOLUMES=0
        fi

        local swap_choice
        swap_choice=$(ui_choose "Swap Configuration" \
            "zram (Recommended: compressed RAM, prolongs SSD life)" \
            "swapfile-4g (4 GB dedicated swap file)" \
            "swapfile-8g (8 GB dedicated swap file)" \
            "none (No swap)")

        case "$swap_choice" in
            "zram"*)        SWAP_TYPE="zram" ;;
            "swapfile-4g"*) SWAP_TYPE="swapfile"; SWAP_SIZE="4G" ;;
            "swapfile-8g"*) SWAP_TYPE="swapfile"; SWAP_SIZE="8G" ;;
            "none"*)        SWAP_TYPE="none" ;;
        esac
    fi

    ui_footer_hint
}

# ------------------------------------------------------------------------------
# Step 6: Software, Kernel & KDE Setup
# ------------------------------------------------------------------------------
step_software() {
    ui_screen_header "Software Environment" 18

    if [ "$TEST_PRESET" -eq 1 ]; then
        SYSTEM_KERNEL="linux-zen"
        INSTALL_DEV_TOOLS=1
        INSTALL_BLUETOOTH=1
        INSTALL_GAMING=1
        return 0
    fi

    local kernel_choice
    kernel_choice=$(ui_choose "Linux Kernel" \
        "linux-zen (Recommended - Low Latency & Desktop Optimized)" \
        "linux (Standard Upstream Linux Kernel)" \
        "linux-lts (Long Term Support - Maximum Stability)")

    case "$kernel_choice" in
        "linux-zen"*) SYSTEM_KERNEL="linux-zen" ;;
        "linux ("*)   SYSTEM_KERNEL="linux" ;;
        "linux-lts"*) SYSTEM_KERNEL="linux-lts" ;;
        *)            SYSTEM_KERNEL="linux-zen" ;;
    esac

    echo ""
    ui_info "Desktop Environment: KDE Plasma 6 (Wayland Session)"
    ui_info "Bootloader: Limine Bootloader"
    echo ""

    if ui_confirm "Install Gaming Suite (Steam, Proton, Heroic Launcher, Lutris, GameMode, MangoHud)?"; then
        INSTALL_GAMING=1
    else
        INSTALL_GAMING=0
    fi

    if ui_confirm "Install Developer Toolkit (Neovim, Zsh, Starship, Git, Tmux, Base-Devel)?"; then
        INSTALL_DEV_TOOLS=1
    else
        INSTALL_DEV_TOOLS=0
    fi

    if ui_confirm "Enable Bluetooth Stack (bluez, bluedevil)?"; then
        INSTALL_BLUETOOTH=1
    else
        INSTALL_BLUETOOTH=0
    fi

    ui_footer_hint
}

# ------------------------------------------------------------------------------
# Step 7: Review & Confirmation
# ------------------------------------------------------------------------------
step_review() {
    ui_screen_header "Installation Review" 20

    local extra_user_summary="None"
    if [ ${#EXTRA_USERS[@]} -gt 0 ]; then
        local names=()
        for u in "${EXTRA_USERS[@]}"; do
            local uname usudo
            uname=$(echo "$u" | cut -d':' -f1)
            usudo=$(echo "$u" | cut -d':' -f3)
            names+=("${uname} (sudo:${usudo})")
        done
        extra_user_summary=$(IFS=', '; echo "${names[*]}")
    fi

    local mode_label="LIVE (Changes will be written to disk)"
    if [ "$DEV_MODE" -eq 1 ]; then
        mode_label="⚡ DEV SIMULATION (Dry-run mode) ⚡"
    fi

    local lpad
    lpad=$(get_left_pad 60)

    gum style \
        --foreground "$OMARCHY_ITEM" \
        "${lpad}Distribution:   ${DISTRO_FULL_NAME}" \
        "${lpad}Install Mode:   ${mode_label}" \
        "${lpad}Hostname:       ${SYSTEM_HOSTNAME}" \
        "${lpad}Locale:         ${SYSTEM_LOCALE}" \
        "${lpad}Keymap:         ${SYSTEM_KEYMAP}" \
        "${lpad}Timezone:       ${SYSTEM_TIMEZONE}" \
        "${lpad}Primary User:   ${USER_NAME} (${USER_REALNAME}) [sudo: YES]" \
        "${lpad}Extra Users:    ${extra_user_summary}" \
        "${lpad}Target Disk:    ${TARGET_DISK} (${TARGET_PARTITION_MODE})" \
        "${lpad}Filesystem:     ${TARGET_FILESYSTEM^^}" \
        "${lpad}Swap Strategy:  ${SWAP_TYPE}" \
        "${lpad}Kernel:         ${SYSTEM_KERNEL}" \
        "${lpad}Desktop:        KDE Plasma 6 (Wayland)" \
        "${lpad}Bootloader:     Limine" \
        "${lpad}Gaming Suite:   $([ "$INSTALL_GAMING" -eq 1 ] && echo " Yes (Steam, Proton/ProtonUp, Heroic, Lutris, MangoHud)" || echo " No")" \
        "${lpad}Developer Tools:$([ "$INSTALL_DEV_TOOLS" -eq 1 ] && echo " Yes" || echo " No")" \
        "${lpad}Bluetooth:      $([ "$INSTALL_BLUETOOTH" -eq 1 ] && echo " Yes" || echo " No")"

    echo ""
    ui_footer_hint "enter confirm  ·  ctrl+c abort"

    if [ "$TEST_PRESET" -eq 1 ]; then
        ui_info "Preset confirmed automatically."
        return 0
    fi

    if [ "$DEV_MODE" -eq 1 ]; then
        if ! ui_confirm "Proceed with the test / dry-run simulation?"; then
            ui_warn "Dry run cancelled."
            exit 0
        fi
    else
        get_term_size
        gum style --foreground "$OMARCHY_DANGER" --bold --align center --width "$TERM_COLS" \
            "⚠ WARNING: ALL DATA ON ${TARGET_DISK} WILL BE PERMANENTLY ERASED!"
        if ! ui_confirm "Are you ABSOLUTELY sure you want to format and install?" "Yes, format disk" "No, abort"; then
            ui_warn "Installation cancelled. No changes were made."
            exit 0
        fi
    fi
}

# ------------------------------------------------------------------------------
# Step 8: Installation Engine (Omarchy Progress Bar View)
# ------------------------------------------------------------------------------
step_install() {
    local efi_part=""
    local root_part=""

    if [ "$TARGET_PARTITION_MODE" = "auto" ]; then
        if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
            efi_part="${TARGET_DISK}p1"
            root_part="${TARGET_DISK}p2"
        else
            efi_part="${TARGET_DISK}1"
            root_part="${TARGET_DISK}2"
        fi
    fi

    # Phase 1: Partitioning & Formatting
    ui_progress_bar 1 6 "Partitioning & Formatting Storage..." "Tip: Super + K shows all the key bindings"
    if [ "$TARGET_PARTITION_MODE" = "auto" ]; then
        ui_cmd "Wiping existing partition table on $TARGET_DISK" \
            wipefs -af "$TARGET_DISK"

        ui_cmd "Creating GPT partition label on $TARGET_DISK" \
            parted -s "$TARGET_DISK" mklabel gpt

        ui_cmd "Creating EFI System Partition (1024 MiB)" \
            parted -s "$TARGET_DISK" mkpart "ESP" fat32 1MiB 1025MiB

        ui_cmd "Setting ESP boot flag on $efi_part" \
            parted -s "$TARGET_DISK" set 1 esp on

        ui_cmd "Creating Root Linux Partition" \
            parted -s "$TARGET_DISK" mkpart "ducklingOS_Root" 1025MiB 100%

        ui_cmd "Formatting EFI Partition as FAT32 ($efi_part)" \
            mkfs.fat -F32 "$efi_part"

        if [ "$TARGET_FILESYSTEM" = "btrfs" ]; then
            ui_cmd "Formatting Root Partition as Btrfs ($root_part)" \
                mkfs.btrfs -f -L "ducklingOS" "$root_part"

            ui_cmd "Mounting root to construct subvolumes" \
                mount "$root_part" "$MOUNT_POINT"

            ui_cmd "Creating Btrfs subvolume @" \
                btrfs subvolume create "${MOUNT_POINT}/@"

            ui_cmd "Creating Btrfs subvolume @home" \
                btrfs subvolume create "${MOUNT_POINT}/@home"

            ui_cmd "Creating Btrfs subvolume @snapshots" \
                btrfs subvolume create "${MOUNT_POINT}/@snapshots"

            ui_cmd "Creating Btrfs subvolume @var_log" \
                btrfs subvolume create "${MOUNT_POINT}/@var_log"

            ui_cmd "Unmounting temporary root" \
                umount "$MOUNT_POINT"

            ui_cmd "Mounting subvolume @ to $MOUNT_POINT" \
                mount -o noatime,compress=zstd:1,subvol=@ "$root_part" "$MOUNT_POINT"

            ui_cmd "Creating directories in target root" \
                mkdir -p "${MOUNT_POINT}/boot" "${MOUNT_POINT}/home" "${MOUNT_POINT}/.snapshots" "${MOUNT_POINT}/var/log"

            ui_cmd "Mounting subvolume @home" \
                mount -o noatime,compress=zstd:1,subvol=@home "$root_part" "${MOUNT_POINT}/home"

            ui_cmd "Mounting subvolume @snapshots" \
                mount -o noatime,compress=zstd:1,subvol=@snapshots "$root_part" "${MOUNT_POINT}/.snapshots"

            ui_cmd "Mounting subvolume @var_log" \
                mount -o noatime,compress=zstd:1,subvol=@var_log "$root_part" "${MOUNT_POINT}/var/log"
        else
            ui_cmd "Formatting Root Partition as EXT4 ($root_part)" \
                mkfs.ext4 -F -L "ducklingOS" "$root_part"

            ui_cmd "Mounting root filesystem to $MOUNT_POINT" \
                mount "$root_part" "$MOUNT_POINT"

            ui_cmd "Creating /boot directory" \
                mkdir -p "${MOUNT_POINT}/boot"
        fi

        ui_cmd "Mounting EFI partition to ${MOUNT_POINT}/boot" \
            mount "$efi_part" "${MOUNT_POINT}/boot"
    fi

    # Phase 2: Installing Packages (Pacstrap)
    ui_progress_bar 2 6 "Installing Base System, KDE Plasma & Limine..." "Tip: Super + Space opens the application launcher"

    local base_pkgs=(
        "base"
        "base-devel"
        "linux-firmware"
        "$SYSTEM_KERNEL"
        "${SYSTEM_KERNEL}-headers"
        "sudo"
        "networkmanager"
        "which"
        "curl"
        "wget"
        "nano"
        "less"
        "limine"
        "efibootmgr"
        "pipewire"
        "wireplumber"
        "pipewire-audio"
        "pipewire-alsa"
        "pipewire-pulse"
        "pipewire-jack"
        "plasma-meta"
        "kde-applications-meta"
        "konsole"
        "dolphin"
        "sddm"
        "sddm-kcm"
        "ttf-jetbrains-mono-nerd"
        "noto-fonts"
        "papirus-icon-theme"
    )

    if [ "$TARGET_FILESYSTEM" = "btrfs" ]; then
        base_pkgs+=("btrfs-progs")
    fi

    if [ "$INSTALL_DEV_TOOLS" -eq 1 ]; then
        base_pkgs+=("git" "neovim" "zsh" "starship" "tmux" "ripgrep" "fd" "htop")
    fi

    if [ "$INSTALL_BLUETOOTH" -eq 1 ]; then
        base_pkgs+=("bluez" "bluez-utils" "bluedevil")
    fi

    if [ "$INSTALL_GAMING" -eq 1 ]; then
        base_pkgs+=(
            "steam"
            "lutris"
            "protonup-qt"
            "gamemode"
            "lib32-gamemode"
            "mangohud"
            "lib32-mangohud"
            "gamescope"
            "wine"
            "wine-gecko"
            "wine-mono"
            "vulkan-tools"
            "flatpak"
        )
    fi

    ui_cmd "Running pacstrap with ${#base_pkgs[@]} packages" \
        pacstrap -K "$MOUNT_POINT" "${base_pkgs[@]}"

    ui_cmd "Generating /etc/fstab" \
        bash -c "genfstab -U '$MOUNT_POINT' >> '${MOUNT_POINT}/etc/fstab'"

    # Phase 3: Localization & Network
    ui_progress_bar 3 6 "Configuring Localization & Network..." "Tip: Super + Return launches your terminal"

    ui_cmd "Setting timezone to $SYSTEM_TIMEZONE" \
        arch-chroot "$MOUNT_POINT" ln -sf "/usr/share/zoneinfo/$SYSTEM_TIMEZONE" /etc/localtime

    ui_cmd "Synchronizing hardware clock" \
        arch-chroot "$MOUNT_POINT" hwclock --systohc

    ui_cmd "Configuring /etc/locale.gen" \
        bash -c "sed -i 's/^#\(${SYSTEM_LOCALE}\)/\1/' '${MOUNT_POINT}/etc/locale.gen' || echo '${SYSTEM_LOCALE} UTF-8' >> '${MOUNT_POINT}/etc/locale.gen'"

    ui_cmd "Generating locales" \
        arch-chroot "$MOUNT_POINT" locale-gen

    ui_cmd "Writing /etc/locale.conf" \
        bash -c "echo 'LANG=${SYSTEM_LOCALE}' > '${MOUNT_POINT}/etc/locale.conf'"

    ui_cmd "Writing /etc/vconsole.conf" \
        bash -c "echo 'KEYMAP=${SYSTEM_KEYMAP}' > '${MOUNT_POINT}/etc/vconsole.conf'"

    ui_cmd "Writing /etc/hostname" \
        bash -c "echo '${SYSTEM_HOSTNAME}' > '${MOUNT_POINT}/etc/hostname'"

    ui_cmd "Writing /etc/hosts" \
        bash -c "cat <<EOF > '${MOUNT_POINT}/etc/hosts'
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${SYSTEM_HOSTNAME}.localdomain ${SYSTEM_HOSTNAME}
EOF"

    # Phase 4: User Accounts & Security
    ui_progress_bar 4 6 "Setting Up User Accounts & Sudo..." "Tip: Super + E opens the Dolphin file manager"

    local user_shell="/bin/bash"
    if [ "$INSTALL_DEV_TOOLS" -eq 1 ]; then
        user_shell="/bin/zsh"
    fi

    ui_cmd "Setting root password" \
        bash -c "echo 'root:${ROOT_PASSWORD}' | arch-chroot '$MOUNT_POINT' chpasswd"

    ui_cmd "Creating primary user $USER_NAME" \
        arch-chroot "$MOUNT_POINT" useradd -m -g users -G wheel,storage,power,audio,video -s "$user_shell" -c "$USER_REALNAME" "$USER_NAME"

    ui_cmd "Setting password for $USER_NAME" \
        bash -c "echo '${USER_NAME}:${USER_PASSWORD}' | arch-chroot '$MOUNT_POINT' chpasswd"

    ui_cmd "Configuring wheel group sudoers" \
        bash -c "cat <<EOF > '${MOUNT_POINT}/etc/sudoers.d/10-duckling-wheel'
%wheel ALL=(ALL:ALL) ALL
Defaults timestamp_timeout=30
EOF
chmod 0440 '${MOUNT_POINT}/etc/sudoers.d/10-duckling-wheel'"

    if [ ${#EXTRA_USERS[@]} -gt 0 ]; then
        for entry in "${EXTRA_USERS[@]}"; do
            local e_user e_fullname e_sudo e_pass
            e_user=$(echo "$entry" | cut -d':' -f1)
            e_fullname=$(echo "$entry" | cut -d':' -f2)
            e_sudo=$(echo "$entry" | cut -d':' -f3)
            e_pass=$(echo "$entry" | cut -d':' -f4)

            local extra_groups="users"
            if [ "$e_sudo" = "yes" ]; then
                extra_groups="users,wheel,storage,power,audio,video"
            fi

            ui_cmd "Creating extra user account: $e_user" \
                arch-chroot "$MOUNT_POINT" useradd -m -g users -G "$extra_groups" -s "$user_shell" -c "$e_fullname" "$e_user"

            ui_cmd "Setting password for $e_user" \
                bash -c "echo '${e_user}:${e_pass}' | arch-chroot '$MOUNT_POINT' chpasswd"
        done
    fi

    # Phase 5: ducklingOS Branding & Memory Optimization
    ui_progress_bar 5 6 "Applying ${DISTRO_NAME} Theme & Branding..." "Tip: Super + W closes the focused window"

    ui_cmd "Writing /etc/os-release" \
        bash -c "cat <<EOF > '${MOUNT_POINT}/etc/os-release'
NAME=\"${DISTRO_NAME}\"
PRETTY_NAME=\"${DISTRO_NAME} ${DISTRO_VERSION} \\\"${DISTRO_CODENAME}\\\" (KDE Plasma Edition)\"
ID=ducklingos
ID_LIKE=arch
VERSION=\"${DISTRO_VERSION}\"
VERSION_ID=\"${DISTRO_VERSION}\"
VERSION_CODENAME=\"${DISTRO_CODENAME}\"
BUILD_ID=rolling
ANSI_COLOR=\"0;33\"
HOME_URL=\"https://ducklingos.org\"
DOCUMENTATION_URL=\"https://wiki.ducklingos.org\"
SUPPORT_URL=\"https://ducklingos.org/support\"
BUG_REPORT_URL=\"https://github.com/the-duckling-group/ducklingOS/issues\"
LOGO=ducklingos
EOF"

    ui_cmd "Writing /etc/issue" \
        bash -c "cat <<EOF > '${MOUNT_POINT}/etc/issue'
     █████                     █████      ████   ███                         ███████     █████████ 
    ░░███                     ░░███      ░░███  ░░░                        ███░░░░░███  ███░░░░░███
  ███████  █████ ████  ██████  ░███ █████ ░███  ████  ████████    ███████ ███     ░░███░███    ░░░ 
 ███░░███ ░░███ ░███  ███░░███ ░███░░███  ░███ ░░███ ░░███░░███  ███░░███░███      ░███░░█████████ 
░███ ░███  ░███ ░███ ░███ ░░░  ░██████░   ░███  ░███  ░███ ░███ ░███ ░███░███      ░███ ░░░░░░░░███
░███ ░███  ░███ ░███ ░███  ███ ░███░░███  ░███  ░███  ░███ ░███ ░███ ░███░░███     ███  ███    ░███
░░████████ ░░████████░░██████  ████ █████ █████ █████ ████ █████░░███████ ░░░███████░  ░░█████████ 
 ░░░░░░░░   ░░░░░░░░  ░░░░░░  ░░░░ ░░░░░ ░░░░░ ░░░░░ ░░░░ ░░░░░  ░░░░░███   ░░░░░░░     ░░░░░░░░░  
                                                                 ███ ░███                          
                                                                ░░██████                           
                                                                 ░░░░░░                            
${DISTRO_NAME} ${DISTRO_VERSION} \"${DISTRO_CODENAME}\" (KDE Plasma) - \r (\l)
EOF"

    if [ "$SWAP_TYPE" = "zram" ]; then
        ui_cmd "Configuring zram swap generator" \
            bash -c "mkdir -p '${MOUNT_POINT}/etc/systemd/zram-generator.conf.d' && cat <<EOF > '${MOUNT_POINT}/etc/systemd/zram-generator.conf.d/zram.conf'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF"
    elif [ "$SWAP_TYPE" = "swapfile" ]; then
        ui_cmd "Creating $SWAP_SIZE swapfile" \
            arch-chroot "$MOUNT_POINT" fallocate -l "$SWAP_SIZE" /swapfile
        ui_cmd "Setting swapfile permissions" \
            arch-chroot "$MOUNT_POINT" chmod 600 /swapfile
        ui_cmd "Formatting swapfile" \
            arch-chroot "$MOUNT_POINT" mkswap /swapfile
        ui_cmd "Adding swapfile to /etc/fstab" \
            bash -c "echo '/swapfile none swap defaults 0 0' >> '${MOUNT_POINT}/etc/fstab'"
    fi

    # Phase 6: Limine Bootloader & Services
    ui_progress_bar 6 6 "Installing Limine Bootloader & Activating Services..." "Tip: Super + F toggles full screen"

    ui_cmd "Preparing Limine EFI directory (/boot/EFI/BOOT)" \
        mkdir -p "${MOUNT_POINT}/boot/EFI/BOOT"

    ui_cmd "Deploying Limine BOOTX64.EFI executable" \
        bash -c "cp '${MOUNT_POINT}/usr/share/limine/BOOTX64.EFI' '${MOUNT_POINT}/boot/EFI/BOOT/BOOTX64.EFI' || true"

    local root_kernel_cmd="root=${root_part} rw quiet"
    if [ "$TARGET_FILESYSTEM" = "btrfs" ]; then
        root_kernel_cmd="root=${root_part} rootflags=subvol=@ rw quiet"
    fi

    ui_cmd "Writing Limine configuration (/boot/limine.conf)" \
        bash -c "cat <<EOF > '${MOUNT_POINT}/boot/limine.conf'
# Limine Bootloader Configuration for ${DISTRO_NAME}
timeout: 3
interface_branding: ${DISTRO_NAME} (KDE Plasma)
interface_branding_color: 3
term_palette: 160b24;f87171;f5e042;fbbf24;a78bfa;c084fc;38bdf8;e2e8f0;7e6c99;f87171;f5e042;fbbf24;a78bfa;c084fc;38bdf8;ffffff

/${DISTRO_NAME} (KDE Plasma - ${SYSTEM_KERNEL})
    protocol: linux
    kernel_path: boot():/vmlinuz-${SYSTEM_KERNEL}
    module_path: boot():/initramfs-${SYSTEM_KERNEL}.img
    cmdline: ${root_kernel_cmd}

/${DISTRO_NAME} (Fallback initramfs)
    protocol: linux
    kernel_path: boot():/vmlinuz-${SYSTEM_KERNEL}
    module_path: boot():/initramfs-${SYSTEM_KERNEL}-fallback.img
    cmdline: ${root_kernel_cmd}
EOF"

    ui_cmd "Registering Limine with UEFI boot manager via efibootmgr" \
        arch-chroot "$MOUNT_POINT" efibootmgr --create --disk "$TARGET_DISK" --part 1 --loader '/EFI/BOOT/BOOTX64.EFI' --label 'ducklingOS (Limine)' --unicode || true

    ui_cmd "Enabling NetworkManager" \
        arch-chroot "$MOUNT_POINT" systemctl enable NetworkManager.service

    ui_cmd "Enabling SDDM (KDE Display Manager)" \
        arch-chroot "$MOUNT_POINT" systemctl enable sddm.service

    if [ "$INSTALL_BLUETOOTH" -eq 1 ]; then
        ui_cmd "Enabling bluetooth service" \
            arch-chroot "$MOUNT_POINT" systemctl enable bluetooth.service
    fi

    # Deploy ducklingos CLI wrapper, updater and pacman redirect hook
    ui_cmd "Installing ducklingos CLI and update suite" \
        bash -c "mkdir -p '${MOUNT_POINT}/usr/local/bin' && \
mkdir -p '${MOUNT_POINT}/var/lib/ducklingos' && \
cp '${LOCAL_UPDATE_SCRIPT}' '${MOUNT_POINT}/usr/local/bin/ducklingos-update' 2>/dev/null || \
curl -fsSL '${UPDATE_SCRIPT_RAW_URL}' -o '${MOUNT_POINT}/usr/local/bin/ducklingos-update' 2>/dev/null || true && \
chmod +x '${MOUNT_POINT}/usr/local/bin/ducklingos-update' 2>/dev/null || true && \
cat <<'STATE_JSON' > '${MOUNT_POINT}/var/lib/ducklingos/installed-versions.json'
${REMOTE_RELEASE_JSON}
STATE_JSON
cat <<'DUCK_CLI' > '${MOUNT_POINT}/usr/local/bin/ducklingos'
#!/usr/bin/env bash
set -e

cmd=\"\${1:-}\"
shift || true

case \"\$cmd\" in
    update)
        exec /usr/local/bin/ducklingos-update \"\$@\"
        ;;
    version|-v|--version)
        echo \"${DISTRO_NAME} ${DISTRO_VERSION} '${DISTRO_CODENAME}' (v${DISTRO_MINI_VERSION:-1.0.0})\"
        ;;
    help|-h|--help|\"\")
        echo \"ducklingOS System Management Utility\"
        echo \"Usage: ducklingos <command> [arguments]\"
        echo \"\"
        echo \"Commands:\"
        echo \"  update    Check and install official ducklingOS system and app updates\"
        echo \"  version   Print current ducklingOS release version\"
        echo \"  help      Show this help message\"
        ;;
    *)
        echo \"Unknown command: \$cmd\"
        echo \"Run 'ducklingos help' for available commands.\"
        exit 1
        ;;
esac
DUCK_CLI
chmod +x '${MOUNT_POINT}/usr/local/bin/ducklingos' && \
cat <<'PACMAN_WRAPPER' > '${MOUNT_POINT}/usr/local/bin/pacman'
#!/usr/bin/env bash
# Intercept system upgrades (pacman -Syu / -Syyu) and redirect to ducklingos update
for arg in \"\$@\"; do
    case \"\$arg\" in
        -Syu|-Suy|-Syyu|-Syyuy)
            echo -e \"\033[38;2;245;224;66m[!] ducklingOS System Notice:\033[0m\"
            echo -e \"    Direct 'pacman -Syu' system upgrades are managed by ducklingOS.\"
            echo -e \"    Please use \033[1;38;2;245;224;66mducklingos update\033[0m to ensure system & app consistency.\"
            echo -e \"\"
            echo -e \"    (To install individual packages without system upgrade, use: pacman -S <pkg>)\"
            exit 1
            ;;
    esac
done
exec /usr/bin/pacman \"\$@\"
PACMAN_WRAPPER
chmod +x '${MOUNT_POINT}/usr/local/bin/pacman'"

    # Execute update.sh with --install flag to perform post-install app rollout
    local update_runner="${LOCAL_UPDATE_SCRIPT}"
    if [ ! -f "$update_runner" ]; then
        update_runner="${MOUNT_POINT}/usr/local/bin/ducklingos-update"
    fi

    local update_cmd=( "$update_runner" "--install" "--target-root=${MOUNT_POINT}" "--repo=${DUCKLINGOS_REPO}" )
    if [ "$DEV_MODE" -eq 1 ]; then
        update_cmd+=( "--dev" "--test-preset" )
    fi
    ui_cmd "Executing ducklingOS Updater (--install mode)" \
        "${update_cmd[@]}"

    if [ "$DEV_MODE" -eq 1 ]; then
        mkdir -p "${PREVIEW_DIR}"
        cat <<EOF > "${PREVIEW_DIR}/simulation_manifest.txt"
${DISTRO_NAME} - Dev Simulation Manifest
Generated At: $(date)
Version: ${DISTRO_VERSION} "${DISTRO_CODENAME}" (v${DISTRO_MINI_VERSION:-1.0.0})
Hostname: $SYSTEM_HOSTNAME
Locale: $SYSTEM_LOCALE
Keymap: $SYSTEM_KEYMAP
Timezone: $SYSTEM_TIMEZONE
Primary User: $USER_NAME ($USER_REALNAME)
Extra Users Count: ${#EXTRA_USERS[@]}
Disk: $TARGET_DISK
Filesystem: $TARGET_FILESYSTEM
Kernel: $SYSTEM_KERNEL
Desktop: KDE Plasma (Wayland)
Bootloader: Limine
Theme: Dark Violet (#160b24) & Bright Yellow (#f5e042)
EOF
    fi

    # Completion View
    get_term_size
    ui_clear
    ui_vertical_pad 14
    ui_logo

    if [ "$DEV_MODE" -eq 1 ]; then
        gum style \
            --foreground "$OMARCHY_YELLOW" \
            --bold \
            --align center \
            --width "$TERM_COLS" \
            "🎉 DEV TEST RUN COMPLETED SUCCESSFULLY!"
        echo ""
        gum style \
            --foreground "$OMARCHY_ITEM" \
            --align center \
            --width "$TERM_COLS" \
            "Simulation finished without touching your physical storage or host system." \
            "Target: ${DISTRO_NAME} (Release: v${DISTRO_MINI_VERSION:-1.0.0} \"${DISTRO_CODENAME}\")" \
            "Test preview files written to: ${PREVIEW_DIR}"
    else
        gum style \
            --foreground "$OMARCHY_YELLOW" \
            --bold \
            --align center \
            --width "$TERM_COLS" \
            "🚀 ${DISTRO_NAME} INSTALLED SUCCESSFULLY!"
        echo ""
        gum style \
            --foreground "$OMARCHY_ITEM" \
            --align center \
            --width "$TERM_COLS" \
            "Release: ${DISTRO_NAME} ${DISTRO_VERSION} \"${DISTRO_CODENAME}\" (v${DISTRO_MINI_VERSION:-1.0.0})" \
            "Desktop: KDE Plasma 6 (Wayland)  ·  Bootloader: Limine" \
            "You may now unmount and reboot into your fresh ducklingOS system." \
            "Command: umount -R /mnt && reboot"
    fi
    echo ""
}

# ------------------------------------------------------------------------------
# Entrypoint & CLI Parsing
# ------------------------------------------------------------------------------
print_usage() {
    cat <<EOF
ducklingOS - Installer (Dark Violet & Yellow Centered Theme)

Usage:
  sudo ./install.sh --installation [options]
  ./install.sh --dev [options]

Flags & Options:
  --installation      Proceed with live system installation (fetches latest release JSON)
  --dev               Run in simulation / dry-run mode (no changes made to system or disks)
  --test-preset       Run with predefined automated answers (ideal for tests / CI)
  --repo=USER/REPO    Custom GitHub repository for system update & release manifests
  -h, --help          Show this help message and exit
  -v, --version       Display installer version and codename

Examples:
  ./install.sh --dev                 # Interactive TUI simulation (no root required)
  ./install.sh --dev --test-preset    # Automated dry-run test
  sudo ./install.sh --installation   # Live production installation of the latest release
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --installation|--install)
            export INSTALLATION_MODE=1
            shift
            ;;
        --dev)
            export DEV_MODE=1
            shift
            ;;
        --test-preset)
            export TEST_PRESET=1
            shift
            ;;
        --repo=*)
            export DUCKLINGOS_REPO="${1#*=}"
            export MANIFEST_RAW_URL="https://raw.githubusercontent.com/${DUCKLINGOS_REPO}/main/system-update.json"
            export MANIFEST_RELEASE_API="https://api.github.com/repos/${DUCKLINGOS_REPO}/releases/latest"
            shift
            ;;
        -v|--version)
            echo "ducklingOS Installer (Dark Violet & Yellow Theme)"
            exit 0
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

check_gum_installed

if [ "$DEV_MODE" -ne 1 ] && [ "$INSTALLATION_MODE" -ne 1 ]; then
    echo -e "\033[38;2;245;224;66m[!] ducklingOS Installer Safety Notice:\033[0m"
    echo -e "    To perform a live installation, run with: \033[1;38;2;245;224;66msudo ./install.sh --installation\033[0m"
    echo -e "    To test without making changes, run:      \033[1;38;2;245;224;66m./install.sh --dev\033[0m"
    echo ""
    exit 1
fi

if [ "$DEV_MODE" -ne 1 ] && [ "$EUID" -ne 0 ]; then
    ui_error "The live installer must be run as root (or with sudo)."
    echo -e "Tip: You can test the installer without root using: \033[38;2;245;224;66m./install.sh --dev\033[0m"
    exit 1
fi

if [ ! -f /etc/arch-release ]; then
    if [ "$DEV_MODE" -eq 1 ]; then
        ui_warn "Non-Arch environment detected. Continuing because --dev mode is active."
    else
        ui_error "ducklingOS must be installed from an Arch Linux live environment."
        exit 1
    fi
fi

trap 'echo -e "\n"; ui_warn "Installation interrupted by user."; exit 130' INT

main() {
    step_welcome
    step_localization
    step_network
    step_users
    step_storage
    step_software
    step_review
    step_install
}

main
