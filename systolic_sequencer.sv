`ifndef SYSTOLIC_SEQUENCER_SV
`define SYSTOLIC_SEQUENCER_SV
class systolic_sequencer #(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_sequencer #(systolic_seq_item#(DIN_WIDTH, N));
    `uvm_component_param_utils(systolic_sequencer#(DIN_WIDTH, N))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass : systolic_sequencer
`endif