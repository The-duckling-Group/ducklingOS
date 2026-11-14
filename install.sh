#!/usr/bin/env bash
# ==============================================================================
# ducklingOS 1 "Obsidian" - All-in-One Installer
# ==============================================================================
# Single-script installer for ducklingOS 1 "Obsidian" built on Arch Linux.
# Features:
#   - Omarchy-style TUI powered by Charmbracelet gum
#   - Desktop Environment: KDE Plasma only (Obsidian Edition)
#   - Bootloader: Limine only
#   - Interactive prompts: Hostname, Localization, Users & Extra Users, Storage
#   - BTRFS (subvolumes) or EXT4
#   - --dev simulation mode (dry run without touching system/disks)
# ==============================================================================

set -eo pipefail

# ------------------------------------------------------------------------------
# Default State & Variables
# ------------------------------------------------------------------------------
export DISTRO_NAME="ducklingOS"
export DISTRO_VERSION="1"
export DISTRO_CODENAME="Obsidian"
export DISTRO_FULL_NAME="${DISTRO_NAME} ${DISTRO_VERSION} \"${DISTRO_CODENAME}\""

export DEV_MODE=0
export TEST_PRESET=0
export PREVIEW_DIR="/tmp/ducklingos-dev-preview"

# Localization Defaults
export SYSTEM_KEYMAP="us"
export SYSTEM_LOCALE="en_US.UTF-8"
export SYSTEM_TIMEZONE="UTC"

# Network Defaults
export SYSTEM_HOSTNAME="duckling-obsidian"

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
export SWAP_TYPE="zram"             # zram, swapfile-4g, swapfile-8g, or none
export SWAP_SIZE="4G"
export MOUNT_POINT="/mnt"

# Fixed Software Environment
export SYSTEM_KERNEL="linux-zen"    # linux-zen (default), selectable: linux, linux-zen, linux-lts
export SYSTEM_PROFILE="kde"         # Fixed to KDE Plasma
export SYSTEM_BOOTLOADER="limine"   # Fixed to Limine
export INSTALL_DEV_TOOLS=1
export INSTALL_BLUETOOTH=1

# Color Palette (Obsidian Theme)
export COLOR_PRIMARY="135"          # Deep Purple
export COLOR_SECONDARY="45"         # Cyan
export COLOR_ACCENT="212"           # Pink Accent
export COLOR_SUCCESS="42"           # Emerald Green
export COLOR_WARNING="214"          # Orange
export COLOR_DANGER="196"           # Crimson Red
export COLOR_MUTED="242"            # Dark Gray

# ------------------------------------------------------------------------------
# UI & Helper Functions
# ------------------------------------------------------------------------------
check_gum_installed() {
    if ! command -v gum &>/dev/null; then
        echo -e "\033[1;33m[!] 'gum' (by Charmbracelet) is required for the ducklingOS TUI.\033[0m"
        if [ "$DEV_MODE" -eq 1 ] && [ "$EUID" -ne 0 ]; then
            echo -e "\033[1;31mPlease install 'gum' using: sudo pacman -S gum\033[0m"
            exit 1
        elif command -v pacman &>/dev/null && [ "$EUID" -eq 0 ]; then
            echo -e "\033[1;32m[*] Installing 'gum' via pacman...\033[0m"
            pacman -Sy --noconfirm gum || {
                echo -e "\033[1;31mFailed to install gum. Aborting.\033[0m"
                exit 1
            }
        else
            echo -e "\033[1;31mError: gum is missing and cannot be installed automatically.\033[0m"
            exit 1
        fi
    fi
}

ui_clear() {
    clear 2>/dev/null || true
}

ui_banner() {
    local dev_badge=""
    if [ "$DEV_MODE" -eq 1 ]; then
        dev_badge=" [DEV / DRY-RUN SIMULATION MODE]"
    fi

    gum style \
        --foreground "$COLOR_PRIMARY" \
        --border-foreground "$COLOR_SECONDARY" \
        --border rounded \
        --align center \
        --width 72 \
        --margin "0 1" \
        --padding "1 2" \
        "  ██████╗ ██╗   ██╗ ██████╗██╗  ██╗██╗     ██╗███╗   ██╗ ██████╗  ██████╗ ███████╗" \
        "  ██╔══██╗██║   ██║██╔════╝██║ ██╔╝██║     ██║████╗  ██║██╔════╝ ██╔═══██╗██╔════╝" \
        "  ██║  ██║██║   ██║██║     █████╔╝ ██║     ██║██╔██╗ ██║██║  ███╗██║   ██║███████╗" \
        "  ██║  ██║██║   ██║██║     ██╔═██╗ ██║     ██║██║╚██╗██║██║   ██║██║   ██║╚════██║" \
        "  ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║██║ ╚████║╚██████╔╝╚██████╔╝███████║" \
        "  ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚══════╝" \
        "" \
        "ducklingOS 1 \"Obsidian\" System Installer$dev_badge" \
        "KDE Plasma Edition • Limine Bootloader • Modern Arch Architecture"
}

