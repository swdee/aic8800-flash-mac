#!/system/bin/sh
# flash_mac_android.sh — burn a permanent Wi-Fi MAC into an AIC8800 (DC/DW/D80) efuse, on Android.
#
# Runs ON THE DEVICE as root (adb shell / ssh), not on a Linux host.
# Derived from https://github.com/swdee/aic8800-flash-mac (USB/D80 flow) with the SDIO/Android deltas:
#   - loader module is aic8800_bsp.ko (not aic_load_fw_usb.ko)
#   - the RF test firmware must sit in the module dir before testmode is loaded
#   - `svc wifi disable` leaves aic8800_bsp loaded: it MUST be rmmod'ed or testmode is silently ignored
#
# The efuse MAC block can be written TWICE in the life of the chip. This script refuses to write unless
# the driver reports a remaining count >= 1, and it never retries on its own.
#
# Usage:  ./flash_mac_android.sh AA:BB:CC:DD:EE:FF
# Env:    MODDIR=/system/vendor/modules  TOOL=/data/local/tmp/wifi_test  IFACE=wlan0
#
# WARNING: this shuts the Wi-Fi down. On a headless device, make sure a boot script re-enables it
# (`settings put global wifi_on 1; svc wifi enable`) and that you have a wired/serial way back in.

MODDIR=${MODDIR:-/system/vendor/modules}
TOOL=${TOOL:-/data/local/tmp/wifi_test}
IFACE=${IFACE:-wlan0}

say() { echo "[flash_mac] $*"; }
die() { say "ERROR: $*"; say "no write performed"; exit 1; }

[ "$(id -u)" = "0" ] || die "must run as root"
[ -x "$TOOL" ] || die "$TOOL not executable (cross-compile wifi_test.c and push it)"
[ -f "$MODDIR/aic8800_bsp.ko" ] || die "$MODDIR/aic8800_bsp.ko not found (set MODDIR)"
[ -f "$MODDIR/aic8800_fdrv.ko" ] || die "$MODDIR/aic8800_fdrv.ko not found (set MODDIR)"

MAC=$(echo "$1" | tr 'A-F' 'a-f')
echo "$MAC" | grep -qE '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$' || die "usage: $0 AA:BB:CC:DD:EE:FF"
FIRST=$(echo "$MAC" | cut -d: -f1)
# refuse a multicast address
[ $((0x$FIRST & 1)) -eq 0 ] || die "multicast MAC refused"

say "target MAC: $MAC"

# --- 1. stop Wi-Fi and unload BOTH modules (the loader stays resident otherwise) ---
say "disabling Wi-Fi"
svc wifi disable 2>/dev/null
i=0
while [ $i -lt 25 ]; do
    cat /proc/modules | grep -q aic8800_fdrv || break
    sleep 1; i=$((i+1))
done
i=0
while [ $i -lt 20 ]; do
    rmmod aic8800_bsp 2>/dev/null
    cat /proc/modules | grep -q aic8800_bsp || break
    sleep 1; i=$((i+1))
done
cat /proc/modules | grep -q aic8800_bsp && die "aic8800_bsp still loaded, cannot enter testmode"
[ -f "$MODDIR/lmacfw_rf_8800dc.bin" ] || say "WARNING: lmacfw_rf_8800dc.bin absent from $MODDIR (needed for AIC8800DC)"

# --- 2. RF test mode ---
say "loading testmode"
insmod "$MODDIR/aic8800_bsp.ko" testmode=1 || die "insmod aic8800_bsp testmode=1 failed"
sleep 2
insmod "$MODDIR/aic8800_fdrv.ko" || die "insmod aic8800_fdrv failed"
i=0
while [ ! -e "/sys/class/net/$IFACE" ] && [ $i -lt 30 ]; do sleep 1; i=$((i+1)); done
[ -e "/sys/class/net/$IFACE" ] || die "$IFACE did not appear in testmode"
ip link set "$IFACE" up 2>/dev/null

# --- 3. read the counter: outside testmode this answers a meaningless remain:0 ---
BEFORE=$($TOOL "$IFACE" get_mac_addr 2>&1)
say "before: $(echo "$BEFORE" | tr '\n' ' ')"
echo "$BEFORE" | grep -q "remain:" || die "counter not reported — not in testmode?"
REMAIN=$(echo "$BEFORE" | sed -n 's/.*remain:\([0-9]*\).*/\1/p' | head -1)
[ -n "$REMAIN" ] || die "cannot parse remaining writes"
say "remaining efuse writes: $REMAIN"
[ "$REMAIN" -ge 1 ] || die "efuse reports 0 writes left — refusing"
[ "$REMAIN" -ge 2 ] || say "WARNING: only ONE write left. A typo is unrecoverable."

echo "$BEFORE" | grep -q "$MAC" && die "MAC is already $MAC, nothing to do"

# --- 4. write, then read back ---
say "writing efuse"
SET=$($TOOL "$IFACE" set_mac_addr $(echo "$MAC" | tr ':' ' ') 2>&1)
say "set_mac_addr: $(echo "$SET" | tr '\n' ' ')"

AFTER=$($TOOL "$IFACE" get_mac_addr 2>&1)
say "after: $(echo "$AFTER" | tr '\n' ' ')"
echo "$AFTER" | grep -qi "$MAC" || say "WARNING: read-back does not show $MAC — check dmesg before trusting this"

say "done — power cycle the device so the normal firmware reloads with the burned MAC"
sync
reboot
