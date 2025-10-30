`timescale 1ns/1ps

interface systolic_if #(
    parameter int DIN_WIDTH = 8,
    parameter int N = 4
)(
    input bit clk,
    input bit rst_n
);
    logic signed [DIN_WIDTH-1:0] a[0:N-1];
    logic signed [DIN_WIDTH-1:0] b[0:N-1];
    logic signed [2*DIN_WIDTH-1:0] c_dout;
    logic [$clog2(N)-1:0]   c_dout_idx; // The output index of c_dout
    logic in_valid;
    logic out_valid;

    modport driver (
        output in_valid,
        output a,
        output b
    );
    
    modport monitor (
        input in_valid,
        input out_valid,
        input a,
        input b,
        input c_dout,
        input c_dout_idx
    );
    
endinterface