ui_dev_warning() {
    if [ "$DEV_MODE" -eq 1 ]; then
        gum style \
            --foreground "$COLOR_WARNING" \
            --border double \
            --border-foreground "$COLOR_WARNING" \
            --padding "0 1" \
            --margin "1 0" \
            " ⚡ DEV MODE ACTIVE: NO REAL CHANGES WILL BE MADE TO YOUR STORAGE OR SYSTEM! ⚡ "
    fi
}

ui_header() {
    local title="$1"
    local desc="$2"
    echo ""
    gum style --foreground "$COLOR_SECONDARY" --bold "❯ $title"
    if [ -n "$desc" ]; then
        gum style --foreground "$COLOR_MUTED" "  $desc"
    fi
    echo ""
}

ui_step() {
    local step="$1"
    local total="$2"
    local name="$3"
    gum style --foreground "$COLOR_ACCENT" --bold "[$step/$total] $name"
}

ui_info() {
    gum style --foreground "$COLOR_SECONDARY" "  ℹ $1"
}

ui_success() {
    gum style --foreground "$COLOR_SUCCESS" --bold "  ✔ $1"
}

ui_warn() {
    gum style --foreground "$COLOR_WARNING" --bold "  ⚠ $1"
}

ui_error() {
    gum style --foreground "$COLOR_DANGER" --bold "  ✖ $1"
}

ui_input() {
    local prompt="$1"
    local placeholder="$2"
    local default_val="$3"
    gum input --prompt "$prompt: " --placeholder "$placeholder" --value "$default_val" --width 60
}

ui_password() {
    local prompt="$1"
    local placeholder="$2"
    gum input --password --prompt "$prompt: " --placeholder "$placeholder" --width 60
}

ui_choose() {
    gum choose "$@"
}

ui_confirm() {
    local prompt="$1"
    local default_btn="${2:-Yes}"
    gum confirm "$prompt" --default="$default_btn"
}

ui_cmd() {
    local cmd_desc="$1"
    shift
    local cmd=("$@")

    if [ "$DEV_MODE" -eq 1 ]; then
        gum style \
            --foreground "$COLOR_WARNING" \
            --border rounded \
            --border-foreground "$COLOR_MUTED" \
            --padding "0 1" \
            " [SIMULATED ACTION] $cmd_desc" \
            " Command: ${cmd[*]}"
        mkdir -p "$PREVIEW_DIR"
        return 0
    else
        echo -e "\033[0;36m[EXEC]\033[0m $cmd_desc"
        "${cmd[@]}"
        local status=$?
        if [ $status -ne 0 ]; then
            ui_error "Command failed with exit code $status: ${cmd[*]}"
            return $status
        fi
        return 0
    fi
}

# ------------------------------------------------------------------------------
# Step 1: Welcome & Pre-Flight Diagnostics
# ------------------------------------------------------------------------------
step_welcome() {
    ui_clear
    ui_banner
    ui_dev_warning

    ui_header "Welcome to ducklingOS 1 \"Obsidian\"" \
              "Featuring KDE Plasma desktop and the next-generation Limine bootloader."

    echo ""
    gum style --bold --foreground "$COLOR_SECONDARY" "System Diagnostics:"

    if [ -d "/sys/firmware/efi/efivars" ]; then
        ui_success "Boot Mode: UEFI (Optimal for Limine)"
    else
        ui_warn "Boot Mode: BIOS / MBR (Limine supports BIOS, but UEFI is recommended)"
    fi

    local total_ram
    total_ram=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
    if [ -n "$total_ram" ]; then
        ui_info "Total Memory: $total_ram"
    fi

    if ping -c 1 -W 2 archlinux.org &>/dev/null; then
        ui_success "Network: Connected to Internet"
    else
        if [ "$DEV_MODE" -eq 1 ]; then
            ui_warn "Network: No active connection detected (Simulating in Dev Mode)"
        else
            ui_warn "Network: No active internet connection. Connect via 'iwctl' or Ethernet."
        fi
    fi

    echo ""
    if [ "$TEST_PRESET" -eq 1 ]; then
        ui_info "Auto-test preset enabled: Continuing automatically."
        return 0
    fi

    if ! ui_confirm "Ready to configure your ducklingOS 1 installation?"; then
        ui_warn "Installation cancelled by user."
        exit 0
    fi
}

