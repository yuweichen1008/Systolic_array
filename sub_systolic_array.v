
module sub_systolic_array #(
    parameter DIN_WIDTH = 8,
    parameter N = 4,
    parameter BUS_WIDTH = 2*DIN_WIDTH*N
) (
    input logic rst_n, //active low reset
    input logic sys_clk, //sys_clk is used for Data read and write
    input logic sr_clk, // sr_clk is used for the operation of Systolic Array and controller logic
    input logic[7:0] M_minus_one, // Set this signal value to be "M-1" to indicates the NxM and MxN matrix multiplications
    input logic [BUS_WIDTH-1:0] din, // Input data for input FIFO. Each sample include N elements of Matrix A(one column) and N elements of matrix B(one row)
    // bits width of each matrix's element is DIN_WIDTH,
    input logic wr_fifo, // Write input FIFO signal, active high
    input logic rd_fifo, // Read output FIFO signal, active high
    output logic in_fifo_full, // Input data FIFO is full (active high)
    output logic [BUS_WIDTH-1:0] dout, // Read data of output FIFO, including N elements (number of column) of Matrix C output
    output logic out_fifo_empty // Output FIFO is empty, active high
);

endmodule 