`ifndef SYSTOLIC_SEQ_ITEM_SV
`define SYSTOLIC_SEQ_ITEM_SV
class systolic_seq_item#(parameter int DIN_WIDTH = 8, parameter int N=4) extends uvm_sequence_item;
    // each element is bit[7:0], array has 4 elements (0..3)
    rand bit [DIN_WIDTH-1:0] a [0:N-1];
    rand bit [DIN_WIDTH-1:0] b [0:N-1];

    // for parameterized UVM objects use the param utils macro
    `uvm_object_param_utils(systolic_seq_item#(DIN_WIDTH, N))

    function new(string name = "systolic_seq_item");
        super.new(name);
        foreach (a[i]) a[i] = '0;
        foreach (b[i]) b[i] = '0;
    endfunction

    function string convert2string();
        string str;
        str = $sformatf("systolic_seq_item: a=[");
        foreach (a[i]) str = {str, $sformatf("%0d ", a[i])};
        str = {str, "] b=["};
        foreach (b[i]) str = {str, $sformatf("%0d ", b[i])};
        str = {str, "]"};
        return str;
    endfunction
    
endclass
`endif