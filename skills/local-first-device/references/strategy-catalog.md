# Strategy catalog

Starting checklist of strategies per device family, best-first within each family. Project names are leads, not guarantees: confirm each is maintained and supports the exact model and firmware before recommending it.

## Contents
- Zigbee
- Thread / Matter
- Bluetooth LE
- Wi-Fi: Tuya and white-label (most Brazilian "smart" brands)
- Wi-Fi: ESP-based and open firmware
- Wi-Fi: vendors with documented local APIs
- Appliances (AC, laundry, fridges, vacuums)
- Cameras, TVs, media, printers
- IR / RF / dumb devices
- Cloud-replacement pattern
- Reverse engineering from scratch

## Zigbee
1. Zigbee2MQTT (check zigbee2mqtt.io/supported-devices for the exact model id). Unsupported device: a Z2M external converter, built from the device's clusters (`zigbee2mqtt/bridge/request/device/interview`, logs of the raw messages).
2. ZHA quirk if Z2M support is worse for that model (rare).
Fully local by nature; no WAN concerns.

## Thread / Matter
- Matter over Wi-Fi: HA Matter integration needs the Matter server add-on/container; pair from the HA companion app.
- Matter over Thread: also needs a Thread border router (OpenThread Border Router on a radio). Check the infra file for whether one exists; if not, say so and offer it as an infra addition (or a different radio of the same product line).
- Many Matter devices also expose the vendor's own local API, which may expose more features than Matter does.

## Bluetooth LE
1. Native HA BLE integrations (BTHome, xiaomi_ble, govee_ble, switchbot, etc.) over HA Bluetooth / ESPHome Bluetooth proxies (range is the usual issue; ESPHome proxies fix it).
2. Custom firmware for the sensor itself (pvvx ATC firmware for Xiaomi LYWSD03MMC-family thermometers → BTHome, no bind key).
3. Encrypted vendor BLE (Tuya BLE, Xiaomi MiBeacon v4/v5): extract keys once (tuya_ble integration, Xiaomi-cloud-tokens-extractor), then local forever.
4. Unknown GATT protocol: capture with Android HCI snoop log on the rooted phone (`re-android`), decode, implement as ESPHome `ble_client` lambdas or a small HA integration.

## Wi-Fi: Tuya and white-label
Positivo Casa Inteligente, Intelbras (some lines), Elgin smart plugs, Nova Digital, generic AliExpress: usually Tuya inside. Pihole queries to `*.tuya*.com` / `*.tuyaus.com` / `a1.tuyaeu.com` confirm it.
1. Custom firmware OTA when the module and firmware allow it: tuya-cloudcutter (BK7231/RTL8710BN profiles, exploit patched in newer firmware) → OpenBeken or ESPHome (LibreTiny). Gives fully local, no keys, no Tuya.
2. tuya_local / localtuya with the device's local key: obtain the key once (tinytuya wizard with a Tuya IoT developer account, or cloudcutter key extraction), then block WAN. Protocol 3.3/3.4/3.5 local TCP 6668. Note: re-pairing in the app rotates the local key.
3. Physical module swap / serial flash (CB2S/CB3S/WB2S → ESP-C3/ESP-02S drop-in, or UART flash of BK7231 with ltchiptool) — last resort per policy.
4. Tuya cloud integration — cloud, last.

## Wi-Fi: ESP-based and open firmware
Device already runs ESPHome/Tasmota/WLED, or has an ESP8266/ESP32 inside (Sonoff, Shelly, Athom, many LED controllers).
1. Already open firmware: adopt in ESPHome dashboard / Tasmota integration / WLED integration.
2. OTA flash without opening: Sonoff DIY mode (zeroconf REST), Shelly → Tasmota/ESPHome via mgos-to-tasmota, Athom ships ESPHome.
3. Serial flash with esptool (last resort; usually trivial on ESP boards with exposed pads).

## Wi-Fi: vendors with documented local APIs
Shelly (local RPC/HTTP, core integration), WLED, Yeelight (LAN control toggle), LIFX, Nanoleaf, Philips Hue bridge, IKEA Dirigera, Govee LAN API (enable per device in app), Sonoff/eWeLink LAN (SonoffLAN custom integration, LAN mode needs device key once from cloud), Xiaomi miio/miot (token via Xiaomi-cloud-tokens-extractor, then local `xiaomi_miio` / `xiaomi_miot`), Broadlink (local), Daikin (local), Gree (local), Bambu printers (LAN mode + ha-bambulab).
Pattern: one-time cloud step to fetch a token/key, then local control and WAN block.

