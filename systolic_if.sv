`timescale 1ns/1ps

interface systolic_if #(
    parameter int DIN_WIDTH = 8,
    parameter int N = 4
)(
    input logic clk,
    input logic rst_n
);
    logic [DIN_WIDTH-1:0] a[0:N-1];
    logic [DIN_WIDTH-1:0] b[0:N-1];
    logic [2*DIN_WIDTH-1:0] c_din; //  The partial_sum input data of first row PEs
    logic [2*DIN_WIDTH-1:0] c_dout[N-1:0];
    logic in_valid;
    logic out_valid;

    modport driver (
    input in_valid,
    output out_valid,
    output a,
    output b
    );
    
    modport monitor (
    input in_valid,
    input out_valid,
    input a,
    input b
    );
    
endinterface