# ------------------------------------------------------------------------------
# Step 2: Localization
# ------------------------------------------------------------------------------
step_localization() {
    ui_clear
    ui_banner
    ui_dev_warning
    ui_step 2 7 "Localization & Regional Settings"

    ui_header "Keyboard Layout" "Select your physical keyboard layout"

    if [ "$TEST_PRESET" -eq 1 ]; then
        SYSTEM_KEYMAP="us"
        SYSTEM_LOCALE="en_US.UTF-8"
        SYSTEM_TIMEZONE="UTC"
        ui_info "Preset selected: Keymap=$SYSTEM_KEYMAP, Locale=$SYSTEM_LOCALE, Timezone=$SYSTEM_TIMEZONE"
        return 0
    fi

    local keymap_choice
    keymap_choice=$(ui_choose "us (US English)" \
                              "de-latin1 (German QWERTZ)" \
                              "uk (UK English)" \
                              "fr (French AZERTY)" \
                              "es (Spanish)" \
                              "it (Italian)" \
                              "ch (Swiss German/French)" \
                              "Custom keyboard layout...")

    case "$keymap_choice" in
        "de-latin1"*) SYSTEM_KEYMAP="de-latin1" ;;
        "us"*)        SYSTEM_KEYMAP="us" ;;
        "uk"*)        SYSTEM_KEYMAP="uk" ;;
        "fr"*)        SYSTEM_KEYMAP="fr" ;;
        "es"*)        SYSTEM_KEYMAP="es" ;;
        "it"*)        SYSTEM_KEYMAP="it" ;;
        "ch"*)        SYSTEM_KEYMAP="sg-latin1" ;;
        "Custom"*)
            SYSTEM_KEYMAP=$(ui_input "Enter console keymap name" "e.g. us, de-latin1" "us")
            ;;
        *) SYSTEM_KEYMAP="us" ;;
    esac

    if [ "$DEV_MODE" -eq 0 ] && command -v loadkeys &>/dev/null; then
        loadkeys "$SYSTEM_KEYMAP" &>/dev/null || true
    fi
    ui_success "Console keymap set to: $SYSTEM_KEYMAP"

    ui_header "System Locale" "Select the default language and regional formatting"
    local locale_choice
    locale_choice=$(ui_choose "en_US.UTF-8 (English - United States)" \
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
            SYSTEM_LOCALE=$(ui_input "Enter locale string" "e.g. en_US.UTF-8" "en_US.UTF-8")
            ;;
        *) SYSTEM_LOCALE="en_US.UTF-8" ;;
    esac
    ui_success "System locale selected: $SYSTEM_LOCALE"

    ui_header "Timezone" "Select system timezone"
    local tz_choice
    tz_choice=$(ui_choose "Europe/Berlin" \
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
            SYSTEM_TIMEZONE=$(ui_input "Enter timezone (Region/City)" "e.g. Europe/Berlin" "UTC")
            ;;
        *)
            SYSTEM_TIMEZONE="$tz_choice"
            ;;
    esac
    ui_success "System timezone set to: $SYSTEM_TIMEZONE"
}

# ------------------------------------------------------------------------------
# Step 3: Network & Hostname
# ------------------------------------------------------------------------------
step_network() {
    ui_clear
    ui_banner
    ui_dev_warning
    ui_step 3 7 "Network & Hostname"

    ui_header "System Hostname" "Assign an identifying name for your ducklingOS machine on the network"

    if [ "$TEST_PRESET" -eq 1 ]; then
        SYSTEM_HOSTNAME="duckling-obsidian"
        ui_info "Preset selected: Hostname=$SYSTEM_HOSTNAME"
        return 0
    fi

    while true; do
        SYSTEM_HOSTNAME=$(ui_input "Enter Hostname" "e.g. duckling-pc, obsidian-box" "$SYSTEM_HOSTNAME")
        if [[ "$SYSTEM_HOSTNAME" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*[a-zA-Z0-9]$ ]] || [[ "$SYSTEM_HOSTNAME" =~ ^[a-zA-Z0-9]$ ]]; then
            break
        else
            ui_error "Invalid hostname. Must contain only letters, numbers, and hyphens."
        fi
    done

    ui_success "Hostname configured as: $SYSTEM_HOSTNAME"
}

