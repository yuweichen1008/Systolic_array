`ifndef SYSTOLIC_SEQUENCE_SV
`define SYSTOLIC_SEQUENCE_SV

// Sequence to generate data for an NxN matrix multiplication
class systolic_sequence#(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_sequence #(systolic_seq_item#(DIN_WIDTH, N));
    
    `uvm_object_param_utils(systolic_sequence#(DIN_WIDTH, N))

    // Constructor
    function new(string name = "systolic_sequence");
        super.new(name);
    endfunction

    // The body task generates N rows of data to form one complete matrix
    virtual task body();
        systolic_seq_item#(DIN_WIDTH, N) req;

        `uvm_info("SYSTOLIC_SEQ", $sformatf("Starting sequence to generate a %0dx%0d matrix", N, N), UVM_LOW)

        // Loop N times because the driver expects N rows to fill the systolic mesh
        for (int i = 0; i < N; i++) begin
            req = systolic_seq_item#(DIN_WIDTH, N)::type_id::create("req");

            // Start the item handshaking with the sequencer
            start_item(req);

            // Randomize the row data (A and B elements)
            // This will use the signed logic ranges defined in the seq_item
            if (!req.randomize()) begin
                `uvm_error("SYSTOLIC_SEQ", "Randomization failed for matrix row")
            end

            // Finish the item to send it to the driver
            finish_item(req);
            
            `uvm_info("SYSTOLIC_SEQ", $sformatf("Sent row %0d/%0d: %s", i+1, N, req.convert2string()), UVM_HIGH)
        end

        `uvm_info("SYSTOLIC_SEQ", "Finished generating one full matrix.", UVM_LOW)
    endtask

endclass

`endif