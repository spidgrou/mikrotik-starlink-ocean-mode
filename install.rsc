# =============================================================================
# mikrotik-starlink-ocean-mode — install.rsc
#
# One-time / idempotent installer for the router infrastructure:
#   1. Creates the "ocean-whitelist" address-list (domains from whitelist.conf).
#   2. Adds the 4 firewall rules. The final "drop WAN" rule starts DISABLED
#      (default = Ocean OFF).
#   3. Creates the ocean-boot scheduler that forces Ocean OFF on every reboot.
#
# The ocean-on / ocean-off / ocean-report scripts are created by their own
# files (ocean-on.rsc, ocean-off.rsc, ocean-report.rsc). Run this file first,
# then run those three.
#
#   /import file-name=install.rsc
#
# Idempotency: items are removed by comment/name before being re-added, so
# running twice does not duplicate anything.
#
# NOTE ON PERSISTENCE:
# On devices WITHOUT a "flash" directory, files created by /file add live in
# the RAM disk and are LOST on reboot. The ocean session log/report therefore
# do not survive a reboot. This is an accepted, documented limitation.
# The firewall rules, scripts and scheduler themselves ARE persistent.
# =============================================================================

# --- 1. Address-list from whitelist.conf ---
# Remove previous STATIC entries to stay idempotent.
# Dynamic entries (the resolved IPs, flag D) are managed by the DNS resolver
# and are NOT removable via /remove — trying to remove them errors with
# "no such item". Filter dynamic=no so we only touch the static FQDNs.
:foreach id in=[/ip firewall address-list find list=ocean-whitelist dynamic=no] do={ /ip firewall address-list remove $id }
/ip firewall address-list add list=ocean-whitelist address="whatsapp.com"
/ip firewall address-list add list=ocean-whitelist address="whatsapp.net"
/ip firewall address-list add list=ocean-whitelist address="web.whatsapp.com"
/ip firewall address-list add list=ocean-whitelist address="mmg.whatsapp.net"
/ip firewall address-list add list=ocean-whitelist address="media-l3-1.cdn.whatsapp.net"
/ip firewall address-list add list=ocean-whitelist address="windy.com"
/ip firewall address-list add list=ocean-whitelist address="tile.windy.com"
/ip firewall address-list add list=ocean-whitelist address="api.windy.com"
/ip firewall address-list add list=ocean-whitelist address="cdn.windy.com"
/ip firewall address-list add list=ocean-whitelist address="predictwind.com"
/ip firewall address-list add list=ocean-whitelist address="api.predictwind.com"
/ip firewall address-list add list=ocean-whitelist address="cdn.predictwind.com"
/ip firewall address-list add list=ocean-whitelist address="gmail.com"
/ip firewall address-list add list=ocean-whitelist address="mail.google.com"
/ip firewall address-list add list=ocean-whitelist address="accounts.google.com"
/ip firewall address-list add list=ocean-whitelist address="apis.google.com"
/ip firewall address-list add list=ocean-whitelist address="ssl.gstatic.com"
/ip firewall address-list add list=ocean-whitelist address="www.gstatic.com"
/ip firewall address-list add list=ocean-whitelist address="clients.google.com"
/ip firewall address-list add list=ocean-whitelist address="contacts.google.com"
/ip firewall address-list add list=ocean-whitelist address="mail-attachment.google.com"
/ip firewall address-list add list=ocean-whitelist address="ogs.google.com"
/ip firewall address-list add list=ocean-whitelist address="googleusercontent.com"
/ip firewall address-list add list=ocean-whitelist address="google.com"
/ip firewall address-list add list=ocean-whitelist address="outlook.com"
/ip firewall address-list add list=ocean-whitelist address="hotmail.com"
/ip firewall address-list add list=ocean-whitelist address="outlook.office365.com"
/ip firewall address-list add list=ocean-whitelist address="outlook.office.com"
/ip firewall address-list add list=ocean-whitelist address="login.microsoftonline.com"
/ip firewall address-list add list=ocean-whitelist address="login.live.com"
/ip firewall address-list add list=ocean-whitelist address="mail.protection.outlook.com"
/ip firewall address-list add list=ocean-whitelist address="office365.com"
/ip firewall address-list add list=ocean-whitelist address="microsoftonline.com"
/ip firewall address-list add list=ocean-whitelist address="live.com"
/ip firewall address-list add list=ocean-whitelist address="microsoft.com"
/ip firewall address-list add list=ocean-whitelist address="msocdn.com"
/ip firewall address-list add list=ocean-whitelist address="x.com"
/ip firewall address-list add list=ocean-whitelist address="twitter.com"
/ip firewall address-list add list=ocean-whitelist address="api.twitter.com"
/ip firewall address-list add list=ocean-whitelist address="t.co"
/ip firewall address-list add list=ocean-whitelist address="twttr.com"
/ip firewall address-list add list=ocean-whitelist address="twimg.com"

# --- 2. Ensure the WAN interface list (critical) ---
# The "drop WAN" rule below matches on out-interface-list=WAN. If that list
# does not exist, or is empty, the drop rule matches nothing and Ocean Mode
# silently fails to block anything. Make sure the list exists and contains the
# interface Starlink is connected to.
#
# On a default RouterOS config a "WAN" list already exists (defconf) with the
# WAN port in it. If yours is missing/empty, this block creates it and adds
# the interface whose default-name is ether1 (change to your actual WAN port
# if Starlink is on another one).
:if ([:len [/interface list find name=WAN]] = 0) do={
  /interface list add name=WAN comment="defconf"
  :log warning "ocean: created missing WAN interface list"
}
:if ([:len [/interface list member find list=WAN]] = 0) do={
  :local wanIf [/interface get [find default-name=ether1] name]
  /interface list member add list=WAN interface=$wanIf
  :log warning ("ocean: added " . $wanIf . " to WAN interface list")
}
# Verify: the WAN list must have at least one member before the rules are added.
:local wanCount [:len [/interface list member find list=WAN]]
:if ($wanCount = 0) do={
  :log error "ocean: WAN interface list is empty — drop rule will NOT work!"
}

# --- 3. Firewall rules (forward chain) ---
# Remove any previous ocean rules (idempotent — foreach is safe for multi-item)
:foreach id in=[/ip firewall filter find comment~"ocean"] do={ /ip firewall filter remove $id }
# Accept traffic to whitelisted domains (the whitelist gate)
/ip firewall filter add chain=forward comment="ocean: accept whitelist" \
  action=accept dst-address-list=ocean-whitelist
# Accept DNS (UDP and TCP) so clients can always resolve
/ip firewall filter add chain=forward comment="ocean: accept DNS udp" \
  action=accept protocol=udp dst-port=53
/ip firewall filter add chain=forward comment="ocean: accept DNS tcp" \
  action=accept protocol=tcp dst-port=53
# Drop everything else toward WAN (the actual Ocean Mode gate).
# Matches on out-interface-list=WAN — see the WAN setup above.
# Starts DISABLED by default = Ocean OFF. Enabled by ocean-on.
/ip firewall filter add chain=forward comment="ocean: drop WAN" \
  action=drop out-interface-list=WAN disabled=yes

# --- 4. Boot scheduler: force Ocean OFF on every reboot ---
/system scheduler remove [find name=ocean-boot]
/system scheduler add name=ocean-boot start-time=startup interval=0s \
  on-event="/system script run ocean-off"

:put "Ocean Mode infrastructure installed. Rules are DISABLED (Ocean OFF)."
:put "WAN list members: $wanCount (must be >=1 for the drop rule to work)."
:put "Now import ocean-on.rsc, ocean-off.rsc and ocean-report.rsc."