# ------------------------------------------------------------------------------
# Step 4: User Accounts & Extra Users
# ------------------------------------------------------------------------------
step_users() {
    ui_clear
    ui_banner
    ui_dev_warning
    ui_step 4 7 "User Accounts & Security"

    if [ "$TEST_PRESET" -eq 1 ]; then
        USER_NAME="duckling"
        USER_REALNAME="Duckling User"
        USER_PASSWORD="devpassword123"
        ROOT_PASSWORD="devpassword123"
        ROOT_PASSWORD_SAME_AS_USER=1
        EXTRA_USERS=("guest:Guest User:no:guest123")
        ui_info "Preset configured: Primary user '$USER_NAME', Extra user 'guest'"
        return 0
    fi

    # Primary user account
    ui_header "Primary User Account" "Set up your main user account (granted sudo rights)"

    while true; do
        USER_NAME=$(ui_input "Username" "e.g. eymen, obsidian, duckling" "")
        if [[ "$USER_NAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            if [ "$USER_NAME" = "root" ]; then
                ui_error "Primary user cannot be 'root'."
            else
                break
            fi
        else
            ui_error "Invalid username. Must be lowercase alphanumeric."
        fi
    done

    USER_REALNAME=$(ui_input "Full Name / Display Name" "e.g. Obsidian Operator" "$USER_NAME")

    # Primary user password
    while true; do
        echo ""
        USER_PASSWORD=$(ui_password "Password for '$USER_NAME'" "Enter a strong password")
        if [ -z "$USER_PASSWORD" ]; then
            ui_error "Password cannot be empty."
            continue
        fi

        local pass_confirm
        pass_confirm=$(ui_password "Confirm Password" "Re-type password")

        if [ "$USER_PASSWORD" = "$pass_confirm" ]; then
            ui_success "Password confirmed for '$USER_NAME'."
            break
        else
            ui_error "Passwords do not match. Please try again."
        fi
    done

    # Root security
    ui_header "Root Security" "Superuser (root) account password configuration"
    if ui_confirm "Use the same password for 'root' (Superuser)?" "Yes"; then
        ROOT_PASSWORD_SAME_AS_USER=1
        ROOT_PASSWORD="$USER_PASSWORD"
        ui_success "Root will share password with '$USER_NAME'."
    else
        ROOT_PASSWORD_SAME_AS_USER=0
        while true; do
            ROOT_PASSWORD=$(ui_password "Root Password" "Enter separate root password")
            if [ -z "$ROOT_PASSWORD" ]; then
                ui_error "Root password cannot be empty."
                continue
            fi

            local root_confirm
            root_confirm=$(ui_password "Confirm Root Password" "Re-type root password")

            if [ "$ROOT_PASSWORD" = "$root_confirm" ]; then
                ui_success "Root password set successfully."
                break
            else
                ui_error "Passwords do not match. Please try again."
            fi
        done
    fi

    # Extra users loop
    ui_header "Additional Users" "Optionally configure extra local user accounts"
    EXTRA_USERS=()

    while true; do
        if ! ui_confirm "Would you like to add an extra user?" "No"; then
            break
        fi

        local ex_user=""
        local ex_fullname=""
        local ex_pass=""
        local ex_sudo="no"

        while true; do
            ex_user=$(ui_input "Extra Username" "e.g. guest, work" "")
            if [[ "$ex_user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                if [ "$ex_user" = "$USER_NAME" ] || [ "$ex_user" = "root" ]; then
                    ui_error "Username '$ex_user' already exists or is reserved."
                else
                    break
                fi
            else
                ui_error "Invalid username. Must be lowercase alphanumeric."
            fi
        done

        ex_fullname=$(ui_input "Full Name" "Display Name for $ex_user" "$ex_user")

        while true; do
            ex_pass=$(ui_password "Password for '$ex_user'" "Enter password")
            local ex_confirm
            ex_confirm=$(ui_password "Confirm Password" "Re-type password")
            if [ "$ex_pass" = "$ex_confirm" ] && [ -n "$ex_pass" ]; then
                break
            else
                ui_error "Passwords do not match or empty."
            fi
        done

        if ui_confirm "Grant administrator (sudo) privileges to '$ex_user'?" "No"; then
            ex_sudo="yes"
        else
            ex_sudo="no"
        fi

        EXTRA_USERS+=("${ex_user}:${ex_fullname}:${ex_sudo}:${ex_pass}")
        ui_success "Added extra user: $ex_user (Full name: $ex_fullname, Sudo: $ex_sudo)"
    done

    local count=${#EXTRA_USERS[@]}
    ui_info "Total extra users configured: $count"
}

# ------------------------------------------------------------------------------
# Step 5: Storage & Target Installation
# ------------------------------------------------------------------------------
step_storage() {
    ui_clear
    ui_banner
    ui_dev_warning
    ui_step 5 7 "Target Installation & Storage"

    ui_header "Target Disk Selection" "Select where ducklingOS 1 \"Obsidian\" will be installed"

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
            disk_list+=("/dev/nvme0n1 (512.0G - Obsidian Dev NVMe Drive)" "/dev/sda (1000.0G - Secondary Dev SSD)")
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
        ui_info "Preset storage: Target Disk=$TARGET_DISK, FS=btrfs, Swap=zram"
        return 0
    fi

    echo ""
    gum style --foreground "$COLOR_MUTED" "Available storage devices:"
    local selected_entry
    selected_entry=$(ui_choose "${disk_list[@]}" "Manual Target (Use already mounted /mnt)")

    if [[ "$selected_entry" == *"Manual Target"* ]]; then
        TARGET_PARTITION_MODE="manual"
        TARGET_DISK="manual"
        ui_info "Selected manual mount mode. Installer will install directly onto $MOUNT_POINT."
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
        ui_header "Filesystem Architecture" "Select your preferred root filesystem"
        local fs_choice
        fs_choice=$(ui_choose "btrfs (Recommended - Snapshots, Subvolumes, Compression)" \
                              "ext4 (Classic, Simple, Standard Linux Filesystem)")

        if [[ "$fs_choice" == *"btrfs"* ]]; then
            TARGET_FILESYSTEM="btrfs"
            BTRFS_SUBVOLUMES=1
            ui_success "Filesystem: BTRFS with subvolumes (@, @home, @snapshots, @var_log)"
        else
            TARGET_FILESYSTEM="ext4"
            BTRFS_SUBVOLUMES=0
            ui_success "Filesystem: EXT4"
        fi

        ui_header "Swap Configuration" "Select memory swapping strategy"
        local swap_choice
        swap_choice=$(ui_choose "zram (Recommended: compressed RAM, prolongs SSD lifespan)" \
                                "swapfile-4g (4 GB dedicated swap file)" \
                                "swapfile-8g (8 GB dedicated swap file)" \
                                "none (No swap)")

        case "$swap_choice" in
            "zram"*)        SWAP_TYPE="zram" ;;
            "swapfile-4g"*) SWAP_TYPE="swapfile"; SWAP_SIZE="4G" ;;
            "swapfile-8g"*) SWAP_TYPE="swapfile"; SWAP_SIZE="8G" ;;
            "none"*)        SWAP_TYPE="none" ;;
        esac
        ui_success "Swap strategy: $SWAP_TYPE"
    fi
}

# ------------------------------------------------------------------------------
# Step 6: Software, Kernel & KDE Plasma
# ------------------------------------------------------------------------------
step_software() {
    ui_clear
    ui_banner
    ui_dev_warning
    ui_step 6 7 "Software Packages & Kernel"

    if [ "$TEST_PRESET" -eq 1 ]; then
        SYSTEM_KERNEL="linux-zen"
        INSTALL_DEV_TOOLS=1
        INSTALL_BLUETOOTH=1
        ui_info "Preset software: Kernel=$SYSTEM_KERNEL, Desktop=KDE Plasma, Bootloader=Limine"
        return 0
    fi

    ui_header "Linux Kernel" "Select the kernel package for ducklingOS"
    local kernel_choice
    kernel_choice=$(ui_choose "linux-zen (Recommended - Low Latency & Desktop Optimized)" \
                              "linux (Standard Upstream Linux Kernel)" \
                              "linux-lts (Long Term Support - Maximum Stability)")

    case "$kernel_choice" in
        "linux-zen"*) SYSTEM_KERNEL="linux-zen" ;;
        "linux ("*)   SYSTEM_KERNEL="linux" ;;
        "linux-lts"*) SYSTEM_KERNEL="linux-lts" ;;
        *)            SYSTEM_KERNEL="linux-zen" ;;
    esac
    ui_success "Selected Kernel: $SYSTEM_KERNEL"

    ui_header "Desktop Environment & Bootloader" "Pre-configured for ducklingOS 1 Obsidian"
    ui_info "Desktop Environment: KDE Plasma 6 (Obsidian Theme & Wayland Session)"
    ui_info "Bootloader: Limine (Modern, ultra-fast, multi-protocol bootloader)"

    ui_header "Optional Software Components" "Select additional stacks"
    if ui_confirm "Install Developer Toolkit (Neovim, Zsh, Starship, Git, Tmux, Base-Devel)?" "Yes"; then
        INSTALL_DEV_TOOLS=1
    else
        INSTALL_DEV_TOOLS=0
    fi

    if ui_confirm "Enable Bluetooth Stack (bluez, bluedevil)?" "Yes"; then
        INSTALL_BLUETOOTH=1
    else
        INSTALL_BLUETOOTH=0
    fi
}

