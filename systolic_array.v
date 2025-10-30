module systolic_array #(
    parameter DIN_WIDTH = 8,
    parameter N = 4
) (
    input logic rst_n, //active low reset
    input logic clk, //clock
    input logic [2*DIN_WIDTH-1:0] c_din[0:N-1], // The partial_sum input data of first row PEs. On top level, it can be connected to c_dout of last row PEs systolic_array
    // With appropriate control logic for the loop back and propagate in each PEs of Systolic array. The Design can support
    // the matrix multiplications for NxM and MxN matrix, This signal need be reset to be 0 when start the new matrix data
    input logic [DIN_WIDTH-1:0] a_din[0:N-1], // N elements data of A matrix （column number）, assuming each element is DIN_WIDTH bits Signed data
    input logic [DIN_WIDTH-1:0] b_din[0:N-1], // N elements data of B matrix（row number）, assuming each element is DIN_WIDTH bits Signed data
    input logic in_valid, // Toggle to be high to indicates last elements data of A matrix and B matrix are ready (each M clock cycle
    // depend on the M of input matrix)
    output logic [2*DIN_WIDTH-1:0] c_dout[N-1:0], // N (number of column of PEs mesh) Elements data of output C matrix, each element is 2*DIN_WIDTH bits
    // Signed data, Default output is zero when data are not ready
    output logic out_valid // Toggle to be high to indicates last elements data of C matrix output data are ready (each M clock cycle
    // depend on the M of input matrix)
);

    // Internal signals for PE array
    logic [DIN_WIDTH-1:0] a_data[0:N-1][0:N-1]; // A matrix data flowing down
    logic [DIN_WIDTH-1:0] b_data[0:N-1][0:N-1]; // B matrix data flowing right
    logic [2*DIN_WIDTH-1:0] c_data[0:N-1][0:N-1]; // C matrix data (partial sums)
    
    // Control signals
    logic [N-1:0] pe_valid[0:N-1]; // Valid signals for each PE
    logic [N-1:0] pe_out_valid[0:N-1]; // Output valid signals for each PE
    
    // Counter for tracking computation cycles
    logic [7:0] cycle_count;
    logic [7:0] matrix_count;
    logic computation_active;
    
    // Initialize outputs
    always_comb begin
        for (int i = 0; i < N; i++) begin
            c_dout[i] = c_data[N-1][i];
        end
        out_valid = pe_out_valid[N-1][N-1];
    end
    
    // Control logic for consecutive matrix multiplications
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
            matrix_count <= 0;
            computation_active <= 0;
        end else begin
            if (in_valid) begin
                computation_active <= 1;
                cycle_count <= 0;
                matrix_count <= matrix_count + 1;
            end else if (computation_active) begin
                cycle_count <= cycle_count + 1;
                // Reset for next matrix after M cycles (assuming M=2 for 2x2 example)
                if (cycle_count == 1) begin // M-1 cycles for computation
                    computation_active <= 0;
                end
            end
        end
    end
    
    // Generate NxN PE array
    genvar i, j;
    generate
        for (i = 0; i < N; i++) begin : gen_row
            for (j = 0; j < N; j++) begin : gen_col
                // Processing Element (PE) instantiation
                pe_unit #(
                    .DIN_WIDTH(DIN_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .a_in(i == 0 ? a_din[j] : a_data[i-1][j]),
                    .b_in(j == 0 ? b_din[i] : b_data[i][j-1]),
                    .c_in(i == 0 ? c_din[j] : c_data[i-1][j]),
                    .a_out(a_data[i][j]),
                    .b_out(b_data[i][j]),
                    .c_out(c_data[i][j]),
                    .valid_in(i == 0 && j == 0 ? in_valid : 
                             i == 0 ? pe_valid[i][j-1] : 
                             j == 0 ? pe_valid[i-1][j] : 
                             pe_valid[i-1][j] && pe_valid[i][j-1]),
                    .valid_out(pe_valid[i][j]),
                    .out_valid(pe_out_valid[i][j])
                );
            end
        end
    endgenerate

endmodule

// Processing Element (PE) module
module pe_unit #(
    parameter DIN_WIDTH = 8
) (
    input logic clk,
    input logic rst_n,
    input logic [DIN_WIDTH-1:0] a_in,
    input logic [DIN_WIDTH-1:0] b_in,
    input logic [2*DIN_WIDTH-1:0] c_in,
    output logic [DIN_WIDTH-1:0] a_out,
    output logic [DIN_WIDTH-1:0] b_out,
    output logic [2*DIN_WIDTH-1:0] c_out,
    input logic valid_in,
    output logic valid_out,
    output logic out_valid
);

    // Internal registers
    logic [DIN_WIDTH-1:0] a_reg;
    logic [DIN_WIDTH-1:0] b_reg;
    logic [2*DIN_WIDTH-1:0] c_reg;
    logic valid_reg;
    logic out_valid_reg;
    
    // PE computation: c_out = c_in + a_in * b_in
    logic [2*DIN_WIDTH-1:0] mult_result;
    logic [2*DIN_WIDTH-1:0] add_result;
    
    // Signed multiplication
    assign mult_result = $signed(a_in) * $signed(b_in);
    assign add_result = $signed(c_in) + $signed(mult_result);
    
    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 0;
            b_reg <= 0;
            c_reg <= 0;
            valid_reg <= 0;
            out_valid_reg <= 0;
        end else begin
            if (valid_in) begin
                a_reg <= a_in;
                b_reg <= b_in;
                c_reg <= add_result;
                valid_reg <= 1;
                out_valid_reg <= 1;
            end else begin
                valid_reg <= 0;
                out_valid_reg <= 0;
            end
        end
    end
    
    // Output assignments
    assign a_out = a_reg;
    assign b_out = b_reg;
    assign c_out = c_reg;
    assign valid_out = valid_reg;
    assign out_valid = out_valid_reg;

endmodule