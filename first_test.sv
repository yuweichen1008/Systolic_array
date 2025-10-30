import uvm_pkg::*;
`include "uvm_macros.svh"
import systolic_pkg::*;

class first_test extends uvm_test;
    localparam int DIN_WIDTH = 8;
    localparam int N = 4;

    `uvm_component_utils(first_test)

    systolic_env #(.DIN_WIDTH(DIN_WIDTH), .N(N)) env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = systolic_env #(DIN_WIDTH, N)::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        systolic_seq_item#(DIN_WIDTH, N) seq_item;
        systolic_sequence #(DIN_WIDTH, N) seq;

        super.run_phase(phase);
        phase.raise_objection(this);

        if (env == null || env.agt == null || env.agt.seqr == null) begin
            `uvm_fatal("SEQ", "Sequencer handle is null!")
        end
        seq = systolic_sequence #(DIN_WIDTH, N)::type_id::create("seq");
        seq.start(env.agt.seqr);

        // Wait for some time to observe DUT behavior
        #1000ns;
        phase.drop_objection(this);
        `uvm_info("FIRST_TEST", "First test completed", UVM_LOW);
    endtask
    
endclass : first_test