# ------------------------------------------------------------------------------
# Step 7: Review & Final Confirmation
# ------------------------------------------------------------------------------
step_review() {
    ui_clear
    ui_banner
    ui_dev_warning
    ui_step 7 7 "Review & Confirmation"

    ui_header "Installation Summary" "Please review your configuration before installation begins"

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

    local dev_status="LIVE EXECUTION (Real disk modifications)"
    if [ "$DEV_MODE" -eq 1 ]; then
        dev_status="⚡ SIMULATION / DRY-RUN (No disk changes) ⚡"
    fi

    gum style \
        --border rounded \
        --border-foreground "$COLOR_PRIMARY" \
        --padding "1 2" \
        --width 72 \
        -- \
        "Distribution:   ${DISTRO_FULL_NAME}" \
        "Install Mode:   ${dev_status}" \
        "──────────────────────────────────────────────────────────────────" \
        "Hostname:       ${SYSTEM_HOSTNAME}" \
        "Locale:         ${SYSTEM_LOCALE}" \
        "Keymap:         ${SYSTEM_KEYMAP}" \
        "Timezone:       ${SYSTEM_TIMEZONE}" \
        "──────────────────────────────────────────────────────────────────" \
        "Primary User:   ${USER_NAME} (${USER_REALNAME}) [sudo: YES]" \
        "Root Password:  $([ "$ROOT_PASSWORD_SAME_AS_USER" -eq 1 ] && echo "Same as primary user" || echo "Dedicated root password")" \
        "Extra Users:    ${extra_user_summary}" \
        "──────────────────────────────────────────────────────────────────" \
        "Target Disk:    ${TARGET_DISK} (${TARGET_PARTITION_MODE})" \
        "Filesystem:     ${TARGET_FILESYSTEM^^}" \
        "Swap Strategy:  ${SWAP_TYPE}" \
        "──────────────────────────────────────────────────────────────────" \
        "Kernel:         ${SYSTEM_KERNEL}" \
        "Desktop:        KDE Plasma (Wayland)" \
        "Bootloader:     Limine" \
        "Developer Tools: $([ "$INSTALL_DEV_TOOLS" -eq 1 ] && echo "Yes" || echo "No")" \
        "Bluetooth:      $([ "$INSTALL_BLUETOOTH" -eq 1 ] && echo "Yes" || echo "No")"

    echo ""
    if [ "$TEST_PRESET" -eq 1 ]; then
        ui_info "Preset auto-confirmation accepted."
        return 0
    fi

    if [ "$DEV_MODE" -eq 1 ]; then
        if ! ui_confirm "Proceed with the test / dry-run simulation?" "Yes"; then
            ui_warn "Dry run aborted by user."
            exit 0
        fi
    else
        gum style --foreground "$COLOR_DANGER" --bold \
            "⚠ WARNING: ALL EXISTING DATA ON ${TARGET_DISK} WILL BE COMPLETELY DESTROYED!"
        if ! ui_confirm "Are you ABSOLUTELY sure you want to write changes to disk and install?" "No"; then
            ui_warn "Installation cancelled. No changes were made."
            exit 0
        fi
    fi
}

