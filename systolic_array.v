// systolic_array.v 
module systolic_array #(
    parameter int DIN_WIDTH = 8,
    parameter int N = 4
)(
    input  logic rst_n,
    input  logic clk,
    input  logic signed [2*DIN_WIDTH-1:0] c_din  [0:N-1],
    input  logic signed [DIN_WIDTH-1:0]   a_din  [0:N-1],
    input  logic signed [DIN_WIDTH-1:0]   b_din  [0:N-1],
    input  logic in_valid,
    output logic signed [2*DIN_WIDTH-1:0] c_dout [0:N-1],
    output logic out_valid
);

    // ---------------------------------------------------------
    // Internal Signal
    // ---------------------------------------------------------
    logic signed [DIN_WIDTH-1:0]   a_pipe [0:N-1][0:N];
    logic signed [DIN_WIDTH-1:0]   b_pipe [0:N][0:N-1];
    logic signed [2*DIN_WIDTH-1:0] c_pipe [0:N][0:N-1];

    logic load_b;
    logic swap_b;
    logic [7:0] cycle_count;

    // ---------------------------------------------------------
    // Boundary Input Connections
    // ---------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : boundary_connections
            assign a_pipe[i][0] = a_din[i];      // input from left (A)
            assign b_pipe[0][i] = b_din[i];      // input from top (B)
            assign c_pipe[0][i] = c_din[i];      // input from top (C)
            assign c_dout[i]    = c_pipe[N][i];  // output to bottom (C)
        end
    endgenerate

    // ---------------------------------------------------------
    // PE Array (NxN Mesh)
    // ---------------------------------------------------------
    genvar r, c;
    generate
        for (r = 0; r < N; r++) begin : rows
            for (c = 0; c < N; c++) begin : cols
                // Processing Element (PE)
                pe #(
                    .DIN_WIDTH(DIN_WIDTH)
                ) u_pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .load_en(in_valid),          // Simplified: Controlled by in_valid
                    .a_in(a_pipe[r][c]),
                    .b_in(b_pipe[r][c]),
                    .c_in(c_pipe[r][c]),
                    .a_out(a_pipe[r][c+1]),      // Forwarded to the right
                    .b_out(b_pipe[r+1][c]),      // Forwarded down
                    .c_out(c_pipe[r+1][c])       // Forwarded down
                );
            end
        end
    endgenerate

    // ---------------------------------------------------------
    // Output Control Logic (Latency Counting)
    // ---------------------------------------------------------
    // In a 2x2 array, the first C should appear in the 6th cycle [cite: 222]
    // General formula: Output latency is usually related to N
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
            out_valid   <= 0;
        end else if (in_valid || cycle_count > 0) begin
            if (cycle_count == (3*N - 2)) begin // Pipeline delay adjusted for N
                out_valid   <= 1;
                cycle_count <= 0;
            end else begin
                cycle_count <= cycle_count + 1;
                out_valid   <= 0;
            end
        end
    end

endmodule

// ---------------------------------------------------------
// Processing Element (PE)
// ---------------------------------------------------------
module pe #(
    parameter int DIN_WIDTH = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic load_en,                        // enable signal for loading new weights (b)
    input  logic signed [DIN_WIDTH-1:0] a_in,    // Activation 
    input  logic signed [DIN_WIDTH-1:0] b_in,    // Weight 
    input  logic signed [2*DIN_WIDTH-1:0] c_in,  // Partial Sum Input
    output logic signed [DIN_WIDTH-1:0] a_out,   // Forwarded Activation
    output logic signed [DIN_WIDTH-1:0] b_out,   // Forwarded Weight
    output logic signed [2*DIN_WIDTH-1:0] c_out  // Output Partial Sum
);

    logic signed [DIN_WIDTH-1:0] b_active;       // current active weight 
    logic signed [DIN_WIDTH-1:0] b_next;         // next weight to be loaded

    // cout = a * b + cin
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out    <= '0;
            b_out    <= '0;
            c_out    <= '0;
            b_active <= '0;
            b_next   <= '0;
        end else begin
            // Data Flow
            a_out <= a_in;
            b_out <= b_in;
            c_out <= (a_in * b_active) + c_in;

            // Weight Management: This demonstrates a simple switching logic
            if (load_en) begin
                b_next   <= b_in;
                b_active <= b_next; // In actual design, switching points should align with matrix boundaries
            end
        end
    end
endmodule