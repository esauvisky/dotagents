---
name: local-first-device
description: Bring any new smart device, appliance, gadget or sensor into the home setup (Home Assistant, Zigbee2MQTT, ESPHome, MQTT, pihole, MikroTik) as locally as possible. Researches the exact model, ranks every integration strategy from fully local to cloud (native integrations, HACS, custom firmware, cloud-replacement servers, DNS redirection, full protocol reverse engineering), lets the user pick, then implements it end to end on the home server. Use whenever the user mentions a device they bought, received, or are considering ("comprei um...", "chegou meu...", "how do I get X into HASS", "can I control Y without the cloud", "de-cloud", "local control", Tuya/LG/Xiaomi/Positivo/Intelbras/etc. gadgets), even if they do not say Home Assistant.
---

# Local-first device integration

Goal: the device works from Home Assistant with no vendor cloud at runtime, with the most features, the least maintenance, and the least risk. Cloud is a labelled fallback, never the default answer.

The home's concrete layout (server, networks, DNS, router, phone, deploy patterns, device inventory) is in `references/home-infra.local.md`. Read it first. It is gitignored. If it is missing (fresh clone), rebuild it by probing the server and router read-only (`scripts/probe-device.sh` shows the access paths) and write it before continuing.

Infra drifts. Re-verify only the facts the chosen strategy depends on (free ports, macvlan IPs in use, free RAM, compose services) with one cheap probe instead of trusting the file blindly, and update the file when it is wrong.

## Workflow

### 1. Identify the device precisely

A brand name is not enough; white-label products hide the real platform. Pin down:

- Exact model / SKU, and region variant (Brazilian models often differ from US/EU ones).
- Radios: Wi-Fi 2.4/5 GHz, BLE, Zigbee, Thread/Matter, IR, 433 MHz RF, wired/serial service port.
- The silicon when it matters: FCC ID → internal photos (fccid.io) or teardown posts identify the module (ESP8266/ESP32, Beken BK7231, Realtek RTL87xx, WinnerMicro W800, Tuya CBx/WBx modules, LG LCW-xxx...). This decides whether custom firmware is possible.
- The vendor app (package name) and what cloud it uses (Tuya white-label, Smart Life, eWeLink, Mi Home, ThinQ...).
- Current firmware version if known; vendors patch exploit paths (cloudcutter, rooting methods).

If the device is already on the network, `scripts/probe-device.sh <ip|mac|hostname-fragment>` pulls its DHCP lease, the domains it queries in pihole (the fastest way to learn which cloud and protocol family it speaks), open ports and mDNS services.

Ask the user for a label photo or model number only if the research cannot proceed without it.

### 2. Research every path

Run independent lookups in parallel (subagents are fine). Check what already exists before considering reverse engineering. Prior art turns weeks into minutes: the LG AC took one `git clone` because someone had already reversed ThinQ.

Sources, roughly in order:

1. Home Assistant core integrations (home-assistant.io/integrations), including ones already configured at home (see the infra file); an existing `tuya_local` or `esphome` setup may cover the device with zero new infrastructure.
2. HACS / custom components on GitHub (`"<brand> <model>" home assistant`, `"<brand> local api"`), checking last commit date and open issues for the user's model.
3. Zigbee2MQTT supported devices, ESPHome devices (devices.esphome.io), Tasmota templates (templates.blakadder.com), OpenBeken / LibreTiny / tuya-cloudcutter device profiles.
4. Cloud-replacement projects (local servers impersonating the vendor cloud) and RE writeups, forum threads (community.home-assistant.io, Reddit, GitHub issues), especially Brazilian forums for local models.

`references/strategy-catalog.md` lists known strategies and projects per device family. Treat it as a starting checklist, not as current truth: verify every project is alive and supports the specific model and firmware.

### 3. Rank the strategies

Score every viable option on these axes, in this priority order:

1. **Locality**: no cloud at runtime is required to rank high. No cloud during setup is better still. Note whether the device can then be blocked from the WAN.
2. **Coverage**: which features reach HA (state, control, energy, diagnostics), push vs polling, latency.
3. **Robustness**: core integration > maintained HACS component > small bridge container > custom code. Consider whether a vendor auto-OTA can silently break it, and if so pair the option with a WAN block.
4. **Effort and risk**: reversible? brick risk? warranty? physical access needed?
5. **Footprint**: the server's RAM is tight (see infra file); prefer in-HA integrations or tiny containers over heavy services.

User policy for what may rank at the top. The overall order is: non-invasive local options, then invasive local options, then cloud.

