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

    bit sr_clk;
    bit rst_n;
    bit [7:0] M_minus_one;


    // Instantiate the actual interface (not virtual) and connect clock/reset
    systolic_if#(.DIN_WIDTH(8), .N(4)) sif (
        .clk(sr_clk),
        .rst_n(rst_n)
    );

    systolic_array #(.DIN_WIDTH(8), .N(4)) dut (
        .clk(sr_clk),
        .rst_n(rst_n),
        .a_din(sif.a),
        .b_din(sif.b),
        .c_out(sif.c_dout),
        .out_idx(sif.c_dout_idx),
        .in_valid(sif.in_valid),
        .out_valid(sif.out_valid)
    );
    // sub_systolic_array #(.DIN_WIDTH(8), .N(4), .BUS_WIDTH(64)) sub_dut (
    //     .clk(sif.clk),
    //     .rst_n(sif.rst_n),
    //     .a_din(sif.a),
    //     .b_din(sif.b),
    //     .c_dout(sif.c_dout),
    //     .out_idx(sif.c_dout_idx),
    //     .in_valid(sif.in_valid),
    //     .out_valid(sif.out_valid)
    // );

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
        uvm_config_db#(virtual systolic_if#(8,4))::set(null, "*", "vif", sif);
        run_test("first_test");
    end
    // Dump waves
    initial begin
        $dumpvars(0, testbench);
        $dumpfile("dump.vcd");
        #5000ns; // adjust time as needed
        $finish;
    end

endmodule
// developed by: Yuwei Chen
// description: This file contains the UVM testbench module for the systolic array design.
// description: This package defines common types and parameters for the systolic array design.