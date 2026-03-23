/******************************************************************************
* File: testbench.sv
* Developed by: Yu-Wei Chen 
* Description: Top-level testbench for UVM verification of the Systolic Array.
* Connects the signed interface to the parallel-output DUT.
*******************************************************************************/

`timescale 1ns/1ps
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

    // Simulation Clock and Reset
    bit clk;
    bit rst_n;

    // Local wires for the top-level partial sum input (D in C = A*B + D)
    // For basic matrix multiplication, this is tied to 0.
    logic signed [2*8-1:0] top_c_din [0:3];

    // 1. Instantiate the Physical Interface
    // Parameters match DIN_WIDTH=8, N=4
    systolic_if #(.DIN_WIDTH(8), .N(4)) sif (.clk(clk));

    // 2. Connect Interface Reset
    assign sif.rst_n = rst_n;

    // 3. Instantiate the Design Under Test (DUT)
    // Mapping to the revised parallel systolic_array.v
    systolic_array #(
        .DIN_WIDTH(8), 
        .N(4)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .c_din     (top_c_din),   // Tied to 0 for initial verification
        .a_din     (sif.a),       // Skewed Row inputs from Driver
        .b_din     (sif.b),       // Skewed Column/Weight inputs from Driver
        .in_valid  (sif.in_valid),
        .c_dout    (sif.c_dout),  // Parallel result output
        .out_valid (sif.out_valid)
    );

    // 4. Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // 5. Reset Generation
    initial begin
        rst_n = 0;
        #100 rst_n = 1;
    end

    // 6. Testbench Initialization
    initial begin
        // Initialize partial sum input to zero
        for (int i = 0; i < 4; i++) begin
            top_c_din[i] = '0;
        end

        // Set the virtual interface in the UVM Configuration Database
        // Note: The path "*" allows all UVM components to access this VIF
        uvm_config_db#(virtual systolic_if#(8,4))::set(null, "*", "vif", sif);
        
        // Start the UVM Test
        run_test("first_test");
    end

    // 7. Waveform Dumping
    initial begin
        $dumpfile("systolic_sim.vcd");
        $dumpvars(0, testbench);
        
        // Safety timeout to prevent infinite simulation
        #100000;
        `uvm_fatal("TIMEOUT", "Simulation exceeded maximum time limit")
        $finish;
    end

endmodule