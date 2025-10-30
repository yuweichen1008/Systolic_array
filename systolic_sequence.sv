`ifndef SYSTOLIC_SEQUENCE_SV
`define SYSTOLIC_SEQUENCE_SV
class systolic_sequence#(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_sequence #(systolic_seq_item#(DIN_WIDTH, N));

    `uvm_object_param_utils(systolic_sequence#(DIN_WIDTH, N))

    function new(string name = "systolic_sequence");
        super.new(name);
    endfunction

    virtual task body();
        systolic_seq_item#(DIN_WIDTH, N) req;
        req = systolic_seq_item#(DIN_WIDTH, N)::type_id::create("req");

        // Example sequence item generation
        start_item(req);
        // randomize fields
        if(req.randomize()) begin
            string a_str, b_str;
            foreach (req.a[i]) a_str = {a_str, $sformatf("%0d ", req.a[i])};
            foreach (req.b[i]) b_str = {b_str, $sformatf("%0d ", req.b[i])};
            $sformatf("Generated seq_item: a=%s, b=%s", a_str, b_str);
            // `uvm_info("SYSTOLIC_SEQ", $sformatf("Generated seq_item: a=%0d, b=%0d", req.a, req.b), UVM_LOW)
        end else begin
            `uvm_error("SYSTOLIC_SEQ", "Failed to randomize seq_item")
        end

        finish_item(req);
    endtask
endclass
`endif