#!/usr/bin/env bash
# ==============================================================================
# ducklingOS - System & Application Updater
# Command: ducklingos update (or /usr/local/bin/ducklingos-update)
# ==============================================================================
set -euo pipefail

export DUCKLINGOS_REPO="the-duckling-group/ducklingOS"
export MANIFEST_RAW_URL="https://raw.githubusercontent.com/${DUCKLINGOS_REPO}/main/system-update.json"
export MANIFEST_RELEASE_API="https://api.github.com/repos/${DUCKLINGOS_REPO}/releases/latest"

export TARGET_ROOT=""
export LOCAL_STATE_DIR="/var/lib/ducklingos"
export LOCAL_STATE_FILE="${LOCAL_STATE_DIR}/installed-versions.json"

export DEV_MODE=0
export TEST_PRESET=0
export FORCE_UPDATE=0
export INSTALL_MODE=0

# Visual Styling - Omarchy Obsidian Theme
export OMARCHY_BG="#160b24"         # Deep Violet
export OMARCHY_YELLOW="#f5e042"     # Signature Yellow
export OMARCHY_HEADER="#a78bfa"     # Soft Lavender
export OMARCHY_MUTED="#7e6c99"      # Violet Gray
export OMARCHY_WARN="#fbbf24"       # Amber
export OMARCHY_DANGER="#f87171"     # Coral Red
export OMARCHY_CURSOR="#f5e042"     # Yellow Cursor
export OMARCHY_ITEM="#e2e8f0"       # Platinum White
export OMARCHY_TRACK="#3a2254"      # Dark Violet Track

# Default Fallback Structure if GitHub is unreachable
DEFAULT_JSON='{
  "os_name": "ducklingOS",
  "big_version": 1,
  "big_version_name": "Obsidian",
  "mini_version": "1.0.0",
  "codename": "Obsidian",
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
        "micro": "latest",
        "steam": "latest",
        "lutris": "latest",
        "protonup-qt": "latest",
        "gamemode": "latest",
        "mangohud": "latest"
      }
    },
    "aur": {
      "apps": {
        "heroic-games-launcher-bin": "latest",
        "proton-ge-custom-bin": "latest"
      }
    }
  }
}'

# Parse command-line flags
for arg in "$@"; do
    case "$arg" in
        --install|--installation)
            INSTALL_MODE=1
            ;;
        --target-root=*)
            TARGET_ROOT="${arg#*=}"
            ;;
        --dev)
            DEV_MODE=1
            ;;
        --test-preset)
            TEST_PRESET=1
            ;;
        --force|-f)
            FORCE_UPDATE=1
            ;;
        --repo=*)
            DUCKLINGOS_REPO="${arg#*=}"
            MANIFEST_RAW_URL="https://raw.githubusercontent.com/${DUCKLINGOS_REPO}/main/system-update.json"
            MANIFEST_RELEASE_API="https://api.github.com/repos/${DUCKLINGOS_REPO}/releases/latest"
            ;;
        --help|-h)
            cat <<EOF
ducklingOS Updater - ducklingos update

Usage:
  ducklingos update [flags]
  ./update.sh [flags]

Flags:
  --install        Invoked during system installation to perform initial app rollout
  --target-root=P  Target root directory when installing to a mounted chroot (e.g. /mnt)
  --dev            Simulation dry-run mode (no changes made to system)
  --test-preset    Run automated non-interactive update check (for tests/CI)
  --force, -f      Force reinstall/upgrade even if version matches local state
  --repo=USER/REPO Custom GitHub repository for system update manifests
  --help, -h       Display this help message
EOF
            exit 0
            ;;
    esac
done

if [ -n "$TARGET_ROOT" ]; then
    LOCAL_STATE_DIR="${TARGET_ROOT}/var/lib/ducklingos"
    LOCAL_STATE_FILE="${LOCAL_STATE_DIR}/installed-versions.json"
fi

# Check root unless in dev mode
if [ "$DEV_MODE" -eq 0 ] && [ "$EUID" -ne 0 ]; then
    echo -e "\033[38;2;245;224;66m[!] ducklingos update requires root privileges.\033[0m"
    echo -e "    Re-running with sudo..."
    exec sudo "$0" "$@"
