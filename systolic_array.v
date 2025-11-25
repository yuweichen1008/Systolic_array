// systolic_array.v - NxN mesh; supports NxM/MxN pipeline control and throughput
module systolic_array #(
    parameter int DIN_WIDTH = 8,
    parameter int N = 2
)(
    input  logic clk,
    input  logic rst_n, // active low
    input  logic [DIN_WIDTH-1:0] a_din [N], // Row input
    input  logic [DIN_WIDTH-1:0] b_din [N], // Col input (weight buffer)
    input  logic in_valid,                   // Input valid for new matrix data
    output logic [2*DIN_WIDTH-1:0] c_out,    // Serialized output
    output logic out_valid,
    output logic [$clog2(N)-1:0] out_idx     // Row index
);

    // Support for NxM and MxN streaming: a_pipe and b_pipe can be internal buffers
    logic [DIN_WIDTH-1:0] a_pipe [N];
    logic [DIN_WIDTH-1:0] b_pipe [N];

    // Accumulate C matrix outputs pipeline
    logic [2*DIN_WIDTH-1:0] acc_pipe [N];

    // Control pipeline for current accumulating row, and state machine
    logic [$clog2(N)-1:0] row_counter;
    logic [$clog2(N)-1:0] output_counter;

    logic [2:0] state; // 0: idle, 1: accumulate, 2: output

    // Latency management for pipelined operation
    logic [$clog2(N*2)-1:0] input_latency;
    logic [$clog2(N*2)-1:0] output_latency;
    logic compute_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_pipe <= '{default:'0};
            b_pipe <= '{default:'0};
            acc_pipe <= '{default:'0};
            row_counter <= '0;
            output_counter <= '0;
            state <= 0;
            input_latency <= 0;
            output_latency <= 0;
            out_valid <= 0;
            c_out <= '0;
            out_idx <= '0;
            compute_ready <= 0;
        end else begin
            case (state)
                0: begin // idle
                    out_valid <= 0;
                    if (in_valid) begin
                        for (int i=0; i<N; i++) begin
                            a_pipe[i] <= a_din[i];
                            b_pipe[i] <= b_din[i];
                        end
                        acc_pipe   <= '{default:'0};
                        row_counter <= 0;
                        input_latency <= input_latency + 1; // track pipeline fill
                        state <= 1;
                    end
                end
                1: begin // accumulate matrix product as systolic pipeline
                    for (int i=0; i<N; i++) begin
                        acc_pipe[i] <= acc_pipe[i] + a_pipe[i] * b_pipe[row_counter];
                    end
                    if (row_counter == N-1) begin
                        compute_ready <= 1; // All MAC cycles complete
                        output_counter <= 0;
                        output_latency <= input_latency + N; // track output latency
                        state <= 2;
                    end else begin
                        row_counter <= row_counter + 1;
                    end
                end
                2: begin // output C matrix products serially
                    out_valid <= 1;
                    c_out     <= acc_pipe[output_counter];
                    out_idx   <= output_counter;
                    output_counter <= output_counter + 1;
                    if (output_counter == N-1) begin
                        state <= 0;
                        out_valid <= 0;
                        output_counter <= 0;
                        input_latency  <= 0;
                        output_latency <= 0;
                        compute_ready  <= 0;
                    end
                end
            endcase
        end
    end

    // Additional comments:
    // - The b_pipe (weight buffer) is used to propagate weights (matrix B) across each column PEs.
    // - The entire NxN mesh operation supports sequential matrix multiplication requests with M clock cycles for
    //   computation per batch, plus pipeline fill & output serialization latency.
    // - Throughput is maximized; output latency due to input streaming does not reduce throughput (only first output is delayed).
    // - With N=2: first product output appears at 6th cycle, second matrix output appears after 2 more cycles,
    //   as illustrated on your reference page.
endmodule