- OTA custom firmware (ESPHome, Tasmota, OpenBeken, cloudcutter, Valetudo-style rooting without opening the device) and blocking WAN at the router are first-class options.
- Opening the device, UART/serial flashing, soldering, module swaps, or wiring an ESP to a service port: last resort. Rank every invasive option below every non-invasive local option (including "one-time cloud step, then local + WAN block"); it may only lead when nothing non-invasive exists, and preferably when someone has documented doing it on this model.
- Keeping the vendor app working is not a goal. Mention bridge modes when they exist, but do not trade locality for them.
- Cloud integrations go last among the options that can actually be done today, explicitly labelled as cloud, and only when no local path exists or as a temporary stopgap while a local one is built.
- Options that are local but not doable today (no known root for this model, an RE project with doubtful odds, returning the device for a supported one) do not go in the ranked table. List them after it under "Not viable now", one line each with what would change that (e.g. "watch Valetudo for ijai support"). This keeps the table honest: every row is something the user could pick now.
- Weaker but doable local fallbacks always get a row, even when a much better option exists: an IR blaster for anything with a remote, a power-monitoring smart plug for dumb loads, a service-port ESP. They are what the user falls back to if the top options fail, so a one-line row is enough.

When nothing local exists, include **full reverse engineering** as a real option with a concrete plan rather than a footnote (see the RE section of the catalog): what to capture first, which skill handles each part (`playstore` to fetch the vendor APK, `re-android` for jadx/Frida/mitmproxy/BLE snoop on the rooted phone, `reverse-engineer-anything` for firmware and native binaries), what the end artifact would be (HA custom integration, ESPHome external component, or an MQTT bridge container publishing HA discovery), and an honest difficulty estimate.

### 4. Present and let the user pick

The user decides from the table, so keep everything else lean: aim for ~500 words excluding links. Only the recommended option gets a section (how it works, numbered steps on this setup, risks, evidence links). Every other option lives in its table row plus at most one sentence below the table when the row cannot carry a key caveat. Detailed steps for another option come later, if the user picks it. Write in the user's language and register.

Hard caps that keep it there: intro of at most 3 sentences, at most 7 numbered steps of one line each, at most 3 risks, the 3 strongest evidence links, at most 4 questions. Before presenting, count the words (`wc -w`); if it is well over 500, cut detail from the recommended section, not options from the table.

Output format:

```
# <Device> (<exact model>) — local integration options

<two or three sentences: what the device really is (platform/chip/cloud), and the bottom line>

| # | Strategy | Local? | What you get in HA | Effort / risk |
|---|----------|--------|--------------------|---------------|
| 1 | ...      | fully / setup-only cloud / cloud | ... | ... |

## 1. <Strategy name> (recommended)
- How it works: ...
- Steps on this setup: concrete steps using the real hosts, networks and services from the infra file
- Risks / what can go wrong: ...
- Evidence: links to the project, issue or writeup proving it works for this model

Other options: <one sentence per option only where the table row needs a caveat>

Not viable now: <one line each, or omit>
```

If the research turned up problems in the home infrastructure itself (a service down, drifted facts), add a short "noticed along the way" note before the questions; do not mix it into the options.

Then ask the user which option to execute, together with anything only they can provide (physical button presses, a label photo, accepting a flash). Ask everything in one batch and stop until they answer.

### 5. Execute the pick end to end

The user's pick authorizes the steps described for that option, including the ones that change state on the server, router and phone. Pause again only if a step outside the described plan turns out to be needed, or something proves more destructive than described (e.g. a flash path that cannot be rolled back when the plan said it could).

Follow the home's deploy patterns from the infra file: compose service conventions and backup naming, network choice (bridge, host, or macvlan when a port the bridge needs is taken), pihole record editing plus cache reload, MikroTik static lease and WAN block, HA verification. Remove setup-only hacks (temporary DNS redirects, test firewall rules) once the device is running.

### 6. Verify

- Device online in its bridge/integration logs.
- Entities exist in HA (read the entity registry, see infra file) and show live, plausible values.
- Read-only checks are free. Before sending a command that physically actuates the device (turning on an AC, opening a lock), ask the user, since they may not be next to it.
- If WAN was blocked, confirm the device keeps working after the block (some devices reboot-loop without NTP or their cloud; this is when you find out).

### 7. Record

Update the device inventory in `references/home-infra.local.md`: model, IP/MAC, strategy used, integration/entities, quirks learned, follow-ups (e.g. "lease still dynamic"). Add any infra fact you had to discover the hard way so the next device starts with it.
