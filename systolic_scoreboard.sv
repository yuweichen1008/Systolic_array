`ifndef SYSTOLIC_SCOREBOARD_SV
`define SYSTOLIC_SCOREBOARD_SV
class coverage_item#(parameter int DIN_WIDTH = 8) extends uvm_object;
  `uvm_object_utils(coverage_item)

  rand bit [DIN_WIDTH-1:0] a;
  rand bit [DIN_WIDTH-1:0] b;
  localparam int MAX_VALUE = 2**DIN_WIDTH - 1;

  function new(string name = "coverage_item");
    super.new(name);
    cg = new();
  endfunction

  covergroup cg;
    coverpoint a {
      bins a_bins[] = {[0:MAX_VALUE]};
    }
    coverpoint b {
      bins b_bins[] = {[0:MAX_VALUE]};
    }
    cross a, b;
  endgroup

  function void sample();
    cg.sample();
  endfunction
endclass : coverage_item

class systolic_scoreboard#(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_component;

  uvm_analysis_imp#(systolic_seq_item#(DIN_WIDTH,N), systolic_scoreboard#(DIN_WIDTH, N)) analysis_export;
  coverage_item#(DIN_WIDTH) cov_item;

  `uvm_component_param_utils(systolic_scoreboard#(DIN_WIDTH, N))

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
    cov_item = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  function void write(systolic_seq_item result);
    // Check result before cover
    `uvm_info("SYSTOLIC_SCOREBOARD", $sformatf("Scoreboard received result: %s", result.convert2string()), UVM_LOW);

    // Sample coverage
    for(int i = 0; i < N; i++) begin
      cov_item.a = result.a[i];
      cov_item.b = result.b[i];
      cov_item.sample();
    end
    
  endfunction

endclass : systolic_scoreboard
`endif