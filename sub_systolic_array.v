// sub_sys.v - Sub-system integrating FIFOs, Data Alignment, and Systolic Array
module sub_sys #(
    parameter int DIN_WIDTH = 8,
    parameter int N = 4,
    parameter int BUS_WIDTH = 2 * DIN_WIDTH * N, // N elements of A + N elements of B
    parameter int FIFO_DEPTH = 16
) (
    input  logic rst_n,
    input  logic sys_clk,        // Domain for Bus Read/Write
    input  logic sr_clk,         // Domain for Systolic Array Operation
    input  logic [7:0] M_minus_one, // Matrix dimension M-1
    
    // Input Interface (sys_clk)
    input  logic [BUS_WIDTH-1:0] din,
    input  logic wr_fifo,
    output logic in_fifo_full,
    
    // Output Interface (sys_clk)
    input  logic rd_fifo,
    output logic [BUS_WIDTH-1:0] dout,
    output logic out_fifo_empty
);

    // ---------------------------------------------------------
    // 1. Input FIFO Logic
    // ---------------------------------------------------------
    // Note: For a real design, use an Asynchronous FIFO for CDC.
    // This simplified version assumes pointers are synchronized or 
    // the clock ratio is handled by the testbench.
    logic [BUS_WIDTH-1:0] in_fifo_mem [FIFO_DEPTH];
    logic [$clog2(FIFO_DEPTH)-1:0] in_wr_ptr, in_rd_ptr_sr;
    
    // Write Logic (sys_clk)
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) in_wr_ptr <= 0;
        else if (wr_fifo && !in_fifo_full) begin
            in_fifo_mem[in_wr_ptr] <= din;
            in_wr_ptr <= in_wr_ptr + 1;
        end
    end
    assign in_fifo_full = (in_wr_ptr + 1'b1 == in_rd_ptr_sr);

    // ---------------------------------------------------------
    // 2. Data Extraction & Alignment Unit (sr_clk)
    // ---------------------------------------------------------
    logic signed [DIN_WIDTH-1:0] a_raw [N];
    logic signed [DIN_WIDTH-1:0] b_raw [N];
    logic signed [DIN_WIDTH-1:0] a_skewed [N];
    logic signed [DIN_WIDTH-1:0] b_skewed [N];
    logic in_valid_sr;

    // Data Extraction from FIFO
    always_ff @(posedge sr_clk or negedge rst_n) begin
        if (!rst_n) begin
            in_rd_ptr_sr <= 0;
            in_valid_sr <= 0;
        end else if (in_wr_ptr != in_rd_ptr_sr) begin
            for (int i=0; i<N; i++) begin
                a_raw[i] <= in_fifo_mem[in_rd_ptr_sr][i*DIN_WIDTH +: DIN_WIDTH];
                b_raw[i] <= in_fifo_mem[in_rd_ptr_sr][(N+i)*DIN_WIDTH +: DIN_WIDTH];
            end
            in_rd_ptr_sr <= in_rd_ptr_sr + 1;
            in_valid_sr <= 1;
        end else begin
            in_valid_sr <= 0;
        end
    end

    // Data Alignment Unit (Skewing Logic)
    // Row i of A must be delayed by i cycles.
    // Column j of B must be delayed by j cycles.
    genvar k;
    generate
        for (k = 0; k < N; k++) begin : skew_logic
            if (k == 0) begin
                assign a_skewed[0] = a_raw[0];
                assign b_skewed[0] = b_raw[0];
            end else begin
                logic [DIN_WIDTH-1:0] a_delay_pipe [k];
                logic [DIN_WIDTH-1:0] b_delay_pipe [k];
                
                always_ff @(posedge sr_clk) begin
                    a_delay_pipe[0] <= a_raw[k];
                    b_delay_pipe[0] <= b_raw[k];
                    for (int j = 1; j < k; j++) begin
                        a_delay_pipe[j] <= a_delay_pipe[j-1];
                        b_delay_pipe[j] <= b_delay_pipe[j-1];
                    end
                end
                assign a_skewed[k] = a_delay_pipe[k-1];
                assign b_skewed[k] = b_delay_pipe[k-1];
            end
        end
    endgenerate

    // ---------------------------------------------------------
    // 3. Systolic Array Instance
    // ---------------------------------------------------------
    logic signed [2*DIN_WIDTH-1:0] sa_c_out [N];
    logic sa_out_valid;

    systolic_array #(
        .DIN_WIDTH(DIN_WIDTH),
        .N(N)
    ) u_sa (
        .clk(sr_clk),
        .rst_n(rst_n),
        .c_din('{default:'0}), // No previous partial sums
        .a_din(a_skewed),
        .b_din(b_skewed),
        .in_valid(in_valid_sr),
        .c_dout(sa_c_out),
        .out_valid(sa_out_valid)
    );

    // ---------------------------------------------------------
    // 4. Output Collection & De-skewing (sr_clk)
    // ---------------------------------------------------------
    // Systolic outputs are also skewed. To write a balanced row to the FIFO,
    // we must delay the earlier outputs so they align with the last one.
    logic signed [2*DIN_WIDTH-1:0] c_deskewed [N];
    
    generate
        for (k = 0; k < N; k++) begin : deskew_logic
            // Column k is ready at different times; delay Column k by (N-1-k)
            if (k == N-1) begin
                assign c_deskewed[k] = sa_c_out[k];
            end else begin
                logic [2*DIN_WIDTH-1:0] c_delay_pipe [N-1-k];
                always_ff @(posedge sr_clk) begin
                    c_delay_pipe[0] <= sa_c_out[k];
                    for (int j = 1; j < (N-1-k); j++) begin
                        c_delay_pipe[j] <= c_delay_pipe[j-1];
                    end
                end
                assign c_deskewed[k] = c_delay_pipe[N-1-k-1];
            end
        end
    endgenerate

    // ---------------------------------------------------------
    // 5. Output FIFO Logic (sr_clk to sys_clk)
    // ---------------------------------------------------------
    logic [BUS_WIDTH-1:0] out_fifo_mem [FIFO_DEPTH];
    logic [$clog2(FIFO_DEPTH)-1:0] out_wr_ptr_sr, out_rd_ptr;
    
    // Write C results to Output FIFO (sr_clk)
    always_ff @(posedge sr_clk or negedge rst_n) begin
        if (!rst_n) out_wr_ptr_sr <= 0;
        else if (sa_out_valid) begin // Simplified valid logic
            for (int i=0; i<N; i++) begin
                out_fifo_mem[out_wr_ptr_sr][i*2*DIN_WIDTH +: 2*DIN_WIDTH] <= c_deskewed[i];
            end
            out_wr_ptr_sr <= out_wr_ptr_sr + 1;
        end
    end

    // Read Logic (sys_clk)
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            out_rd_ptr <= 0;
            dout <= '0;
        end else if (rd_fifo && !out_fifo_empty) begin
            dout <= out_fifo_mem[out_rd_ptr];
            out_rd_ptr <= out_rd_ptr + 1;
        end
    end
    assign out_fifo_empty = (out_rd_ptr == out_wr_ptr_sr);

endmodule