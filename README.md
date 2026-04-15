# Fast Notification Service

A lightweight desktop notification service for Linux that listens on a TCP port and displays notifications based on configuration files. Designed for easy integration into other applications.

## Features

- Make sending custom notifications very easy
- TCP-based notification triggering
- Configurable notification templates
- Optional sound playback with repeat support
- Systemd user service integration
- CLI tool for service management
- Single command installation for applications

---

## For Application Developers

### Quick Install (One Command)

```bash
curl -sSL https://raw.githubusercontent.com/amooebrahim/fast-notification/main/install.sh | sudo bash
```

### Check if Installed (in your app code)

```bash
# Check if service is installed
curl -sSL https://raw.githubusercontent.com/amooebrahim/fast-notification/main/install.sh | bash -s -- --check
```

### Install as Dependency

Add to your application's setup/install script:

```bash
# Check if already installed
if ! curl -sSL <installer-url> | bash -s -- --check 2>/dev/null; then
    echo "Installing Fast Notification Service..."
    curl -sSL <installer-url> | sudo bash
fi

# Start the service
systemctl --user start fast-notification
```

---

## Send Notifications from Code

### Bash

```bash
# Send by template name (from templates directory)
echo "my-alert.conf" | nc localhost 52345

# Send by full path
echo "/etc/fast-notification/templates/my-alert.conf" | nc localhost 52345
```

### Python

```python
import socket

def send_notification(template_name, host='localhost', port=52345):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((host, port))
    sock.sendall(template_name.encode())
    sock.close()
```

### Any Language

Simply open a TCP connection to `localhost:52345` and send the template filename or full path.

---

## CLI Commands

```bash
fast-notification status    # Show service status and info
fast-notification start     # Start the systemd service
fast-notification stop      # Stop the systemd service
fast-notification restart   # Restart the systemd service
fast-notification test      # Send a test notification
fast-notification create    # Create a new notification config
fast-notification log       # View recent logs
fast-notification -h        # Show help
fast-notification -v        # Show version
```

---

## Configuration

### Service Settings

Edit `/etc/fast-notification/service.conf`:

```ini
NOTIFICATION_PORT=52345
NOTIFICATION_LOG_FILE=/var/log/fast-notification/listener.log
NOTIFICATION_CONFIG_DIR=/etc/fast-notification
NOTIFICATION_TEMPLATE_DIR=/etc/fast-notification/templates
```

### Notification Templates

Create `.conf` files in `/etc/fast-notification/templates/`:

```ini
[notification]
notification_enabled=true
title=Alert Title
body=Notification message
icon=dialog-warning
urgency=critical
timeout=5000
transient=true

[sound]
sound_enabled=true
file=/usr/share/sounds/freedesktop/stereo/service-logout.oga
repeat=3
sleep=1
```

Or use the interactive creator:

```bash
fast-notification create
```

---

## Installer Options

```bash
# Install (default)
curl -sSL <url> | sudo bash

# Check status
curl -sSL <url> | bash -s -- --check

# Update
curl -sSL <url> | sudo bash -s -- --update

# Uninstall
curl -sSL <url> | sudo bash -s -- --uninstall
```

---

## Troubleshooting

### Check Service Status

```bash
fast-notification status
```

### View Logs

```bash
tail -f /var/log/fast-notification/listener.log
```

### Common Issues

- **Service won't start**: Ensure you have a desktop environment running
- **Notifications not showing**: Check DISPLAY and XAUTHORITY environment variables
- **Sound not playing**: Verify `paplay` is installed

---

## File Structure

```
/usr/local/bin/fast-notification/
├── fast-notification          # CLI tool
├── notification-create       # Config creator
└── notification-listener    # Service daemon

/etc/fast-notification/
├── service.conf             # Service config
└── templates/               # Notification templates
    └── example.conf

/var/log/fast-notification/
└── listener.log

/etc/systemd/user/
└── fast-notification.service
```

## Dependencies

- libnotify-bin (notify-send)
- pulseaudio-utils (paplay)
- netcat-openbsd (nc)
- bc

## License
MIT