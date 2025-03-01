#!/bin/sh

# Get the list of connected devices from ARP table
DEVICES=$(ip neigh show | awk '/REACHABLE/ {print $1, $5}')
if [ -z "$DEVICES" ]; then
    DEVICES=$(arp -a | awk '{print $2, $4}' | sed 's/[()]//g')
fi

# Check if any device is detected
if [ -z "$DEVICES" ]; then
    echo "No devices found on the network!"
    exit 1
fi

# Create a mapping of Hostname -> IP -> MAC
MENU_ITEMS=""
DEVICE_MAP=""
while read -r IP MAC; do
    HOSTNAME=$(grep -w "$IP" /tmp/dhcp.leases | awk '{print $4}')
    if [ -z "$HOSTNAME" ]; then
        HOSTNAME=$(nslookup "$IP" 2>/dev/null | awk -F' = ' '/name =/ {print $2}' | sed 's/\.$//')
    fi
    [ -z "$HOSTNAME" ] && HOSTNAME="$IP"

    MENU_ITEMS="$MENU_ITEMS \"$HOSTNAME\" \"$HOSTNAME\""
    DEVICE_MAP="$DEVICE_MAP\n$HOSTNAME $IP $MAC"
done <<EOF
$DEVICES
EOF

# Show device selection menu
CHOICE=$(whiptail --title "Select Device" --menu "Choose a device for Wake on LAN:" 20 60 10 $MENU_ITEMS 3>&1 1>&2 2>&3)

# Clean up CHOICE (remove extra quotes)
CHOICE=$(echo "$CHOICE" | sed 's/^"//' | sed 's/"$//')

# Check if user selected a device
if [ -z "$CHOICE" ]; then
    echo "No device selected!"
    exit 1
fi

# Find the corresponding IP and MAC for the selected device
DEVICE_INFO=$(echo -e "$DEVICE_MAP" | grep -w "$CHOICE" | head -n 1)
IP_ADDRESS=$(echo "$DEVICE_INFO" | awk '{print $2}')
MAC_ADDRESS=$(echo "$DEVICE_INFO" | awk '{print $3}')

# Check if MAC address was found
if [ -z "$MAC_ADDRESS" ]; then
    echo "Failed to find MAC address for $CHOICE"
    exit 1
fi

# Clean up device name for filenames
DEVICE_NAME_CLEAN=$(echo "$CHOICE" | tr -d '()' | tr ' ' '_' | sed 's/"//g')

# Create WOL script in CGI-bin
WOL_SCRIPT="/www/cgi-bin/$DEVICE_NAME_CLEAN.sh"
cat <<EOF > "$WOL_SCRIPT"
#!/bin/sh
/usr/bin/etherwake -i br-lan "$MAC_ADDRESS"
EOF
chmod +x "$WOL_SCRIPT"

# Create HTML trigger page
WOL_PAGE="/www/wol/$DEVICE_NAME_CLEAN.html"
cat <<EOF > "$WOL_PAGE"
<html>
<head>
    <meta http-equiv="refresh" content="0; url=/cgi-bin/$DEVICE_NAME_CLEAN.sh">
</head>
<body>
    <p>If the page does not redirect automatically, <a href="/cgi-bin/$DEVICE_NAME_CLEAN.sh">click here</a>.</p>
</body>
</html>
EOF

# Print confirmation
echo "WOL script and HTML page created successfully!"
echo "Trigger WOL by opening: http://10.1.1.1/wol/$DEVICE_NAME_CLEAN.html"
echo "Made By PeDitX https://t.me/peditx"
