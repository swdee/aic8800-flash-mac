#!/bin/bash
# apt install aicrf-test

find_interface()
{
	while true; do
		interface=$(ip link show | grep -o 'wlan[0-9]*')

		if [[ -n "$interface" ]]; then
		    echo "Interface $interface found, executing commands..."
		    break
		else
		    echo "No wlan interface found, continuing to check..."
		fi
		sleep 2
	done
}

is_valid_mac() {
    local mac=$1
    
    if [[ $mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        return 0
    else
        return 1
    fi
}

read -p "Please enter a MAC address (format: XX:XX:XX:XX:XX:XX): " mac_address

if is_valid_mac "$mac_address"; then
    echo "The MAC address is valid."

    # Ask for user confirmation
    read -p "Do you confirm this MAC address? (y/n): " confirmation
    if [[ $confirmation =~ ^[Yy](es)?$ ]]; then
        echo "User has confirmed the MAC address."
    else
        echo "User did not confirm the MAC address."
        exit -1
    fi
else
    echo "The MAC address is invalid, please check your input."
    exit -1
fi


# Install aicrf-test
apt update
apt install aicrf-test

# Replace Binary File
cp /lib/firmware/aic8800_fw/USB/aic8800D80/lmacfw_rf_8800d80_u02.bin ./lmacfw_rf_8800d80_u02.bin.bak
cp ./lmacfw_rf_8800d80_u02.bin /lib/firmware/aic8800_fw/USB/aic8800D80/

# Get Module File
cp /lib/modules/`uname -r`/updates/dkms/aic_load_fw_usb.ko.xz ./
cp /lib/modules/`uname -r`/updates/dkms/aic8800_fdrv_usb.ko.xz ./
xz -d aic_load_fw_usb.ko.xz 
xz -d aic8800_fdrv_usb.ko.xz

server_mac=$(echo $mac_address | tr ':' ' ')

# testmode
rmmod aic8800_fdrv
rmmod aic_load_fw
insmod aic_load_fw_usb.ko testmode=1
insmod aic8800_fdrv_usb.ko
find_interface
    
# burn the mac address (need aicrf-test)
wifi_test wlan0 set_mac_addr $server_mac

# recover
rmmod aic8800_fdrv
rmmod aic_load_fw
insmod aic_load_fw_usb.ko
insmod aic8800_fdrv_usb.ko
find_interface

cp ./lmacfw_rf_8800d80_u02.bin.bak /lib/firmware/aic8800_fw/USB/aic8800D80/lmacfw_rf_8800d80_u02.bin

exit 0
