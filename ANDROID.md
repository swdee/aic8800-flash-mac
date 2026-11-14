Discussion and background: https://github.com/swdee/aic8800-flash-mac/issues/1

# Android / SDIO (AIC8800DC) — notes from a successful flash, and the trap that makes it look impossible

Thanks for this repo — it's the only clear write-up of the efuse MAC burn. I used it as the basis to flash
an **Android 6.0.1 / Allwinner A33** photo frame whose Wi-Fi is an **AIC8800DC on SDIO**, and three things
differ from the USB/D80 flow enough to waste a day. Sharing them.

## What differs on SDIO/Android

| Step | USB/D80 (this repo) | SDIO/Android (AIC8800DC) |
|---|---|---|
| Loader module | `aic_load_fw_usb.ko` | `aic8800_bsp.ko` — also has the `testmode` parameter |
| Driver module | `aic8800_fdrv_usb.ko` | `aic8800_fdrv.ko` |
| Firmware dir | `/lib/firmware/...` | whichever `aic_fw_path` was compiled in (here `/system/vendor/modules`) |
| RF firmware | `lmacfw_rf_8800d80_u02.bin` | `lmacfw_rf_8800dc.bin` (from `radxa-pkg/aic8800`, `src/SDIO/driver_fw/fw/aic8800DC/`, 170 014 bytes, sha256 `a445652f6e0238b228d550d0f2067a4554b7cc9d9fd60e889f4a96326288d42b`) |
| Userspace tool | `aicrf-test` package | not shipped on Android; `wifi_test.c` from the same driver tree cross-compiled |

`wifi_test` talks to the driver through `ioctl(SIOCDEVPRIVATE+1)` and `struct android_wifi_priv_cmd`, so a
**static armv7 glibc binary** runs fine on Android 6:

```
arm-linux-gnueabihf-gcc -O2 -static -o wifi_test_arm wifi_test.c
```

## The trap: `svc wifi disable` leaves the loader module loaded

On Android the natural way to stop Wi-Fi is `svc wifi disable` (or toggling Wi-Fi in Settings). That unloads
`aic8800_fdrv` but **leaves `aic8800_bsp` resident**. The next step then fails in a way that looks
harmless and is easy to miss:

```
# insmod /system/vendor/modules/aic8800_bsp.ko testmode=1
insmod: failed to load aic8800_bsp.ko: File exists     # rc=1
# insmod /system/vendor/modules/aic8800_fdrv.ko
# fdrv rc=0                                              # ...but in NORMAL mode
```

The interface comes up, the commands are accepted, and nothing tells you the RF firmware was never loaded.
`get_mac_addr` then answers:

```
get_mac_addr:
done: get macaddr = 00 : 00 : 00 : 00 : 00 : 00
  (remain:0)
```

`remain:0` looks like "the two efuse writes are already used, this chip is dead" — it is **not**. Outside
testmode the rftest request is not served, the reply struct stays zeroed, and both the MAC and the counter
are meaningless. Correct order:

```sh
svc wifi disable
# wait until aic8800_fdrv is gone from /proc/modules
rmmod aic8800_bsp                     # <-- the missing step
insmod $MODDIR/aic8800_bsp.ko testmode=1
insmod $MODDIR/aic8800_fdrv.ko
wait for wlan0
wifi_test wlan0 get_mac_addr          # now (remain:N) is real
```

Same chip, same command, in testmode:

```
get macaddr = 00 : 00 : 00 : 00 : 00 : 00
  (remain:2)                           # virgin efuse, two writes available
```

after `wifi_test wlan0 set_mac_addr 88 00 33 77 xx xx` (rc=0):

```
get macaddr = 88 : 00 : 33 : 77 : xx : xx
  (remain:1)
```

dmesg confirms the burn:

```
match set_mac_addr
set macaddr:88,0,33,77,xx,xx
...
match get_mac_addr 0x3377xx xx,0x8800 (remain:1)
```

## Other findings that may save someone time

- **`MAC_ADDR=` in `aic_userconfig_*.txt` cannot work.** The parser `rwnx_parse_configfile()` exists
  (`rwnx_cfgfile.c`) but its call site in `rwnx_main.c` is inside `#if 0`. The MAC comes from the efuse,
  otherwise from the default `CONFIG_MAC_RANDOM_IF_NO_MAC_IN_EFUSE` build option (which is why the random
  MAC always keeps the vendor prefix and only randomises the last two bytes).
- **Do not switch testmode with rmmod/insmod only.** Moving between `testmode=0` and `testmode=1` needs a
  power cycle of the chip; a `reboot` is the reliable way and also restores the normal firmware.
- **Android persists the Wi-Fi off state.** `svc wifi disable` writes `wifi_on=0` to Settings.Global and it
  survives a reboot: on a headless/wall-mounted device you lose your only access channel. Add
  `settings put global wifi_on 1` + `svc wifi enable` to a boot script **before** attempting the flash.
- **Vendor OUI:** keeping the chip's own prefix (`88:00:33` for AIC) avoids being classified as a
  "private/randomised MAC" by the AP controller. Don't burn a locally-administered (`02:…`) address.
- The p2p interface takes MAC+1 automatically, so leave a gap.

Happy to open a PR with an `ANDROID.md` section and a `flash_mac_android.sh` (parameterised: module dir,
wifi_test path, MAC) if you think it fits the repo.
