#!/bin/bash
# -----------------------------
# Fast Notification Service - Standalone Installer
# -----------------------------
# Can be downloaded and run independently:
#   curl -sSL https://raw.githubusercontent.com/amooebrahim/fast-notification/main/install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/amooebrahim/fast-notification/main/install.sh | bash -s -- --check
#   curl -sSL https://raw.githubusercontent.com/amooebrahim/fast-notification/main/install.sh | bash -s -- --uninstall
#
# For developers: check if installed in your app:
#   if curl -sSL <installer-url> | bash -s -- --check; then
#       echo "Service is installed"
#   fi
# -----------------------------

set -euo pipefail

readonly VERSION='1.0.0'
readonly SERVICE_NAME='fast-notification'
readonly INSTALL_DIR='/usr/local/bin/fast-notification'
readonly CLI_BIN='/usr/local/bin/fast-notification/fast-notification'
readonly CONFIG_DIR='/etc/fast-notification'
readonly TEMPLATE_DIR='/etc/fast-notification/templates'
readonly LOG_DIR='/var/log/fast-notification'
readonly PROFILE_SCRIPT='/etc/profile.d/fast-notification.sh'
readonly RAW_BASE='https://raw.githubusercontent.com/amooebrahim/fast-notification/main'

show_help() {
    cat <<EOF
Fast Notification Service Installer

Usage:
    curl -sSL <url> | bash [options]

Options:
    --check       Check if service is installed and running
    --uninstall   Remove the service and all files
    --update      Update to latest version
    --help        Show this help
    --version     Show version

Without options, installs the service.

Examples:
    # Install
    curl -sSL https://raw.githubusercontent.com/amooebrahim/fast-notification/main/install.sh | bash

    # Check if installed
    curl -sSL https://raw.githubusercontent.com/amooebrahim/fast-notification/main/install.sh | bash -s -- --check

    # Check in your code
    if curl -sSL <url> | bash -s -- --check; then
        # service is installed
    fi

    # Uninstall
    curl -sSL https://raw.githubusercontent.com/amooebrahim/fast-notification/main/install.sh | bash -s -- --uninstall
EOF
}

is_installed() {
    if [[ -f "$CLI_BIN" ]] && [[ -f "$INSTALL_DIR/notification-listener" ]]; then
        return 0
    else
        return 1
    fi
}

is_running() {
    systemctl --user is-active "$SERVICE_NAME" &>/dev/null
}

check_service() {
    echo "=== Fast Notification Service Check ==="
    echo ""

    if is_installed; then
        echo "Status: INSTALLED"
    else
        echo "Status: NOT INSTALLED"
        return 1
    fi

    if is_running; then
        echo "Service: RUNNING"
    else
        echo "Service: STOPPED"
    fi

    if [[ -f "$CONFIG_DIR/service.conf" ]]; then
        local port
        port=$(grep '^NOTIFICATION_PORT=' "$CONFIG_DIR/service.conf" 2>/dev/null | cut -d'=' -f2)
        echo "Port: ${port:-not set}"
    fi

    return 0
}

download_file() {
    local url="$1"
    local dest="$2"

    if command -v curl &>/dev/null; then
        curl -sSL "$url" -o "$dest"
    elif command -v wget &>/dev/null; then
        wget -q "$url" -O "$dest"
    else
        echo "Error: Neither curl nor wget found" >&2
        return 1
    fi
}

do_install() {
    echo "Installing Fast Notification Service..."

    if is_installed; then
        echo "Already installed. Use --update to reinstall."
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root"
        echo "Usage: sudo curl ... | bash"
        return 1
    fi

    echo "Installing dependencies..."
    apt-get update -qq && apt-get install -y libnotify-bin pulseaudio-utils netcat-openbsd bc >/dev/null 2>&1 || true

    echo "Creating directories..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$TEMPLATE_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p /etc/systemd/user

    echo "Downloading files..."

    echo "  Downloading fast-notification (CLI)..."
    download_file "$RAW_BASE/fast-notification" "$CLI_BIN" || {
        echo "Error: Failed to download main CLI" >&2
        return 1
    }

    echo "  Downloading notification-create..."
    download_file "$RAW_BASE/create.sh" "$INSTALL_DIR/notification-create" || true

    echo "  Downloading notification-listener..."
    download_file "$RAW_BASE/service-listener.sh" "$INSTALL_DIR/notification-listener" || true

    echo "  Downloading service files..."
    download_file "$RAW_BASE/fast-notification.service" "/etc/systemd/user/fast-notification.service" || true
    download_file "$RAW_BASE/service.conf" "$CONFIG_DIR/service.conf" || true
    download_file "$RAW_BASE/example-notification.conf" "$TEMPLATE_DIR/example.conf" || true

    echo "Setting permissions..."
    chmod +x "$CLI_BIN"
    chmod +x "$INSTALL_DIR/notification-create"
    chmod +x "$INSTALL_DIR/notification-listener"
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$TEMPLATE_DIR"
    chmod 755 "$LOG_DIR"

    echo "Adding to PATH..."
    echo 'export PATH="/usr/local/bin/fast-notification:$PATH"' > "$PROFILE_SCRIPT"

    systemctl --user daemon-reload 2>/dev/null || true

    echo ""
    echo "Installation complete!"
    echo ""
    echo "Usage:"
    echo "  fast-notification status"
    echo "  fast-notification start"
    echo "  fast-notification test"
    echo ""
    echo "Config: $CONFIG_DIR/service.conf"
    echo "Templates: $TEMPLATE_DIR/"
}

do_uninstall() {
    echo "Uninstalling Fast Notification Service..."

    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root"
        return 1
    fi

    systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true

    rm -f "$CLI_BIN"
    rm -rf "$INSTALL_DIR"
    rm -rf "$CONFIG_DIR"
    rm -rf "$LOG_DIR"
    rm -f /etc/systemd/user/fast-notification.service
    rm -f "$PROFILE_SCRIPT"

    systemctl --user daemon-reload 2>/dev/null || true

    echo "Uninstallation complete."
}

do_update() {
    echo "Updating Fast Notification Service..."
    do_uninstall
    do_install
}

main() {
    case "${1:-}" in
        --check)
            check_service
            ;;
        --uninstall)
            do_uninstall
            ;;
        --update)
            do_update
            ;;
        --help|-h)
            show_help
            ;;
        --version|-v)
            echo "fast-notification installer version $VERSION"
            ;;
        "")
            do_install
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            return 1
            ;;
    esac
}

main "$@"