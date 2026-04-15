#!/bin/bash
set -e

PACKAGE_NAME="fast-notification"
VERSION="1.0.0"
MAINTAINER="Amoo Ebrahim github.com/amooebrahim"
DESCRIPTION="Helper desktop notification service for Linux systems for use inside other apps"
DEPENDENCIES="libnotify-bin, pulseaudio-utils, netcat-openbsd, bc"

if ! command -v fpm &>/dev/null; then
    echo "Error: fpm (Effing Package Manager) is not installed."
    echo "Install with: gem install fpm"
    exit 1
fi

BUILD_DIR=$(mktemp -d)
echo "Building package in: $BUILD_DIR"

mkdir -p "$BUILD_DIR/usr/local/bin/fast-notification"
mkdir -p "$BUILD_DIR/etc/fast-notification"
mkdir -p "$BUILD_DIR/etc/fast-notification/templates"
mkdir -p "$BUILD_DIR/var/log/fast-notification"
mkdir -p "$BUILD_DIR/usr/share/doc/fast-notification"
mkdir -p "$BUILD_DIR/etc/systemd/user"

cp fast-notification "$BUILD_DIR/usr/local/bin/fast-notification"
cp create.sh "$BUILD_DIR/usr/local/bin/fast-notification/notification-create"
cp service-listener.sh "$BUILD_DIR/usr/local/bin/fast-notification/notification-listener"
cp example-notification.conf "$BUILD_DIR/etc/fast-notification/templates/example.conf"
cp service.conf "$BUILD_DIR/etc/fast-notification/service.conf"
cp fast-notification.service "$BUILD_DIR/etc/systemd/user/"

cat > "$BUILD_DIR/usr/share/doc/fast-notification/README.md" <<'EOF'
# Fast Notification Service

A simple desktop notification service that listens on a TCP port for notification requests.

## Usage

1. Start the service:
   ```bash
   fast-notification start
   ```

2. Create a notification configuration:
   ```bash
   fast-notification create
   ```

3. Send a notification:
   ```bash
   echo "example.conf" | nc localhost 52345
   ```

## Commands

- `fast-notification status` - Check service status
- `fast-notification start` - Start the service
- `fast-notification stop` - Stop the service
- `fast-notification restart` - Restart the service
- `fast-notification test` - Send test notification
- `fast-notification create` - Create new notification
- `fast-notification log` - View logs
- `fast-notification -h` - Show help

## Configuration

- Service config: /etc/fast-notification/service.conf
- Templates: /etc/fast-notification/templates/
- Logs: /var/log/fast-notification/listener.log
- Port: 52345 (fixed after install)
EOF

chmod +x "$BUILD_DIR/usr/local/bin/fast-notification"
chmod +x "$BUILD_DIR/usr/local/bin/fast-notification/notification-create"
chmod +x "$BUILD_DIR/usr/local/bin/fast-notification/notification-listener"
chmod 755 "$BUILD_DIR/usr/local/bin/fast-notification"
chmod 755 "$BUILD_DIR/etc/fast-notification"
chmod 755 "$BUILD_DIR/etc/fast-notification/templates"
chmod 755 "$BUILD_DIR/var/log/fast-notification"

echo "Building .deb package..."
fpm -s dir -t deb \
    -n "$PACKAGE_NAME" \
    -v "$VERSION" \
    --description "$DESCRIPTION" \
    --maintainer "$MAINTAINER" \
    --url "https://github.com/amooebrahim/fast-notification" \
    --category "utils" \
    --depends "$DEPENDENCIES" \
    --deb-no-default-config-files \
    --after-install <(cat <<'EOFSCRIPT'
#!/bin/bash
echo "Fast Notification Service installed successfully!"
echo ""
echo "Usage:"
echo "  fast-notification status  - Check service status"
echo "  fast-notification start    - Start the service"
echo "  fast-notification create   - Create new notification"
echo ""
echo "Config: /etc/fast-notification/service.conf"
echo "Templates: /etc/fast-notification/templates/"
EOFSCRIPT
) \
    --before-remove <(cat <<'EOFSCRIPT'
#!/bin/bash
systemctl --user stop fast-notification 2>/dev/null || true
systemctl --user disable fast-notification 2>/dev/null || true
EOFSCRIPT
) \
    -C "$BUILD_DIR" \
    .

rm -rf "$BUILD_DIR"

echo ""
echo "Package built successfully: $(ls -1 fast-notification_*.deb)"
echo ""
echo "To install: sudo dpkg -i fast-notification_*.deb"
echo "To fix missing dependencies: sudo apt-get install -f"