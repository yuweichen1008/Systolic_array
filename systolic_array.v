// systolic_array.v
module systolic_array #(
    parameter int DIN_WIDTH = 8,
    parameter int N = 4
)(
    input  logic                          clk,
    input  logic                          rst_n,    // active low
    input  logic signed [DIN_WIDTH-1:0]   a_din [N], // A input stream (N elements at once)
    input  logic signed [DIN_WIDTH-1:0]   b_din [N], // B input stream (N elements at once)
    input  logic                          in_valid,  // pulse each injection cycle
    output logic signed [2*DIN_WIDTH-1:0] c_out,     // output matrix value (serialized)
    output logic                          out_valid, // stream valid
    output logic [$clog2(N)-1:0]          out_idx    // row index for c_out multiplexing
);

    // Internal data busses: all arrays are [row][col], zero-based from [0][0]
    logic signed [DIN_WIDTH-1:0]   a_wire [N][N];
    logic signed [DIN_WIDTH-1:0]   b_wire [N][N];
    logic signed [2*DIN_WIDTH-1:0] c_wire [N][N];

    genvar i, j;
    generate
        for (i = 0; i < N; i++) begin : ROWS
            for (j = 0; j < N; j++) begin : COLS
                // Local wires for input to this PE
                logic signed [DIN_WIDTH-1:0] a_in, b_in;
                logic signed [2*DIN_WIDTH-1:0] c_in;

                // Multiplex: leftmost column gets external a_din, else shift from left
                assign a_in = (j == 0) ? a_din[i]    : a_wire[i][j-1];
                // Top row gets external b_din, else downward shift from above
                assign b_in = (i == 0) ? b_din[j]    : b_wire[i-1][j];
                // First column col 0 gets zero partial sum; rest shift c from left
                assign c_in = (j == 0) ? '0          : c_wire[i][j-1];

                pe #(.DW(DIN_WIDTH)) u_pe (
                    .clk    (clk),
                    .rst_n  (rst_n),
                    .a_in   (a_in),
                    .b_in   (b_in),
                    .c_in   (c_in),
                    .a_out  (a_wire[i][j]),      // right, for next col
                    .b_out  (b_wire[i][j]),      // down,  for next row
                    .c_out  (c_wire[i][j])       // right, for next col
                );
            end
        end
    endgenerate

    // Output serialization: return c_wire[row][N-1] for row=0..N-1 over N cycles
    // Standard state machine for streaming output after latency
    typedef enum logic [1:0] {IDLE, INJECT, WAIT_LAT, OUTPUT} state_t;
    state_t state, next_state;

    logic [$clog2(N)-1:0] out_counter;    // output row index
    int injected_count;                   // input injection count
    int latency_cnt;                      // latency counter

    // Synchronous state machine and output logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= IDLE;
            injected_count   <= 0;
            latency_cnt      <= 0;
            out_counter      <= 0;
            out_valid        <= 0;
            c_out            <= '0;
            out_idx          <= '0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    out_valid      <= 0;
                    if (in_valid)  injected_count <= 1;
                    else           injected_count <= 0;
                    latency_cnt    <= 0;
                    out_counter    <= 0;
                end
                INJECT: begin
                    if (in_valid && (injected_count < N))
                        injected_count <= injected_count + 1;
                end
                WAIT_LAT: begin
                    latency_cnt    <= latency_cnt + 1;
                    out_valid      <= 0;
                end
                OUTPUT: begin
                    out_valid      <= 1;
                    c_out          <= c_wire[out_counter][N-1];
                    out_idx        <= out_counter;
                    if (out_counter == N-1)
                        out_counter <= 0;
                    else
                        out_counter <= out_counter + 1;
                end
            endcase
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE:    if (in_valid) next_state = INJECT;
            INJECT:  if ((injected_count + (in_valid ? 1 : 0)) >= N) next_state = WAIT_LAT;
                     else if (!in_valid) next_state = IDLE;
            WAIT_LAT:if (latency_cnt + 1 >= N) next_state = OUTPUT;
            OUTPUT:  if (out_counter + 1 >= N) next_state = IDLE;
        endcase
    end

endmodule

// Processing Element (PE)
module pe #(
    parameter int DW = 8
) (
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic signed [DW-1:0]        a_in,
    input  logic signed [DW-1:0]        b_in,
    input  logic signed [2*DW-1:0]      c_in,
    output logic signed [DW-1:0]        a_out,
    output logic signed [DW-1:0]        b_out,
    output logic signed [2*DW-1:0]      c_out
);
    logic signed [DW-1:0] a_r, b_r;
    logic signed [2*DW-1:0] c_r;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_r <= '0;
            b_r <= '0;
            c_r <= '0;
        end else begin
            c_r <= c_in + a_r * b_r;
            a_r <= a_in;
            b_r <= b_in;
        end
    end
    assign a_out = a_r;
    assign b_out = b_r;
    assign c_out = c_r;
endmodule
