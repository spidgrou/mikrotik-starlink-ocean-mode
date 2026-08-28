# =============================================================================
# mikrotik-starlink-ocean-mode — ocean-off.rsc
#
# Imports the "ocean-off" system script that DISABLES Ocean Mode:
#   - Disables the "ocean: drop WAN" firewall rule (opens all WAN traffic).
#   - Records the session end (timestamp + WAN rx/tx counters) to the same RAM
#     log file, so ocean-report can compute duration and usage.
#
# Import once:  /import file-name=ocean-off.rsc
# Run anytime:  /system script run ocean-off
# (or from SSH: ssh admin@<router-ip> '/system script run ocean-off')
# =============================================================================

/system script remove [find name=ocean-off]
/system script add name=ocean-off source={
  :local logname "ocean-sessions.txt"
  :local wanId [/interface find default-name=ether1]
  :local rx [/interface get $wanId rx-byte]
  :local tx [/interface get $wanId tx-byte]
  :local date [/system clock get date]
  :local time [/system clock get time]

  # Disable the drop rule (turn Ocean Mode OFF)
  /ip firewall filter set [find comment="ocean: drop WAN"] disabled=yes

  # Record session end to RAM log (append)
  :if ([:len [/file find name=$logname]] = 0) do={ /file add name=$logname type=file }
  :delay 1
  :local old ""
  :if ([:len [/file find name=$logname]] > 0) do={ :set old [/file get $logname contents] }
  :local line ("END " . $date . " " . $time . " rx=" . $rx . " tx=" . $tx)
  /file set $logname contents=($old . $line . "\n")

  :log info "ocean-off: Ocean Mode DISABLED"
  :put "Ocean Mode DISABLED. Session end recorded."
}
