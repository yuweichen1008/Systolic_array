/*******************************************
This is a basic UVM systolic testbench.
*********************************************/

`include "uvm_macros.svh"
`include "systolic_if.sv"
`include "systolic_pkg.sv"
// DUT files
`include "systolic_array.v"
`include "sub_systolic_array.v"
`include "first_test.sv"

module testbench;
    import uvm_pkg::*;
    import systolic_pkg::*;

    systolic_array #(.DIN_WIDTH(8), .N(4)) dut ();
    sub_systolic_array #(.DIN_WIDTH(8), .N(4), .BUS_WIDTH(64)) sub_dut ();
    logic sr_clk;
    logic rst_n;
    // Instantiate the actual interface (not virtual) and connect clock/reset
    systolic_if#(.DIN_WIDTH(8), .N(4)) sif (sr_clk, rst_n);
    // systolic array clock
    initial begin
        sr_clk = 0;
        forever begin
            #10 sr_clk = ~sr_clk;
        end
    end
    // reset
    initial begin
        rst_n = 0;
        #100 rst_n = 1;
    end

    initial begin
        systolic_cfg cfg;
        cfg = systolic_cfg::type_id::create("cfg");
        // default cfg.data_width = 8;
        // default cfg.array_size = 4;
        uvm_config_db#(systolic_cfg)::set(null, "uvm_test_top.*", "cfg", cfg);
        uvm_config_db#(virtual systolic_if#(8,4))::set(null, "*", "vif", sif);
        run_test("first_test");
    end
    // Dump waves
    initial begin
        $dumpvars(0, testbench);
        $dumpfile("dump.vcd");
        // $dumpvars(0, top);
    end

endmodule
// developed by: Yuwei Chen
// description: This file contains the UVM testbench module for the systolic array design.
// description: This package defines common types and parameters for the systolic array design.