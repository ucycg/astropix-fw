#!/usr/bin/tclsh
source flow.tcl

#
# Create bitfiles
#

# Add to list to set special defines
# CLOCK_SE_DIFF # if single-ended sampleclock output should be used
# CLOCK_SE_SE # if LVDS Receiver is not asembled on carrier pcb, remember to connect IN+ with Out
# CONFIG_SE # if GECCO Board has no lvds receivers for SR config
# TELESCOPE # if telescope setup is used

#           board name	       Version    Defines                   constraints file
run_bit     astropix-nexys     3          {}                        $firmware_dir/constraints/constraints.tcl
#run_bit     astropix-nexys     2          {}                        $firmware_dir/constraints/constraints.tcl
#run_bit     astropix-nexys     3          {CONFIG_SE}               $firmware_dir/constraints/constraints.tcl
#run_bit     astropix-nexys     2          {CONFIG_SE}               $firmware_dir/constraints/constraints.tcl
#run_bit     astropix-nexys     3          {TELESCOPE}               $firmware_dir/constraints/constraints.tcl
#run_bit     astropix-nexys     2          {TELESCOPE}               $firmware_dir/constraints/constraints.tcl
exit