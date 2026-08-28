# =============================================================================
# mikrotik-starlink-ocean-mode — ocean-report.rsc
#
# Imports the "ocean-report" system script that prints a formatted Ocean Mode
# usage report to the terminal (STDOUT). Because the session log lives in the
# RAM disk, the report is emitted directly via :put so it can be captured
# over SSH without relying on a downloadable file.
#
# Import once:  /import file-name=ocean-report.rsc
# Run anytime:  /system script run ocean-report
# (or from SSH: ssh admin@<router-ip> '/system script run ocean-report')
#
# Output example:
#   === OCEAN MODE — REPORT ===
#   Generated: 2026-08-28 10:50:00
#   Status:    ENABLED (last session open)
#   Log:       ocean-sessions.txt (RAM disk — lost on reboot)
#   --- sessions ---
#   START 2026-08-28 10:49:00 rx=... tx=...
#   END   2026-08-28 10:49:30 rx=... tx=...
# =============================================================================

/system script remove [find name=ocean-report]
/system script add name=ocean-report source={
  :local logname "ocean-sessions.txt"
  :local date [/system clock get date]
  :local time [/system clock get time]

  :put "=== OCEAN MODE — REPORT ==="
  :put ("Generated: " . $date . " " . $time)

  # Show drop-rule state
  :local dropState [/ip firewall filter get [find comment="ocean: drop WAN"] disabled]
  :if ($dropState = false) do={ :put "Status:    ENABLED (drop rule active)" } else={ :put "Status:    DISABLED (Ocean OFF)" }

  :if ([:len [/file find name=$logname]] = 0) do={
    :put "Log:       not found (no sessions recorded yet)"
  } else={
    :put "--- sessions (RAM log) ---"
    :put [/file get $logname contents]
  }
  :put "Note: log lives in RAM and is lost on reboot (no flash dir)."
}