# ------------------------------------------------------------------------------
# Step 8: Installation Engine (Partitioning, Pacstrap, KDE, Limine)
# ------------------------------------------------------------------------------
step_install() {
    ui_clear
    ui_banner
    ui_dev_warning

    ui_header "Installation in Progress" "ducklingOS 1 \"Obsidian\" (KDE Plasma & Limine) is building"

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

    # 1. Storage Partitioning & Formatting
    echo ""
    ui_step 1 6 "Partitioning & Formatting Storage"

    if [ "$TARGET_PARTITION_MODE" = "auto" ]; then
        ui_cmd "Wiping existing partition signatures on $TARGET_DISK" \
            wipefs -af "$TARGET_DISK"

        ui_cmd "Creating GPT partition table on $TARGET_DISK" \
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

            ui_cmd "Mounting root partition temporarily to create Btrfs subvolumes" \
                mount "$root_part" "$MOUNT_POINT"

            ui_cmd "Creating subvolume @" \
                btrfs subvolume create "${MOUNT_POINT}/@"

            ui_cmd "Creating subvolume @home" \
                btrfs subvolume create "${MOUNT_POINT}/@home"

            ui_cmd "Creating subvolume @snapshots" \
                btrfs subvolume create "${MOUNT_POINT}/@snapshots"

            ui_cmd "Creating subvolume @var_log" \
                btrfs subvolume create "${MOUNT_POINT}/@var_log"

            ui_cmd "Unmounting temporary root" \
                umount "$MOUNT_POINT"

            ui_cmd "Mounting subvolume @ to $MOUNT_POINT" \
                mount -o noatime,compress=zstd:1,subvol=@ "$root_part" "$MOUNT_POINT"

            ui_cmd "Creating mount directories under $MOUNT_POINT" \
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
    else
        ui_info "Using pre-mounted filesystem at $MOUNT_POINT"
    fi

    # 2. Base Packages + KDE Plasma + Limine (Pacstrap)
    echo ""
    ui_step 2 6 "Installing Base Packages, KDE Plasma & Limine"

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
        # Audio
        "pipewire"
        "wireplumber"
        "pipewire-audio"
        "pipewire-alsa"
        "pipewire-pulse"
        "pipewire-jack"
        # KDE Plasma Desktop Suite
        "plasma-meta"
        "plasma-wayland-session"
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
        base_pkgs+=(
            "git"
            "neovim"
            "zsh"
            "starship"
            "tmux"
            "ripgrep"
            "fd"
            "htop"
        )
    fi

    if [ "$INSTALL_BLUETOOTH" -eq 1 ]; then
        base_pkgs+=("bluez" "bluez-utils" "bluedevil")
    fi

    ui_cmd "Executing pacstrap on $MOUNT_POINT with ${#base_pkgs[@]} packages" \
        pacstrap -K "$MOUNT_POINT" "${base_pkgs[@]}"

    ui_cmd "Generating /etc/fstab using genfstab -U" \
        bash -c "genfstab -U '$MOUNT_POINT' >> '${MOUNT_POINT}/etc/fstab'"

    # 3. Localization & Hostname
    echo ""
    ui_step 3 6 "Configuring Localization, Timezone & Hostname"

    ui_cmd "Setting timezone to $SYSTEM_TIMEZONE" \
        arch-chroot "$MOUNT_POINT" ln -sf "/usr/share/zoneinfo/$SYSTEM_TIMEZONE" /etc/localtime

    ui_cmd "Syncing hardware clock" \
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

    # 4. User Accounts & Security
    echo ""
    ui_step 4 6 "Configuring Users & Sudo Permissions"

    local user_shell="/bin/bash"
    if [ "$INSTALL_DEV_TOOLS" -eq 1 ]; then
        user_shell="/bin/zsh"
    fi

    ui_cmd "Setting root password" \
        bash -c "echo 'root:${ROOT_PASSWORD}' | arch-chroot '$MOUNT_POINT' chpasswd"

    ui_cmd "Creating primary user account: $USER_NAME ($USER_REALNAME)" \
        arch-chroot "$MOUNT_POINT" useradd -m -g users -G wheel,storage,power,audio,video -s "$user_shell" -c "$USER_REALNAME" "$USER_NAME"

    ui_cmd "Setting password for $USER_NAME" \
        bash -c "echo '${USER_NAME}:${USER_PASSWORD}' | arch-chroot '$MOUNT_POINT' chpasswd"

    ui_cmd "Configuring wheel group sudo rights" \
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

            ui_cmd "Creating extra user '$e_user' (Sudo: $e_sudo)" \
                arch-chroot "$MOUNT_POINT" useradd -m -g users -G "$extra_groups" -s "$user_shell" -c "$e_fullname" "$e_user"

            ui_cmd "Setting password for extra user '$e_user'" \
                bash -c "echo '${e_user}:${e_pass}' | arch-chroot '$MOUNT_POINT' chpasswd"
        done
    fi

    # 5. ducklingOS 1 "Obsidian" Identity & Theming
    echo ""
    ui_step 5 6 "Applying ducklingOS 1 \"Obsidian\" Branding"

    ui_cmd "Writing /etc/os-release" \
        bash -c "cat <<EOF > '${MOUNT_POINT}/etc/os-release'
NAME=\"ducklingOS\"
PRETTY_NAME=\"ducklingOS 1 \\\"Obsidian\\\" (KDE Plasma Edition)\"
ID=ducklingos
ID_LIKE=arch
VERSION=\"1\"
VERSION_ID=\"1\"
VERSION_CODENAME=\"Obsidian\"
BUILD_ID=rolling
ANSI_COLOR=\"0;35\"
HOME_URL=\"https://ducklingos.org\"
DOCUMENTATION_URL=\"https://wiki.ducklingos.org\"
SUPPORT_URL=\"https://ducklingos.org/support\"
BUG_REPORT_URL=\"https://github.com/ducklingos/ducklingos/issues\"
LOGO=ducklingos
EOF"

    ui_cmd "Writing /etc/issue" \
        bash -c "cat <<EOF > '${MOUNT_POINT}/etc/issue'
   ____            _    _ _             ___  ____  
  / __ \__  _______| | _| (_)_ __   __ _/ _ \/ ___| 
 / / _\` | | | / __/ |/ / | | '_ \ / _\` | | | \___ \ 
| | (_| | |_| | (_|   <| | | | | | (_| | |_| |___) |
 \ \__,_|\__,_|\___\_|\_\_|_|_| |_|\__, |\___/|____/ 
  \____/                           |___/             
  ducklingOS 1 \"Obsidian\" (KDE Plasma) - \r (\l)
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
        ui_cmd "Securing swapfile permissions" \
            arch-chroot "$MOUNT_POINT" chmod 600 /swapfile
        ui_cmd "Formatting swapfile" \
            arch-chroot "$MOUNT_POINT" mkswap /swapfile
        ui_cmd "Adding swapfile to /etc/fstab" \
            bash -c "echo '/swapfile none swap defaults 0 0' >> '${MOUNT_POINT}/etc/fstab'"
    fi

    # 6. Limine Bootloader Installation & Services
    echo ""
    ui_step 6 6 "Installing Limine Bootloader & Enabling System Services"

    # Limine EFI installation
    ui_cmd "Creating EFI directory for Limine (/boot/EFI/BOOT)" \
        mkdir -p "${MOUNT_POINT}/boot/EFI/BOOT"

    ui_cmd "Deploying Limine EFI binary (BOOTX64.EFI)" \
        bash -c "cp '${MOUNT_POINT}/usr/share/limine/BOOTX64.EFI' '${MOUNT_POINT}/boot/EFI/BOOT/BOOTX64.EFI' || true"

    local root_kernel_cmd="root=${root_part} rw quiet"
    if [ "$TARGET_FILESYSTEM" = "btrfs" ]; then
        root_kernel_cmd="root=${root_part} rootflags=subvol=@ rw quiet"
    fi

    ui_cmd "Creating Limine configuration file (/boot/limine.conf)" \
        bash -c "cat <<EOF > '${MOUNT_POINT}/boot/limine.conf'
# Limine Configuration for ducklingOS 1 \"Obsidian\"
timeout: 3
interface_branding: ducklingOS 1 \"Obsidian\" (KDE Plasma)
interface_branding_color: 5
term_palette: 000000;aa0000;00aa00;aa5500;0000aa;aa00aa;00aaaa;aaaaaa;555555;ff5555;55ff55;ffff55;5555ff;ff55ff;55ffff;ffffff

/ducklingOS 1 \"Obsidian\" (KDE Plasma - ${SYSTEM_KERNEL})
    protocol: linux
    kernel_path: boot():/vmlinuz-${SYSTEM_KERNEL}
    module_path: boot():/initramfs-${SYSTEM_KERNEL}.img
    cmdline: ${root_kernel_cmd}

/ducklingOS 1 \"Obsidian\" (Fallback initramfs)
    protocol: linux
    kernel_path: boot():/vmlinuz-${SYSTEM_KERNEL}
    module_path: boot():/initramfs-${SYSTEM_KERNEL}-fallback.img
    cmdline: ${root_kernel_cmd}
EOF"

    ui_cmd "Registering Limine with UEFI boot manager via efibootmgr" \
        arch-chroot "$MOUNT_POINT" efibootmgr --create --disk "$TARGET_DISK" --part 1 --loader '/EFI/BOOT/BOOTX64.EFI' --label 'ducklingOS (Limine)' --unicode || true

    # Enable systemd services
    ui_cmd "Enabling NetworkManager" \
        arch-chroot "$MOUNT_POINT" systemctl enable NetworkManager.service

    ui_cmd "Enabling SDDM (KDE Display Manager)" \
        arch-chroot "$MOUNT_POINT" systemctl enable sddm.service

    if [ "$INSTALL_BLUETOOTH" -eq 1 ]; then
        ui_cmd "Enabling bluetooth service" \
            arch-chroot "$MOUNT_POINT" systemctl enable bluetooth.service
    fi

    # Dev preview manifest
    if [ "$DEV_MODE" -eq 1 ]; then
        mkdir -p "${PREVIEW_DIR}"
        cat <<EOF > "${PREVIEW_DIR}/simulation_manifest.txt"
ducklingOS 1 "Obsidian" - Dev Simulation Manifest
Generated At: $(date)
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
EOF
    fi

    # Finish Screen
    ui_clear
    ui_banner

    if [ "$DEV_MODE" -eq 1 ]; then
        gum style \
            --foreground "$COLOR_SUCCESS" \
            --border double \
            --border-foreground "$COLOR_SUCCESS" \
            --padding "1 2" \
            --margin "1 0" \
            " 🎉 DEV TEST RUN COMPLETED SUCCESSFULLY! " \
            "" \
            " ducklingOS 1 \"Obsidian\" (KDE Plasma & Limine) simulated successfully." \
            " Simulation manifest stored at: ${PREVIEW_DIR}/simulation_manifest.txt" \
            " No storage or system modifications were made."
    else
        gum style \
            --foreground "$COLOR_SUCCESS" \
            --border double \
            --border-foreground "$COLOR_SUCCESS" \
            --padding "1 2" \
            --margin "1 0" \
            " 🚀 ducklingOS 1 \"Obsidian\" INSTALLED SUCCESSFULLY! " \
            "" \
            " Desktop: KDE Plasma 6" \
            " Bootloader: Limine" \
            " You may now reboot into ducklingOS 1." \
            " Command to reboot: umount -R /mnt && reboot"
    fi
}

# ------------------------------------------------------------------------------
# Main Entry Point & CLI Parsing
# ------------------------------------------------------------------------------
print_usage() {
    cat <<EOF
ducklingOS 1 "Obsidian" - All-in-One Installer
(KDE Plasma Edition with Limine Bootloader)

Usage:
  sudo ./install.sh [options]

Options:
  --dev               Run in dry-run simulation mode (no system or disk modifications)
  --test-preset       Run with predefined automated choices (for CI / testing)
  -h, --help          Show this help message and exit
  -v, --version       Display installer version and information

Examples:
  ./install.sh --dev              # Interactive TUI in test mode (no root required)
  ./install.sh --dev --test-preset # Headless test run with dry-run output
  sudo ./install.sh               # Live installation onto hardware
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dev)
            export DEV_MODE=1
            shift
            ;;
        --test-preset)
            export TEST_PRESET=1
            shift
            ;;
        -v|--version)
            echo "${DISTRO_FULL_NAME} Installer (KDE Plasma + Limine)"
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

if [ "$DEV_MODE" -ne 1 ] && [ "$EUID" -ne 0 ]; then
    ui_error "The live installer must be run as root (or with sudo)."
    echo -e "Tip: You can test the installer without root using: \033[1;36m./install.sh --dev\033[0m"
    exit 1
fi

if [ ! -f /etc/arch-release ]; then
    if [ "$DEV_MODE" -eq 1 ]; then
        ui_warn "Non-Arch environment detected. Continuing because --dev mode is active."
    else
        ui_error "ducklingOS 1 must be installed from an Arch Linux live environment."
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
