module sub_sys #(
    parameter int DIN_WIDTH = 8,
    parameter int N = 4,
    parameter int BUS_WIDTH = 2*DIN_WIDTH*N,
    parameter int FIFO_DEPTH = 16
) (
    input  logic rst_n,
    input  logic sys_clk,        // Data read and write
    input  logic sr_clk,         // Systolic Array and controller
    input  logic [7:0] M_minus_one, // Unused: can be extended for NxM/MxN
    input  logic [BUS_WIDTH-1:0] din,         // Input FIFO data (N A + N B packed)
    input  logic wr_fifo,        // Write input FIFO (sys_clk)
    input  logic rd_fifo,        // Read output FIFO (sys_clk)
    output logic in_fifo_full,   // Input FIFO status
    output logic [BUS_WIDTH-1:0] dout,        // Output FIFO (N C packed)
    output logic out_fifo_empty  // Output FIFO status
);

    // -------------------------------------------
    // Input FIFO (sys_clk domain)
    logic [BUS_WIDTH-1:0] in_fifo [FIFO_DEPTH];
    logic [$clog2(FIFO_DEPTH)-1:0] in_wr_ptr, in_rd_ptr;
    logic in_fifo_empty;
    assign in_fifo_full  = (in_wr_ptr + 1 == in_rd_ptr);
    assign in_fifo_empty = (in_wr_ptr == in_rd_ptr);

    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            in_wr_ptr <= 0;
        end else begin
            if (wr_fifo && !in_fifo_full) begin
                in_fifo[in_wr_ptr] <= din;
                in_wr_ptr <= in_wr_ptr + 1;
            end
        end
    end

    // -------------------------------------------
    // Output FIFO (sr_clk write, sys_clk read domain)
    logic [BUS_WIDTH-1:0] out_fifo [FIFO_DEPTH];
    logic [$clog2(FIFO_DEPTH)-1:0] out_wr_ptr;    // sr_clk domain
    logic [$clog2(FIFO_DEPTH)-1:0] out_rd_ptr;    // sys_clk domain

    assign out_fifo_empty = (out_wr_ptr == out_rd_ptr);

    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            out_rd_ptr <= 0;
            dout <= '0;
        end else begin
            if (rd_fifo && !(out_wr_ptr == out_rd_ptr)) begin
                dout <= out_fifo[out_rd_ptr];
                out_rd_ptr <= out_rd_ptr + 1;
            end
        end
    end

    // -------------------------------------------
    // Data extraction for systolic array input (sr_clk domain)
    logic inject_enable;
    logic signed [DIN_WIDTH-1:0] a_vec [N];
    logic signed [DIN_WIDTH-1:0] b_vec [N];
    logic in_valid_sr_clk;

    always_ff @(posedge sr_clk or negedge rst_n) begin
        if (!rst_n) begin
            in_rd_ptr <= 0;
            inject_enable <= 0;
        end else begin
            inject_enable <= !in_fifo_empty && (in_rd_ptr != in_wr_ptr); // valid data available
            if (inject_enable) begin
                for (int i=0; i<N; i++) begin
                    a_vec[i] <= in_fifo[in_rd_ptr][i*DIN_WIDTH +: DIN_WIDTH];
                    b_vec[i] <= in_fifo[in_rd_ptr][(N+i)*DIN_WIDTH +: DIN_WIDTH];
                end
                in_rd_ptr <= in_rd_ptr + 1;
                in_valid_sr_clk <= 1;
            end else begin
                in_valid_sr_clk <= 0;
            end
        end
    end

    // -------------------------------------------
    // Systolic array instance (sr_clk domain)
    logic signed [2*DIN_WIDTH-1:0] c_out;
    logic out_valid;
    logic [$clog2(N)-1:0] out_idx;

    systolic_array #(.DIN_WIDTH(DIN_WIDTH), .N(N)) u_sa (
        .clk(sr_clk),
        .rst_n(rst_n),
        .a_din(a_vec),
        .b_din(b_vec),
        .in_valid(in_valid_sr_clk),
        .c_out(c_out),
        .out_valid(out_valid),
        .out_idx(out_idx)
    );

    // -------------------------------------------
    // Write C results to output FIFO in sr_clk domain
    always_ff @(posedge sr_clk or negedge rst_n) begin
        if (!rst_n) begin
            out_wr_ptr <= 0;
        end else if (out_valid && ((out_wr_ptr + 1) != out_rd_ptr)) begin
            out_fifo[out_wr_ptr][out_idx*2*DIN_WIDTH +: 2*DIN_WIDTH] <= c_out;
            if (out_idx == N-1)
                out_wr_ptr <= out_wr_ptr + 1;
        end
    end

endmodule