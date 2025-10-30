module systolic_array #(
    parameter int DIN_WIDTH = 8,
    parameter int N = 4
)(
    input  logic clk,
    input  logic rst_n, // active low
    input  logic [DIN_WIDTH-1:0] a_din [N], // Row input
    input  logic [DIN_WIDTH-1:0] b_din [N], // Col input
    input  logic in_valid,
    output logic [2*DIN_WIDTH-1:0] c_out, // Serialized output
    output logic out_valid,
    output logic [$clog2(N)-1:0] out_idx // Row index
);

    // Pipeline registers for partial products and accumulations
    logic [DIN_WIDTH-1:0] a_pipe [N];
    logic [DIN_WIDTH-1:0] b_pipe [N];
    logic [2*DIN_WIDTH-1:0] acc_pipe [N];

    logic [$clog2(N)-1:0] row_counter;
    logic [2:0] state; // 0: idle, 1: accumulate, 2: output

    // Input register stage
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_pipe <= '{default:'0};
            b_pipe <= '{default:'0};
            acc_pipe <= '{default:'0};
            row_counter <= '0;
            state <= 0;
            out_valid <= 0;
            c_out <= '0;
            out_idx <= '0;
        end else begin
            case (state)
                0: begin // idle
                    out_valid <= 0;
                    if (in_valid) begin
                        for (int i=0; i<N; i++) begin
                            a_pipe[i] <= a_din[i];
                            b_pipe[i] <= b_din[i];
                        end
                        acc_pipe <= '{default:'0};
                        row_counter <= 0;
                        state <= 1; // move to accumulate
                    end
                end
                1: begin // accumulate matrix product
                    for (int i=0; i<N; i++) begin
                        acc_pipe[i] <= acc_pipe[i] + a_pipe[i] * b_pipe[row_counter];
                    end
                    if (row_counter == N-1) state <= 2;
                    else row_counter <= row_counter + 1;
                end
                2: begin // output products serially
                    out_valid <= 1;
                    c_out <= acc_pipe[out_idx];
                    out_idx <= out_idx + 1;
                    if (out_idx == N-1) begin
                        state <= 0;
                        out_idx <= 0;
                        out_valid <= 0;
                    end
                end
            endcase
        end
    end
endmodule
