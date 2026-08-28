# =============================================================================
# mikrotik-starlink-ocean-mode — ocean-on.rsc
#
# Imports the "ocean-on" system script that ENABLES Ocean Mode:
#   - Enables the "ocean: drop WAN" firewall rule (blocks non-whitelisted WAN).
#   - Records the session start (timestamp + WAN rx/tx counters) to a RAM log
#     file "ocean-sessions.txt", so ocean-report can compute usage.
#
# Import once:  /import file-name=ocean-on.rsc
# Run anytime:  /system script run ocean-on
# (or from SSH: ssh admin@<router-ip> '/system script run ocean-on')
#
# NOTE: "ocean-sessions.txt" lives in the RAM disk and is lost on reboot on
# routers without a "flash" dir. Accepted, documented limitation.
# =============================================================================

/system script remove [find name=ocean-on]
/system script add name=ocean-on source={
  :local logname "ocean-sessions.txt"
  :local wanId [/interface find default-name=ether1]
  :local rx [/interface get $wanId rx-byte]
  :local tx [/interface get $wanId tx-byte]
  :local date [/system clock get date]
  :local time [/system clock get time]

  # Enable the drop rule (turn Ocean Mode ON)
  /ip firewall filter set [find comment="ocean: drop WAN"] disabled=no

  # Record session start to RAM log (append)
  # Ensure the file exists first (/file set fails silently on missing file)
  :if ([:len [/file find name=$logname]] = 0) do={ /file add name=$logname type=file }
  :delay 1
  :local old ""
  :if ([:len [/file find name=$logname]] > 0) do={ :set old [/file get $logname contents] }
  :local line ("START " . $date . " " . $time . " rx=" . $rx . " tx=" . $tx)
  /file set $logname contents=($old . $line . "\n")

  :log info "ocean-on: Ocean Mode ENABLED"
  :put "Ocean Mode ENABLED. Session start recorded."
}