fi

# Terminal size helper
get_term_size() {
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)
    TERM_LINES=$(tput lines 2>/dev/null || echo 24)
}

get_left_pad() {
    local target_width="${1:-80}"
    get_term_size
    local pad=0
    if [ "$TERM_COLS" -gt "$target_width" ]; then
        pad=$(( (TERM_COLS - target_width) / 2 ))
    fi
    printf '%*s' "$pad" ''
}

ui_vertical_pad() {
    local est_height="${1:-18}"
    get_term_size
    local vpad=0
    if [ "$TERM_LINES" -gt "$est_height" ]; then
        vpad=$(( (TERM_LINES - est_height) / 2 ))
    fi
    for ((i=0; i<vpad; i++)); do
        echo ""
    done
}

ui_clear() {
    clear 2>/dev/null || true
    printf "\033]11;%s\007" "$OMARCHY_BG" 2>/dev/null || true
}

ui_logo() {
    get_term_size
    if command -v gum >/dev/null 2>&1; then
        gum style \
            --foreground "$OMARCHY_YELLOW" \
            --bold \
            --align center \
            --width "$TERM_COLS" \
            "     █████                     █████      ████   ███                         ███████     █████████ " \
            "    ░░███                     ░░███      ░░███  ░░░                        ███░░░░░███  ███░░░░░███" \
            "  ███████  █████ ████  ██████  ░███ █████ ░███  ████  ████████    ███████ ███     ░░███░███    ░░░ " \
            " ███░░███ ░░███ ░███  ███░░███ ░███░░███  ░███ ░░███ ░░███░░███  ███░░███░███      ░███░░█████████ " \
            "░███ ░███  ░███ ░███ ░███ ░░░  ░██████░   ░███  ░███  ░███ ░███ ░███ ░███░███      ░███ ░░░░░░░░███" \
            "░███ ░███  ░███ ░███ ░███  ███ ░███░░███  ░███  ░███  ░███ ░███ ░███ ░███░░███     ███  ███    ░███" \
            "░░████████ ░░████████░░██████  ████ █████ █████ █████ ████ █████░░███████ ░░░███████░  ░░█████████ " \
            " ░░░░░░░░   ░░░░░░░░  ░░░░░░  ░░░░ ░░░░░ ░░░░░ ░░░░░ ░░░░ ░░░░░  ░░░░░███   ░░░░░░░     ░░░░░░░░░  " \
            "                                                                 ███ ░███                          " \
            "                                                                ░░██████                           " \
            "                                                                 ░░░░░░                            "
    else
        cat <<'EOF'
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
EOF
    fi
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
    local hint="${1:-enter continue  ·  ctrl+c exit}"
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

ui_confirm() {
    local prompt="$1"
    local affirmative="${2:-Yes}"
    local negative="${3:-No}"
    local lpad
    lpad=$(get_left_pad 71)

    if [ "$TEST_PRESET" -eq 1 ] || [ "$INSTALL_MODE" -eq 1 ]; then
        echo -e "${lpad}ℹ Proceeding with '${affirmative}'."
        return 0
    fi

    gum confirm \
        --prompt.foreground="$OMARCHY_HEADER" \
        --selected.background="$OMARCHY_YELLOW" \
        --selected.foreground="#160b24" \
        --unselected.background="#22123b" \
        --unselected.foreground="#e2e8f0" \
        --affirmative="$affirmative" \
        --negative="$negative" \
        "${lpad}${prompt}"
}

ui_progress_bar() {
    local current="$1"
    local total="$2"
    local title="$3"
    local tip="${4:-}"
    local lpad
    lpad=$(get_left_pad 42)

    ui_screen_header "$title" 16
    local filled=$(( (current * 42) / total ))
    local empty=$(( 42 - filled ))
    local bar_f=""
    local bar_e=""
    for ((i=0; i<filled; i++)); do bar_f="${bar_f}█"; done
    for ((i=0; i<empty; i++)); do bar_e="${bar_e}░"; done

    echo -e "${lpad}\033[38;2;245;224;66m${bar_f}\033[38;2;58;34;84m${bar_e}\033[0m\n"
    if [ -n "$tip" ]; then
        gum style --foreground "$OMARCHY_MUTED" --align center --width "$TERM_COLS" "$tip"
        echo ""
    fi
}

run_step() {
    local desc="$1"
    shift
    local lpad
    lpad=$(get_left_pad 71)
    echo -e "${lpad}\033[38;2;245;224;66m❯\033[0m \033[38;2;226;232;240m${desc}\033[0m"
    if [ "$DEV_MODE" -eq 1 ]; then
        echo -e "${lpad}  \033[38;2;126;108;153m[SIMULATION] $*\033[0m"
        sleep 0.2
        return 0
    fi

    if [ -n "$TARGET_ROOT" ]; then
        arch-chroot "$TARGET_ROOT" "$@"
    else
        "$@"
    fi
}

# ==============================================================================
# JSON STATE & GITHUB RELEASE RESOLUTION
# ==============================================================================

read_local_state() {
    LOCAL_OS_NAME="ducklingOS"
    LOCAL_BIG_VERSION="1"
    LOCAL_BIG_NAME="Obsidian"
    LOCAL_MINI_VERSION="1.0.0"

    if [ -f "$LOCAL_STATE_FILE" ]; then
        LOCAL_OS_NAME=$(python3 -c "import json; d=json.load(open('${LOCAL_STATE_FILE}')); print(d.get('os_name', 'ducklingOS'))" 2>/dev/null || echo "ducklingOS")
        LOCAL_BIG_VERSION=$(python3 -c "import json; d=json.load(open('${LOCAL_STATE_FILE}')); print(d.get('big_version', '1'))" 2>/dev/null || echo "1")
        LOCAL_BIG_NAME=$(python3 -c "import json; d=json.load(open('${LOCAL_STATE_FILE}')); print(d.get('big_version_name', 'Obsidian'))" 2>/dev/null || echo "Obsidian")
        LOCAL_MINI_VERSION=$(python3 -c "import json; d=json.load(open('${LOCAL_STATE_FILE}')); print(d.get('mini_version', '1.0.0'))" 2>/dev/null || echo "1.0.0")
    fi
}

fetch_remote_manifest() {
    REMOTE_JSON=""

    if [ "$DEV_MODE" -eq 1 ]; then
        # In DEV mode, simulate a newer release
        REMOTE_JSON='{
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
        "micro": "latest",
        "steam": "latest",
        "lutris": "latest",
        "protonup-qt": "latest",
        "gamemode": "latest",
        "mangohud": "latest"
      }
    },
    "aur": {
      "apps": {
        "heroic-games-launcher-bin": "latest",
        "proton-ge-custom-bin": "latest"
      }
    }
  }
}'
        return 0
    fi

    # 1. Check latest release from GitHub API
    local api_resp
    api_resp=$(curl -fsSL -H "Accept: application/vnd.github+json" "$MANIFEST_RELEASE_API" 2>/dev/null || true)

    if [ -n "$api_resp" ]; then
        local asset_url
        asset_url=$(echo "$api_resp" | grep -Po '"browser_download_url":\s*"\K[^"]*system-update\.json' | head -n 1 || echo "")
        if [ -n "$asset_url" ]; then
            REMOTE_JSON=$(curl -fsSL "$asset_url" 2>/dev/null || true)
        fi
    fi

    # 2. Check main branch raw file if asset not attached
    if [ -z "$REMOTE_JSON" ]; then
        REMOTE_JSON=$(curl -fsSL "$MANIFEST_RAW_URL" 2>/dev/null || true)
    fi

    # 3. Fallback to default JSON if offline or repo not yet published
    if [ -z "$REMOTE_JSON" ]; then
        REMOTE_JSON="$DEFAULT_JSON"
    fi
}

