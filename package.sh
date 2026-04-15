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
BUILD_OUTPUT_DIR="$(dirname "$0")/build"
echo "Building package in: $BUILD_DIR"

mkdir -p "$BUILD_DIR/usr/local/bin/fast-notification"
mkdir -p "$BUILD_DIR/etc/fast-notification"
mkdir -p "$BUILD_DIR/etc/fast-notification/templates"
mkdir -p "$BUILD_DIR/var/log/fast-notification"
mkdir -p "$BUILD_DIR/usr/share/doc/fast-notification"
mkdir -p "$BUILD_DIR/etc/systemd/user"

mkdir -p "$BUILD_OUTPUT_DIR"

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

AFTER_INSTALL_SCRIPT="$BUILD_DIR/after-install.sh"
cat > "$AFTER_INSTALL_SCRIPT" <<'EOF'
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
EOF

BEFORE_REMOVE_SCRIPT="$BUILD_DIR/before-remove.sh"
cat > "$BEFORE_REMOVE_SCRIPT" <<'EOF'
#!/bin/bash
systemctl --user stop fast-notification 2>/dev/null || true
systemctl --user disable fast-notification 2>/dev/null || true
EOF

build_package() {
    local type="$1"
    local deb_flags=""
    if [ "$type" = "deb" ]; then
        deb_flags="--deb-no-default-config-files"
    fi
    echo ""
    echo "Building .$type package..."
    fpm -s dir -t "$type" \
        -n "$PACKAGE_NAME" \
        -v "$VERSION" \
        --description "$DESCRIPTION" \
        --maintainer "$MAINTAINER" \
        --url "https://github.com/amooebrahim/fast-notification" \
        --category "utils" \
        --depends "$DEPENDENCIES" \
        $deb_flags \
        --after-install "$AFTER_INSTALL_SCRIPT" \
        --before-remove "$BEFORE_REMOVE_SCRIPT" \
        -C "$BUILD_DIR" \
        -p "$BUILD_OUTPUT_DIR/${PACKAGE_NAME}_${VERSION}.${type}"
}

build_package deb
build_package rpm

rm -rf "$BUILD_DIR"

echo ""
echo "Packages built in: $BUILD_OUTPUT_DIR/"
ls -1 "$BUILD_OUTPUT_DIR/"