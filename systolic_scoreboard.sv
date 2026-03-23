`ifndef SYSTOLIC_SCOREBOARD_SV
`define SYSTOLIC_SCOREBOARD_SV

// Coverage item updated to handle signed values and meaningful ranges
class coverage_item#(parameter int DIN_WIDTH = 8) extends uvm_object;
  `uvm_object_utils(coverage_item)

  // Use logic signed to correctly represent the 2's complement range
  logic signed [DIN_WIDTH-1:0] a;
  logic signed [DIN_WIDTH-1:0] b;

  function new(string name = "coverage_item");
    super.new(name);
    cg = new();
  endfunction

  // Covergroup focused on signed arithmetic corner cases
  covergroup cg;
    option.per_instance = 1;
    
    // Check if we hit negative, zero, and positive ranges
    cp_a: coverpoint a {
      bins neg      = { [-(2**(DIN_WIDTH-1)) : -1] };
      bins zero     = { 0 };
      bins pos      = { [1 : (2**(DIN_WIDTH-1)-1)] };
      bins max_neg  = { -(2**(DIN_WIDTH-1)) };
      bins max_pos  = { (2**(DIN_WIDTH-1)-1) };
    }
    cp_b: coverpoint b {
      bins neg      = { [-(2**(DIN_WIDTH-1)) : -1] };
      bins zero     = { 0 };
      bins pos      = { [1 : (2**(DIN_WIDTH-1)-1)] };
      bins max_neg  = { -(2**(DIN_WIDTH-1)) };
      bins max_pos  = { (2**(DIN_WIDTH-1)-1) };
    }
    // Ensure we test combinations like Neg x Neg = Pos
    cross_ab: cross cp_a, cp_b;
  endgroup

  function void sample();
    cg.sample();
  endfunction
endclass : coverage_item

class systolic_scoreboard#(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_component;

  `uvm_component_param_utils(systolic_scoreboard#(DIN_WIDTH, N))

  // Analysis port to receive transactions from the Monitor
  uvm_analysis_imp#(systolic_seq_item#(DIN_WIDTH, N), systolic_scoreboard#(DIN_WIDTH, N)) analysis_export;
  
  coverage_item#(DIN_WIDTH) cov_item;

  // Internal buffers for the Golden Model
  logic signed [DIN_WIDTH-1:0] local_matrix_a [N][N];
  logic signed [DIN_WIDTH-1:0] local_matrix_b [N][N];
  
  // Queue to store expected matrix results for pipelined checking
  typedef logic signed [2*DIN_WIDTH-1:0] matrix_c_t [N][N];
  matrix_c_t expected_q[$];

  int input_row_cnt = 0;
  int error_cnt = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
    cov_item = new();
  endfunction

  // Main verification logic triggered by the monitor
  virtual function void write(systolic_seq_item#(DIN_WIDTH, N) tr);
    // 1. Process Inputs: Store rows until a full NxN matrix is ready
    if (tr.is_input) begin
        for (int i = 0; i < N; i++) begin
            local_matrix_a[input_row_cnt][i] = tr.a[i];
            local_matrix_b[input_row_cnt][i] = tr.b[i];
        end
        
        input_row_cnt++;
        
        // Once full matrix is received, calculate the expected product
        if (input_row_cnt == N) begin
            calculate_golden_matrix();
            input_row_cnt = 0;
        end
        
        // Sample coverage for input values
        sample_input_coverage(tr);
    end

    // 2. Process Outputs: Compare DUT output against the expected queue
    if (tr.is_output && tr.out_valid) begin
        perform_comparison(tr);
    end
  endfunction

  // Reference Model: C = A * B using signed arithmetic
  function void calculate_golden_matrix();
    matrix_c_t res;
    for (int i = 0; i < N; i++) begin
      for (int j = 0; j < N; j++) begin
        res[i][j] = 0;
        for (int k = 0; k < N; k++) begin
          // The "Signed" magic happens here: SystemVerilog preserves the sign
          res[i][j] += local_matrix_a[i][k] * local_matrix_b[k][j];
        end
      end
    end
    expected_q.push_back(res);
    `uvm_info("SCB_GOLDEN", "Matrix multiplication result queued.", UVM_HIGH)
  endfunction

  // Automated result checking logic
  function void perform_comparison(systolic_seq_item#(DIN_WIDTH, N) tr);
    static int output_row_cnt = 0;
    matrix_c_t exp;

    if (expected_q.size() == 0) begin
        `uvm_error("SCB_ERROR", "DUT produced output but no expected result in queue!")
        return;
    end

    exp = expected_q[0];
    
    // Compare each element in the row
    for (int i = 0; i < N; i++) begin
        if (tr.c_dout[i] !== exp[output_row_cnt][i]) begin
            `uvm_error("SCB_MISMATCH", $sformatf("Mismatch at Matrix Row %0d, Col %0d | Exp: %0d, Got: %0d", 
                        output_row_cnt, i, exp[output_row_cnt][i], tr.c_dout[i]))
            error_cnt++;
        end
    end

    output_row_cnt++;
    if (output_row_cnt == N) begin
        void'(expected_q.pop_front());
        output_row_cnt = 0;
        `uvm_info("SCB_MATCH", "Full NxN Matrix verified successfully!", UVM_LOW)
    end
  endfunction

  function void sample_input_coverage(systolic_seq_item#(DIN_WIDTH, N) tr);
    for (int i = 0; i < N; i++) begin
        cov_item.a = tr.a[i];
        cov_item.b = tr.b[i];
        cov_item.sample();
    end
  endfunction

  // Report final verification status
  function void report_phase(uvm_phase phase);
    if (error_cnt == 0)
        `uvm_info("SCB_FINAL", "VERIFICATION PASSED: All results matched.", UVM_LOW)
    else
        `uvm_error("SCB_FINAL", $sformatf("VERIFICATION FAILED: %0d total mismatches.", error_cnt))
  endfunction

endclass : systolic_scoreboard

`endif