#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root. Use sudo."
  exit 1
fi

XSETUP_FILE="/usr/share/sddm/scripts/Xsetup"
SDDM_CONF="/etc/sddm.conf.d/sddm.conf"
TEMP_FILE="/tmp/xrandr_output.txt"

DISPLAY_SERVER="unknown"
if [ -f "$SDDM_CONF" ]; then
  if grep -q "DisplayServer=wayland" "$SDDM_CONF"; then
    DISPLAY_SERVER="wayland"
  elif grep -q "DisplayServer=x11" "$SDDM_CONF"; then
    DISPLAY_SERVER="x11"
  fi
fi

xrandr > "$TEMP_FILE" 2>/dev/null || {
  echo "xrandr failed. Likely running in native Wayland without XWayland."
}

mapfile -t MONITORS < <(grep " connected" "$TEMP_FILE" | awk '{print $1}')

MONITOR_COUNT=${#MONITORS[@]}
if [ "$MONITOR_COUNT" -lt 2 ] || [ "$MONITOR_COUNT" -gt 3 ]; then
  echo "Error: Script supports 2 or 3 monitors, found $MONITOR_COUNT."
  rm -f "$TEMP_FILE"
  exit 1
fi

if [ "$DISPLAY_SERVER" = "x11" ] || [ "$DISPLAY_SERVER" = "unknown" ]; then
  echo "Configuring for X11 (xrandr)..."
  XRANDR_CMD="xrandr"
  for MONITOR in "${MONITORS[@]}"; do
    XRANDR_CMD="$XRANDR_CMD --output $MONITOR --auto"
  done

  cat > "$XSETUP_FILE" << EOF
#!/bin/sh
# Xsetup - run as root before the login dialog appears
$XRANDR_CMD
EOF

  chmod +x "$XSETUP_FILE"

  mkdir -p /etc/sddm.conf.d
  cat > "$SDDM_CONF" << EOF
[General]
DisplayServer=x11
EOF

  echo "Updated $XSETUP_FILE with $MONITOR_COUNT monitors: ${MONITORS[*]}"
  cat "$XSETUP_FILE"
fi

if [ "$DISPLAY_SERVER" = "wayland" ]; then
  echo "SDDM is using Wayland. xrandr is not applicable."
  echo "Attempting to configure SDDM Wayland session..."

  WAYLAND_SCRIPT="/usr/local/bin/sddm-wayland-monitor.sh"
  cat > "$WAYLAND_SCRIPT" << EOF
#!/bin/sh
# Experimental: Attempt to configure monitors in SDDM Wayland greeter
# Note: wlr-randr may not be available
if command -v wlr-randr >/dev/null; then
  wlr-randr --output HDMI-A-1 --on --output DP-1 --on --output HDMI-A-2 --on
else
  echo "wlr-randr not available in SDDM greeter" > /tmp/sddm-wayland-error.log
fi
EOF
  chmod +x "$WAYLAND_SCRIPT"

  mkdir -p /etc/sddm.conf.d
  cat > "$SDDM_CONF" << EOF
[Wayland]
EnableHiDPI=true
SessionCommand=$WAYLAND_SCRIPT
EOF

  echo "Configured Wayland session script at $WAYLAND_SCRIPT"
  echo "Note: Wayland monitor configuration may require switching to X11 or a different display manager (e.g., GDM)."
fi

rm -f "$TEMP_FILE"

echo "Configuration complete. Restart SDDM or reboot to apply changes:"
echo "sudo systemctl restart sddm"
