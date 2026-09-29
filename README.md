# pickit2_flutter

A Flutter PICkit 2 programmer with native Android USB and macOS IOKit backends.

## macOS backend

The macOS plugin compiles the pk2cmd C++ programming engine directly into the
plugin and calls it through an Objective-C++ bridge. It does not launch or ship
the `pk2cmd` command-line executable.

The initial desktop feature set includes:

- PICkit 2 connection, serial number, and firmware version
- target auto-detection and manual target selection
- read, erase, blank check, program, and verify
- Intel HEX/BIN loading and exact HEX export of a read target
- program, EEPROM, configuration, and user-ID memory transfer
- masked raw configuration-word editing and HEX/EEPROM/config viewers

The host app needs the `com.apple.security.device.usb` entitlement. The example
runner already includes it in debug and release entitlements.

## pk2cmd license

The incorporated Microchip pk2cmd sources may be used, modified, and
distributed for use with Microchip products only. They are provided without
warranty. The complete required notice is bundled in
`macos/Resources/PK2CMD_LICENSE.txt`, and source-specific third-party notices
remain in `macos/Classes/pk2cmd`.