# ==============================================================================
# MAIN WORKFLOW
# ==============================================================================

main() {
    read_local_state

    # Screen 1: Welcome & Check
    local header_title="ducklingOS System & Apps Update"
    if [ "$INSTALL_MODE" -eq 1 ]; then
        header_title="ducklingOS Post-Install Application Setup"
    fi

    ui_screen_header "$header_title" 20
    if [ "$INSTALL_MODE" -eq 1 ]; then
        ui_info "Mode: --install (Invoked by ducklingOS Installer)"
    fi
    ui_info "Checking latest release from GitHub (https://github.com/${DUCKLINGOS_REPO})..."

    fetch_remote_manifest

    # Parse Remote Values
    REMOTE_OS_NAME=$(python3 -c "import json; d=json.loads('''${REMOTE_JSON}'''); print(d.get('os_name', 'ducklingOS'))")
    REMOTE_BIG_VERSION=$(python3 -c "import json; d=json.loads('''${REMOTE_JSON}'''); print(d.get('big_version', 1))")
    REMOTE_BIG_NAME=$(python3 -c "import json; d=json.loads('''${REMOTE_JSON}'''); print(d.get('big_version_name', 'Obsidian'))")
    REMOTE_MINI_VERSION=$(python3 -c "import json; d=json.loads('''${REMOTE_JSON}'''); print(d.get('mini_version', '1.0.0'))")

    echo ""
    if [ "$INSTALL_MODE" -eq 1 ]; then
        ui_info "Target System:  ${REMOTE_OS_NAME} ${REMOTE_BIG_VERSION} \"${REMOTE_BIG_NAME}\" (v${REMOTE_MINI_VERSION})"
    else
        ui_info "Current Local:  ${LOCAL_OS_NAME} ${LOCAL_BIG_VERSION} \"${LOCAL_BIG_NAME}\" (v${LOCAL_MINI_VERSION})"
        ui_info "Remote Release: ${REMOTE_OS_NAME} ${REMOTE_BIG_VERSION} \"${REMOTE_BIG_NAME}\" (v${REMOTE_MINI_VERSION})"
    fi

    # Version comparison check (only in update mode, not in --install mode)
    if [ "$INSTALL_MODE" -eq 0 ] && [ "$FORCE_UPDATE" -eq 0 ] && [ "$DEV_MODE" -eq 0 ]; then
        if [ "$LOCAL_BIG_VERSION" = "$REMOTE_BIG_VERSION" ] && [ "$LOCAL_MINI_VERSION" = "$REMOTE_MINI_VERSION" ]; then
            echo ""
            ui_success "Your system is already running the latest version: ${LOCAL_OS_NAME} ${LOCAL_MINI_VERSION}!"
            ui_info "No update required. Run 'ducklingos update --force' to force re-running update steps."
            ui_footer_hint "enter exit"
            if [ "$TEST_PRESET" -eq 0 ]; then
                read -r _ || true
            fi
            exit 0
        fi
    fi

    # Read apps from remote manifest
    mapfile -t PACMAN_APPS < <(python3 -c "import json; d=json.loads('''${REMOTE_JSON}'''); print('\n'.join(d.get('packages',{}).get('pacman',{}).get('apps',{}).keys()))")
    mapfile -t AUR_APPS < <(python3 -c "import json; d=json.loads('''${REMOTE_JSON}'''); print('\n'.join(d.get('packages',{}).get('aur',{}).get('apps',{}).keys()))")

    echo ""
    local lpad
    lpad=$(get_left_pad 71)
    echo -e "${lpad}\033[38;2;167;139;250mTarget Release Applications:\033[0m"
    for app in "${PACMAN_APPS[@]}"; do
        [ -n "$app" ] && echo -e "${lpad}  • \033[38;2;245;224;66m${app}\033[0m (pacman: latest)"
    done
    for app in "${AUR_APPS[@]}"; do
        [ -n "$app" ] && echo -e "${lpad}  • \033[38;2;192;132;252m${app}\033[0m (aur: latest)"
    done

    ui_footer_hint "enter start  ·  ctrl+c exit"
    if [ "$TEST_PRESET" -eq 0 ] && [ "$INSTALL_MODE" -eq 0 ]; then
        read -r _ || true
    fi

    # Screen 2: Confirmation
    if [ "$INSTALL_MODE" -eq 0 ]; then
        ui_screen_header "Update Confirmation" 16
        if ! ui_confirm "Update to ${REMOTE_OS_NAME} ${REMOTE_BIG_VERSION} \"${REMOTE_BIG_NAME}\" (v${REMOTE_MINI_VERSION})?"; then
            ui_warn "Update cancelled by user."
            exit 0
        fi
    fi

    # Phase 1: Base System / Upgrade
    if [ "$INSTALL_MODE" -eq 1 ]; then
        ui_progress_bar 1 4 "Phase 1/4: Synchronizing Package Databases..." "Updating repositories on target system"
        run_step "Synchronizing repositories" \
            pacman -Sy --noconfirm
    else
        ui_progress_bar 1 4 "Phase 1/4: Upgrading Base System & Repositories..." "Synchronizing Arch Linux package databases"
        run_step "Updating Arch mirrors & system packages" \
            pacman -Syu --noconfirm --needed
    fi

    # Phase 2: Installing/Updating Core Applications from Release JSON
    local phase2_title="Phase 2/4: Deploying Release Applications..."
    if [ "$INSTALL_MODE" -eq 1 ]; then
        phase2_title="Phase 2/4: Installing Initial System Applications..."
    fi
    ui_progress_bar 2 4 "$phase2_title" "Installing specified release applications"
    if [ ${#PACMAN_APPS[@]} -gt 0 ]; then
        run_step "Installing Pacman apps (${PACMAN_APPS[*]})" \
            pacman -S --needed --noconfirm "${PACMAN_APPS[@]}"
    fi

    # Phase 3: AUR Packages
    ui_progress_bar 3 4 "Phase 3/4: Processing Extra & AUR Applications..." "Checking AUR packages from release manifest (Heroic Launcher, etc.)"
    local aur_helper=""
    if [ -n "$TARGET_ROOT" ]; then
        if [ -x "${TARGET_ROOT}/usr/bin/yay" ]; then aur_helper="yay";
        elif [ -x "${TARGET_ROOT}/usr/bin/paru" ]; then aur_helper="paru"; fi
    else
        if command -v yay >/dev/null 2>&1; then aur_helper="yay";
        elif command -v paru >/dev/null 2>&1; then aur_helper="paru"; fi
    fi

    if [ -n "$aur_helper" ] && [ ${#AUR_APPS[@]} -gt 0 ]; then
        run_step "Installing AUR apps via ${aur_helper} (${AUR_APPS[*]})" \
            "$aur_helper" -S --needed --noconfirm "${AUR_APPS[@]}"
    else
        ui_info "AUR helper not pre-installed in root - registering AUR apps for first boot."
        # If flatpak is installed and heroic-games-launcher is requested, make sure flatpak heroic can be deployed or saved
        if [ ${#AUR_APPS[@]} -gt 0 ]; then
            for a_app in "${AUR_APPS[@]}"; do
                if [[ "$a_app" == *"heroic"* ]]; then
                    ui_info "Heroic Games Launcher registered via manifest (${a_app})."
                fi
            done
        fi
    fi

    # Phase 4: Finalizing & Writing New Version State
    ui_progress_bar 4 4 "Phase 4/4: Finalizing Setup State..." "Recording updated version tag"
    if [ "$DEV_MODE" -eq 0 ]; then
        mkdir -p "$LOCAL_STATE_DIR"
    fi

    run_step "Recording release manifest to ${LOCAL_STATE_FILE}" \
        bash -c "cat <<EOF > '${LOCAL_STATE_FILE}'
${REMOTE_JSON}
EOF"

    # Completion Screen
    ui_screen_header "Setup Complete" 16
    if [ "$INSTALL_MODE" -eq 1 ]; then
        ui_success "${REMOTE_OS_NAME} applications installed successfully!"
    else
        ui_success "${REMOTE_OS_NAME} updated to v${REMOTE_MINI_VERSION} successfully!"
    fi
    ui_info "OS:      ${REMOTE_OS_NAME} ${REMOTE_BIG_VERSION} \"${REMOTE_BIG_NAME}\""
    ui_info "Version: v${REMOTE_MINI_VERSION}"
    echo ""
    ui_footer_hint "enter finish"
    if [ "$TEST_PRESET" -eq 0 ] && [ "$INSTALL_MODE" -eq 0 ]; then
        read -r _ || true
    fi
}

main "$@"
