#!/usr/bin/env bash
# Usage: probe-device.sh <ip | mac | hostname-fragment>
# Read-only fingerprint of a device on the home LAN: DHCP lease + Wi-Fi association (router),
# MAC vendor, domains it resolved via pihole (last 24 h), open TCP ports, mDNS services.
# Hosts and access paths come from references/home-infra.local.md; override with env vars.
set -euo pipefail

ROUTER="${ROUTER:-192.168.1.1}"
NUC="${NUC:-root@192.168.1.2}"
q="${1:?usage: probe-device.sh <ip|mac|hostname-fragment>}"

ros() { timeout 20 ssh -o BatchMode=yes "$ROUTER" "$1"; }
nuc() { timeout 30 ssh -o BatchMode=yes "$NUC" "$1"; }

echo "== DHCP lease (router)"
if [[ "$q" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then filter="address=$q"
elif [[ "$q" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then filter="mac-address=${q^^}"
else filter="host-name~\"$q\""; fi
lease=$(ros "/ip dhcp-server lease print terse where $filter")
if [[ -z "${lease//[[:space:]]/}" ]]; then
    echo "no lease matches '$q' (device offline, static IP, or not on this DHCP server)"
    exit 1
fi
echo "$lease"
ip=$(grep -oE '(^| )address=[0-9.]+' <<<"$lease" | head -1 | cut -d= -f2)
mac=$(grep -oE 'mac-address=[0-9A-F:]+' <<<"$lease" | head -1 | cut -d= -f2)

echo; echo "== Wi-Fi association"
ros "/interface wifi registration-table print terse where mac-address=$mac"

echo; echo "== MAC vendor"
oui=$(tr -d : <<<"${mac:0:8}")
if (( 16#${mac:1:1} & 2 )); then
    echo "$mac is locally administered (randomized), vendor unknown"
else
    vendor=$(awk -v o="${oui^^}" 'toupper($1)==o {$1=""; print substr($0,2)}' /usr/share/nmap/nmap-mac-prefixes)
    echo "${mac} -> ${vendor:-not in nmap OUI database}"
fi

echo; echo "== Domains resolved via pihole, last 24 h ($ip)"
nuc "docker exec pihole pihole-FTL sqlite3 /etc/pihole/pihole-FTL.db \"select count(*), domain from queries where client='$ip' and timestamp > unixepoch()-86400 group by domain order by 1 desc limit 40;\""

echo; echo "== Open TCP ports"
scan=$(timeout 180 nmap -Pn -sT --open -T4 -p 1-10000,49152-49160,55443 "$ip")
ports=$(awk '/^[0-9]+\/tcp/' <<<"$scan")
echo "${ports:-no open TCP ports in 1-10000,49152-49160,55443}"

echo; echo "== mDNS services advertised by $ip"
timeout 8 avahi-browse -atrpk | awk -F';' -v ip="$ip" '$1=="=" && $8==ip {print $4" "$5" port="$9" "$10}' | sort -u
