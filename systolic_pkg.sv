// developed by: Yuwei Chen
// date: 2025-10-29
// description: This package defines common types and parameters for the systolic array design.


package systolic_pkg;

    import uvm_pkg::*;

    `include "uvm_macros.svh"
    `include "systolic_seq_item.sv"
    `include "systolic_cfg.sv"
    `include "systolic_sequence.sv"
    `include "systolic_sequencer.sv"
    `include "systolic_driver.sv"
    `include "systolic_monitor.sv"
    `include "systolic_scoreboard.sv"
    `include "systolic_agent.sv"
    `include "systolic_env.sv"

endpackage : systolic_pkg