# ducklingOS 1 "Obsidian"

Standalone TUI Installer and Dynamic System Updater for **ducklingOS**, inspired by Omarchy's minimalist aesthetic.

## Features
- **Standalone Single-File Installer**: `install.sh`
- **Dynamic System & App Updater**: `update.sh` (called via `ducklingos update` on the installed system)
- **GitHub Release Integration**: Both installer and updater dynamically query the latest GitHub release JSON (`system-update.json`).
- **Signature Styling**: Dark Violet (`#160b24`) background with vibrant Yellow (`#f5e042`) wordmark and Omarchy-style centered menus.
- **Fixed System Stack**: Arch Linux base + KDE Plasma 6 (Wayland) + Limine bootloader.
- **Update Safety**: `pacman -Syu` interceptor wrapper redirects users to `ducklingos update` to ensure system and app consistency.

---

## 1. Release Manifest Schema (`system-update.json`)
Host this file in your GitHub Release (e.g., `the-duckling-group/ducklingOS`) as a release asset named `system-update.json` or in the `main` branch:

```json
{
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
}
```

---

## 2. Running the Installer (`install.sh`)

### Live Installation
To run a live installation on an Arch Linux ISO:
```bash
sudo ./install.sh --installation
```
*(The `--installation` flag triggers the full disk setup, base system installation, and invokes `update.sh --install` for initial app rollout)*

### Dry-Run Simulation Mode (`--dev`)
To test the full TUI without root privileges and without modifying storage disks:
```bash
./install.sh --dev
```

### Automated CI / Preset Testing
```bash
./install.sh --dev --test-preset
```

---

## 3. System Updating (`ducklingos update`)

Once ducklingOS is installed, users update the base OS and apps through:
```bash
ducklingos update
```

### Updater Flags:
- `--install`: Used internally by `install.sh` during setup to deploy initial apps to the target root filesystem.
- `--force`, `-f`: Reinstalls or re-runs updates even if the local version matches the release version.
- `--dev`: Dry-run mode for testing updater logic.
- `--repo=USER/REPO`: Points to an alternative GitHub repository.
