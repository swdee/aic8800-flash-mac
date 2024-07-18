# AIC8800 Wifi MAC Address

The Radxa Rock 5C uses the AIC8800 Wifi chipset.  On the device I received
the Wifi MAC Address would [randomly change](https://forum.radxa.com/t/rock-5c-mac-address-changes-on-reboot/21781) each time the device rebooted.  Follow these instructions to flash a permanent MAC Address to the device.

## Requirements

* You must be running Radxa's 6.1 Linux image for the Rock 5C from [here](https://github.com/radxa-build/rock-5c-6_1/releases/download/rsdk-t3/rock-5c-6_1_bookworm_kde_t3.output.img.xz).  So install this on an SD card to perform the flashing process, if you use another OS image.

* When running the flash process you must do it from a TTL terminal, an SSH session over a wired ethernet connection, or locally (monitor and keyboard).  DO NOT attempt this over a Wifi connection to the device as the process shuts the Wifi down.

* Decide what MAC Address you want to flash, if you are not sure then pick the current one that has been randomly assigned.   Using `ip addr` to see what this is.


## Flash Process

Boot up into the above 6.1 Linux image and connect to the shell terminal.

Clone this git repository with flash script and firmware.
```
apt install git
git clone https://github.com/swdee/aic8800-flash-mac.git
```

Run script as super user.
```
cd aic8800-flash-mac/
sudo bash flash_mac.sh
```

Regular output of the script flashing process.
```
Please enter a MAC address (format: XX:XX:XX:XX:XX:XX): 11:22:33:44:55:66
The MAC address is valid.
Do you confirm this MAC address? (y/n): y
User has confirmed the MAC address.
Hit:1 https://radxa-repo.github.io/bookworm-test bookworm-test InRelease
Hit:2 https://radxa-repo.github.io/rk3588s2-bookworm-test rk3588s2-bookworm-test InRelease
Hit:3 https://deb.debian.org/debian bookworm-backports InRelease
Hit:4 https://deb.debian.org/debian-security bookworm-security InRelease
Hit:5 https://deb.debian.org/debian bookworm-updates InRelease
Hit:6 https://deb.debian.org/debian bookworm InRelease
Hit:7 https://download.vscodium.com/debs vscodium InRelease
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
102 packages can be upgraded. Run 'apt list --upgradable' to see them.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
aicrf-test is already the newest version (3.0+git20240327.3561b08f-2).
0 upgraded, 0 newly installed, 0 to remove and 102 not upgraded.
xz: aic_load_fw_usb.ko: File exists
xz: aic8800_fdrv_usb.ko: File exists
rmmod: ERROR: Module aic8800_fdrv is not currently loaded
rmmod: ERROR: Module aic_load_fw is not currently loaded
No wlan interface found, continuing to check...
No wlan interface found, continuing to check...
No wlan interface found, continuing to check...
No wlan interface found, continuing to check...
Interface wlan0 found, executing commands...
set_mac_addr:
done
No wlan interface found, continuing to check...
No wlan interface found, continuing to check...
No wlan interface found, continuing to check...
Interface wlan0 found, executing commands...
```

Run `ip addr` to see MAC Address.
```
5: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 11:22:33:44:55:66 brd ff:ff:ff:ff:ff:ff
```
