`ifndef SYSTOLIC_DRIVER_SV
`define SYSTOLIC_DRIVER_SV 

class systolic_driver #(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_driver#(systolic_seq_item#(DIN_WIDTH, N));

    typedef virtual systolic_if #(DIN_WIDTH, N) systolic_vif_t;
    systolic_vif_t vif;
    `uvm_component_param_utils(systolic_driver#(DIN_WIDTH, N))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(systolic_vif_t)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface 'vif' not found in config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        systolic_seq_item#(DIN_WIDTH, N) req; // non-parameterized type
        phase.raise_objection(this);
        forever begin
            // get next sequence item from sequencer
            seq_item_port.get_next_item(req);

            // simple handshake: put data on interface and wait for ready
            for(int i = 0; i < N; i++) begin
                @(posedge vif.clk);
                vif.a[i] <= req.a[i];
                vif.b[i] <= req.b[i];
                vif.in_valid <= 1;
            end

            // deassert in_valid on next cycle
            @(posedge vif.clk);
            vif.in_valid <= 0;

            // notify sequencer the item is processed
            seq_item_port.item_done();
        end
        phase.drop_objection(this);
    endtask
endclass

`endif