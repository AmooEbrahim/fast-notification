#!/bin/bash
set -e

# Fast Notification Service - Local Installer
# Usage: sudo ./local-install.sh

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    echo "Usage: sudo ./local-install.sh"
    exit 1
fi

readonly INSTALL_DIR='/usr/local/bin/fast-notification'
readonly CLI_BIN='/usr/local/bin/fast-notification'
readonly CONFIG_DIR='/etc/fast-notification'
readonly TEMPLATE_DIR='/etc/fast-notification/templates'
readonly LOG_DIR='/var/log/fast-notification'

echo "Installing Fast Notification Service from local files..."

echo "Installing dependencies..."
apt-get install -y libnotify-bin pulseaudio-utils netcat-openbsd bc

echo "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$TEMPLATE_DIR"
mkdir -p "$LOG_DIR"

echo "Copying files..."
cp fast-notification "$CLI_BIN"
cp create.sh "$INSTALL_DIR/notification-create"
cp service-listener.sh "$INSTALL_DIR/notification-listener"
cp example-notification.conf "$TEMPLATE_DIR/example.conf"

if [[ ! -f "$CONFIG_DIR/service.conf" ]]; then
    cp service.conf "$CONFIG_DIR/service.conf"
fi

echo "Setting permissions..."
chmod +x "$CLI_BIN"
chmod +x "$INSTALL_DIR/notification-create"
chmod +x "$INSTALL_DIR/notification-listener"
chmod 755 "$INSTALL_DIR"
chmod 755 "$CONFIG_DIR"
chmod 755 "$TEMPLATE_DIR"
chmod 755 "$LOG_DIR"

echo "Installing systemd service..."
cp fast-notification.service /etc/systemd/user/

if command -v systemctl &>/dev/null; then
    systemctl --user daemon-reload 2>/dev/null || true
fi

echo ""
echo "Installation complete!"
echo ""
echo "Usage:"
echo "  fast-notification status    - Check service status"
echo "  fast-notification start     - Start the service"
echo "  fast-notification stop      - Stop the service"
echo "  fast-notification restart   - Restart the service"
echo "  fast-notification test      - Send test notification"
echo "  fast-notification create    - Create new notification"
echo "  fast-notification log       - View logs"
echo "  fast-notification -h        - Show help"
echo ""
echo "Config: $CONFIG_DIR/service.conf"
echo "Templates: $TEMPLATE_DIR/"