# Outline

This is repository for testing Systolic array UVM testbench

# Files

DUT: 
1. systolic_array.v
2. sub_systolic_array.v


# Testbench

please refer to systolic_pkt.sv

```
    `include "systolic_if.sv"
    `include "systolic_seq_item.sv"
    `include "systolic_cfg.sv"
    `include "systolic_sequence.sv"
    `include "systolic_sequencer.sv"
    `include "systolic_driver.sv"
    `include "systolic_monitor.sv"
    `include "systolic_scoreboard.sv"
    `include "systolic_agent.sv"
    `include "systolic_env.sv"
```

# EDAplayground


# Revision
| 0.1  | Initial push, add systolic uvm to repo     |       
| 0.2  | Connect systolic_array dut with testbench  |       
| 0.3  | Remove checker for no DUT                  |       
