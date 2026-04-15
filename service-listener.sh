#!/bin/bash
# -----------------------------
# Notification Listener Service
# -----------------------------
# Listens on a configurable TCP port for config file paths
# Reads notification config and triggers desktop notification + optional sound
#
# Usage: echo '/path/to/config.conf' | nc localhost <port>
# -----------------------------

set -euo pipefail

readonly VERSION='1.0.0'
readonly DEFAULT_PORTS=(52345 52346 52347 52348 52349)
readonly LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fast-notification/logs"
readonly LOG_FILE="$LOG_DIR/listener.log"
readonly CONFIG_DIR=/etc/fast-notification
readonly CONFIG_FILE=/etc/fast-notification/service.conf
readonly TEMPLATE_DIR=/etc/fast-notification/templates

SERVICE_PORT=

mkdir -p $(dirname $LOG_FILE) 2>/dev/null || {
    echo 'ERROR: Cannot create log directory: '$(dirname $LOG_FILE) >&2
    exit 1
}

log() {
    echo $(date '+%F %T') - $* >> $LOG_FILE
}

log_error() {
    echo $(date '+%F %T') - ERROR: $* >> $LOG_FILE
}

read_config() {
    local file="$1"
    local key="$2"
    local default="${3:-}"
    
    local value=$(grep "^${key}=" "$file" 2>/dev/null | head -n1 | cut -d'=' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']$//')
    
    echo "${value:-$default}"
}

is_port_available() {
    local port="$1"
    if nc -z localhost "$port" 2>/dev/null; then
        return 1
    else
        return 0
    fi
}

find_first_available_port() {
    for port in ${DEFAULT_PORTS[@]}; do
        if is_port_available "$port"; then
            echo "$port"
            return 0
        fi
    done
    return 1
}

is_true() {
    [[ "${1,,}" == "true" ]]
}

validate_float() {
    [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]
}

process_notification() {
    local config_path="$1"
    
    local resolved_path="$config_path"
    
    if [[ ! "$config_path" =~ ^/ ]]; then
        resolved_path="$TEMPLATE_DIR/$config_path"
        if [[ ! -f "$resolved_path" ]]; then
            resolved_path="$CONFIG_DIR/$config_path"
        fi
    fi
    
    if [[ ! -f "$resolved_path" ]]; then
        log_error "Config file not found: $resolved_path (original: $config_path)"
        return 1
    fi
    
    if [[ ! -r "$resolved_path" ]]; then
        log_error "Config file not readable: $resolved_path"
        return 1
    fi
    
    config_path="$resolved_path"
    
    local notification_enabled=$(read_config "$config_path" "notification_enabled" "true")
    
    if is_true "$notification_enabled"; then
        local title=$(read_config "$config_path" "title" "Notification")
        local body=$(read_config "$config_path" "body" "")
        local icon=$(read_config "$config_path" "icon" "dialog-information")
        local urgency=$(read_config "$config_path" "urgency" "normal")
        local timeout=$(read_config "$config_path" "timeout" "5000")
        local transient=$(read_config "$config_path" "transient" "true")
        
        if [[ ! "$urgency" =~ ^(low|normal|critical)$ ]]; then
            log_error "Invalid urgency level: $urgency. Using 'normal'"
            urgency="normal"
        fi
        
        if notify-send -u "$urgency" -t "$timeout" -i "$icon" -h "string:transient:$transient" "$title" "$body"; then
            log "Notification sent: '$title' from $config_path"
        else
            log_error "Failed to send notification from $config_path"
            return 1
        fi
    else
        log "Notification disabled in config: $config_path"
    fi
    
    local sound_enabled=$(read_config "$config_path" "sound_enabled" "false")
    
    if is_true "$sound_enabled"; then
        local sound_file=$(read_config "$config_path" "file" "")
        local repeat=$(read_config "$config_path" "repeat" "1")
        local sleep_duration=$(read_config "$config_path" "sleep" "0")
        
        if [[ -z "$sound_file" ]]; then
            log_error "Sound enabled but no file specified in $config_path"
        elif [[ ! -f "$sound_file" ]]; then
            log_error "Sound file not found: $sound_file"
        else
            (
                for ((i=1; i<=repeat; i++)); do
                    if paplay "$sound_file" 2>/dev/null; then
                        log "Played sound ($i/$repeat): $sound_file"
                    else
                        log_error "Failed to play sound: $sound_file"
                        break
                    fi
                    
                    if [[ $i -lt $repeat ]] && validate_float "$sleep_duration"; then
                        local sleep_sec=$(echo "$sleep_duration" | cut -d. -f1)
                        local sleep_ms=$(echo "$sleep_duration" | cut -d. -f2 2>/dev/null || echo "0")
                        if [[ $(echo "$sleep_duration > 0" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
                            sleep "${sleep_sec}.${sleep_ms}0"
                        fi
                    fi
                done
            ) &
        fi
    fi
    
    return 0
}

main() {
    local configured_port=""
    
    if [[ -n "${NOTIFICATION_PORT:-}" ]]; then
        configured_port="$NOTIFICATION_PORT"
    elif [[ -f "$CONFIG_FILE" ]]; then
        configured_port=$(read_config "$CONFIG_FILE" "NOTIFICATION_PORT" "")
    fi
    
    if [[ -n "$configured_port" ]]; then
        if is_port_available "$configured_port"; then
            SERVICE_PORT="$configured_port"
            log "Using configured port: $SERVICE_PORT"
        else
            log_error "Configured port $configured_port is not available. Please choose a different port."
            echo "ERROR: Port $configured_port is already in use." >&2
            echo "Please set a different port in /etc/fast-notification/service.conf" >&2
            exit 1
        fi
    else
        SERVICE_PORT=$(find_first_available_port)
        if [[ -z "$SERVICE_PORT" ]]; then
            log_error "No available port found in range 52345-52349. Please set NOTIFICATION_PORT manually."
            echo "ERROR: No available port found in range 52345-52349." >&2
            echo "Please set a different port in /etc/fast-notification/service.conf" >&2
            exit 1
        fi
        log "No port configured, using first available: $SERVICE_PORT"
    fi
    
    log "Notification listener started on port $SERVICE_PORT"
    
    while true; do
        if command -v nc &>/dev/null; then
            config_path=$(nc -l $SERVICE_PORT 2>/dev/null || nc -l -p $SERVICE_PORT 2>/dev/null) || true
        else
            log_error "netcat (nc) not found. Please install netcat-openbsd or nmap-ncat"
            sleep 5
            continue
        fi
        
        config_path=$(echo "$config_path" | tr -d '\r\n' | xargs)
        
        if [[ -z "$config_path" ]]; then
            log_error "Received empty config path"
            continue
        fi
        
        if ! process_notification "$config_path"; then
            log_error "Failed to process notification: $config_path"
        fi
    done
}

trap 'log "Notification listener stopped"; exit 0' SIGTERM SIGINT

main