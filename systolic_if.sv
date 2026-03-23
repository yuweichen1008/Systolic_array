// systolic_if.sv - Interface with integrated SVA for protocol checking
interface systolic_if #(
    parameter int DIN_WIDTH = 8, 
    parameter int N = 4
)(
    input logic clk
);
    // Control Signals
    logic rst_n; // Active low reset [cite: 225, 232]
    logic in_valid; // High when input A/B data is ready [cite: 228, 236]
    logic out_valid; // High when output C data is ready [cite: 231, 239]

    // Data Signals - All defined as signed logic 
    logic signed [DIN_WIDTH-1:0]   a [0:N-1]; // Row inputs [cite: 228, 236]
    logic signed [DIN_WIDTH-1:0]   b [0:N-1]; // Column/Weight inputs [cite: 228, 236]
    logic signed [2*DIN_WIDTH-1:0] c_dout [0:N-1]; // Result outputs [cite: 230, 237]

    // ---------------------------------------------------------
    // SystemVerilog Assertions (SVA)
    // ---------------------------------------------------------

    // 1. Reset Integrity: Valid signals must be deasserted during reset
    property p_reset_active;
        @(posedge clk) !rst_n |-> (!in_valid && !out_valid);
    endproperty
    assert_reset_active: assert property (p_reset_active) 
        else $error("[SVA] Protocol Violation: Valid signal high during reset!");

    // 2. Data Stability: Inputs must not be 'X' when in_valid is high
    property p_in_data_stable;
        @(posedge clk) disable iff (!rst_n)
        in_valid |-> !($isunknown(a)) && !($isunknown(b));
    endproperty
    assert_in_data_stable: assert property (p_in_data_stable) 
        else $error("[SVA] Protocol Violation: Unknown (X) data detected on inputs when in_valid is high!");

    // 3. Response Check: out_valid must eventually toggle after in_valid
    // Expected latency is roughly 3N cycles; using 5N as a safe timeout 
    property p_output_exists;
        @(posedge clk) disable iff (!rst_n)
        in_valid |=> ##[1:5*N] out_valid;
    endproperty
    assert_output_exists: assert property (p_output_exists) 
        else $error("[SVA] Performance Violation: DUT failed to provide out_valid within the expected window!");

endinterface