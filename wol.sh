#!/bin/sh

# Get the list of connected devices from ARP table (IP and MAC)
DEVICES=$(ip neigh show | awk '/REACHABLE/ {print $1, $5}')

# Check if any device is detected in the network
if [ -z "$DEVICES" ]; then
    whiptail --msgbox "No connected devices found!" 10 40
    exit 1
fi

# Create a list of devices for the whiptail menu
MENU_ITEMS=""
while read -r IP MAC; do
    # Try to get the hostname from DHCP leases
    HOSTNAME=$(grep "$IP" /tmp/dhcp.leases | awk '{print $4}')
    
    # If hostname is empty, fallback to nslookup
    if [ -z "$HOSTNAME" ]; then
        HOSTNAME=$(nslookup "$IP" 2>/dev/null | awk -F' = ' '/name =/ {print $2}' | sed 's/\.$//')
    fi

    # If still empty, set to IP address
    [ -z "$HOSTNAME" ] && HOSTNAME="Unknown"

    # Add device to the menu with hostname only (no IP, no "Device" suffix)
    MENU_ITEMS="$MENU_ITEMS \"$HOSTNAME\" \"$HOSTNAME\""
done <<EOF
$DEVICES
EOF

# Show device selection menu for sending WOL command
CHOICE=$(whiptail --title "Select Device" --menu "Choose a device for Wake on LAN:" 20 60 10 $MENU_ITEMS 3>&1 1>&2 2>&3)

# Check if the user selected a device
if [ -z "$CHOICE" ]; then
    exit 1
fi

# Send Wake on LAN command to the selected device
etherwake -i br-lan "$CHOICE"

# Extract the selected device name for renaming the HTML file
DEVICE_NAME="$CHOICE"

# Remove invalid characters from the device name and make sure there are no quotes
DEVICE_NAME_CLEAN=$(echo "$DEVICE_NAME" | tr -d '()' | tr ' ' '_' | sed 's/"//g')

# Ensure the /www/wol directory exists
mkdir -p /www/wol

# Create a default index.html file if it doesn't exist
echo "<html><body><h1>WOL Triggered for $DEVICE_NAME_CLEAN</h1></body></html>" > "/www/wol/$DEVICE_NAME_CLEAN.html"

# Show success message to the user
whiptail --msgbox "WOL command sent!\nHTML file created: /www/wol/$DEVICE_NAME_CLEAN.html" 10 50

# Usage instruction
echo "To trigger WOL, open: http://<router-ip>/wol/$DEVICE_NAME_CLEAN.html"
