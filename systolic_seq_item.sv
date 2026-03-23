`ifndef SYSTOLIC_SEQ_ITEM_SV
`define SYSTOLIC_SEQ_ITEM_SV

class systolic_seq_item#(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_sequence_item;

    // Input data fields (A and B rows)
    rand logic signed [DIN_WIDTH-1:0] a [0:N-1];
    rand logic signed [DIN_WIDTH-1:0] b [0:N-1];

    // Output data field (Result C row)
    // Note: This is not random as it's captured from the DUT
    logic signed [2*DIN_WIDTH-1:0] c_dout [0:N-1];

    // Control flags used by Monitor and Scoreboard
    bit is_input;
    bit is_output;
    bit out_valid;

    // UVM automation macros for parameters
    `uvm_object_param_utils_begin(systolic_seq_item#(DIN_WIDTH, N))
        `uvm_field_sarray_int(a, UVM_ALL_ON)
        `uvm_field_sarray_int(b, UVM_ALL_ON)
        `uvm_field_sarray_int(c_dout, UVM_ALL_ON)
        `uvm_field_int(is_input, UVM_ALL_ON)
        `uvm_field_int(is_output, UVM_ALL_ON)
        `uvm_field_int(out_valid, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "systolic_seq_item");
        super.new(name);
    endfunction

    // Helper function for cleaner logging in Scoreboard
    function string convert2string();
        string s;
        if (is_input)
            s = $sformatf("INPUT: a=%p, b=%p", a, b);
        else if (is_output)
            s = $sformatf("OUTPUT: c_dout=%p", c_dout);
        else
            s = "Empty Transaction";
        return s;
    endfunction
    
endclass

`endif