## Appliances
- **AC**: Midea family (Midea, Springer Midea, Carrier, Comfee, many Brazilian inverters): midea_ac_lan, or ESPHome `midea` component on an ESP dongle replacing the USB/UART Wi-Fi stick. LG ThinQ: rethink cloud replacement (already deployed at home, see inventory). Gree/Daikin: local core integrations. Samsung WindFree: SmartThings cloud, local options weak, check for ESP UART projects. Last resort for any split AC: ESP on the wired-remote/service port (LG CN-REMO via esphome-lg-controller, Daikin S21, Mitsubishi CN105) or IR blaster.
- **Laundry / fridges / dishwashers**: LG → rethink; Samsung → cloud only in practice; Electrolux/Brastemp/Consul (Whirlpool BR) → check for local projects, otherwise cloud; RE candidate.
- **Robot vacuums**: Valetudo (Roborock, Dreame, some Viomi/Xiaomi; rooting difficulty varies from OTA to UART), Roborock local via token; Ecovacs → Bumper (local cloud replacement) with DNS redirect.

## Cameras, TVs, media, printers
- Cameras: RTSP/ONVIF → Frigate (already running at home) + HA. No RTSP: open firmware (OpenIPC, thingino for Ingenic SoCs; check the SoC first). Tuya/Intelbras Mibo-style cloud cameras: check for RTSP toggles, ONVIF, or firmware replacement before giving up.
- TVs: LG webOS (webostv), Android TV (androidtv_remote), Cast; Samsung Tizen (samsungtv, local).
- Printers: OctoPrint, Moonraker/Klipper, Bambu LAN mode, Prusa Link.

## IR / RF / dumb devices
- IR: ESPHome `remote_transmitter`/`remote_receiver` (IR blaster, maybe an existing ESPHome node in the room), Broadlink. HA climate via ESPHome `climate_ir` platforms for many AC brands.
- 433/315 MHz: ESPHome with CC1101 or RXB6, or rtl_433 with an RTL-SDR → MQTT.
- Mains appliances with no brains: smart plug / relay with power monitoring (ESPHome/Tasmota) and state inferred from power draw.

## Cloud-replacement pattern
When the device only talks to its cloud but the protocol is understood (or understandable), run a local server that impersonates it:
1. Learn the endpoints: pihole query log for the device's IP.
2. Point them at a local service with a pihole `dns.hosts` record; the router's DNS hijack makes this work even when the device hardcodes 8.8.8.8. It fails against DoH/DoT or hardcoded IPs: then a MikroTik dstnat rule for that destination IP/port is the fallback.
3. TLS: the device must accept the local server's certificate. Works when the device trusts a CA it receives during provisioning (LG ThinQ), skips validation, or can be re-provisioned with a custom CA. A device that pins a vendor CA in firmware needs firmware modification instead.
4. Local server publishes to HA via MQTT discovery.
Known instances: rethink (LG ThinQ), Bumper (Ecovacs), tuya-cloudcutter (as an exploit delivery path), community servers for some Chinese camera/vacuum clouds.

## Reverse engineering from scratch
Use when nothing above exists. Order of operations, cheapest signal first:
1. **Passive network**: pihole query log (domains), MikroTik `/tool sniffer` streaming to Wireshark (TZSP) or `torch` for flows (protocols, ports, cleartext vs TLS, MQTT vs HTTP vs custom UDP).
2. **Vendor app**: fetch the APK with `playstore`, decompile and hook with `re-android` (jadx for API endpoints and payload models, Frida for TLS unpinning, crypto keys, and local-protocol code paths). Many apps contain a LAN-control code path the cloud never advertises.
3. **MITM** the app/device traffic (mitmproxy via `re-android`) to collect request/response pairs and state payloads.
4. **BLE**: Android HCI snoop log while operating the app, decode GATT writes/notifications.
5. **Firmware**: FCC ID → chip → dump (OTA URL from the app/MITM, or UART/esptool/ltchiptool as last resort) → analyze with `reverse-engineer-anything`. Look for local listeners, provisioning protocol, cert handling.
6. **Implement**: smallest artifact that HA consumes natively — ESPHome external component (if an ESP ends up in the loop), HA custom integration (Python, local push if possible), or a bridge container publishing MQTT discovery (the rethink model). Deploy following the infra file's patterns.
Estimate effort honestly in the strategy list: "cleartext local protocol, a few hours" vs "TLS with pinned CA and signed firmware, weeks, may not be feasible".
