`ifndef SYSTOLIC_MONITOR_SV
`define SYSTOLIC_MONITOR_SV

class systolic_monitor #(
    parameter int DIN_WIDTH = 8, 
    parameter int N = 4
) extends uvm_monitor;

    `uvm_component_param_utils(systolic_monitor#(DIN_WIDTH, N))

    // Virtual Interface handle
    typedef virtual systolic_if #(DIN_WIDTH, N) systolic_vif_t;
    systolic_vif_t vif;

    // Analysis Port to send transactions to the Scoreboard 
    uvm_analysis_port #(systolic_seq_item#(DIN_WIDTH, N)) item_collected_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(systolic_vif_t)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MON_NOCFG", "Virtual interface 'vif' not found in config_db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        // Concurrently monitor inputs and outputs
        fork
            monitor_inputs();
            monitor_outputs();
        join
    endtask

    // Task to capture A and B matrix inputs
    protected task monitor_inputs();
        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.in_valid) begin
                systolic_seq_item#(DIN_WIDTH, N) tr;
                tr = systolic_seq_item#(DIN_WIDTH, N)::type_id::create("in_tr");
                
                tr.is_input = 1;
                tr.is_output = 0;
                for (int i = 0; i < N; i++) begin
                    tr.a[i] = vif.a[i];
                    tr.b[i] = vif.b[i];
                end
                
                `uvm_info("MON_INPUT", $sformatf("Captured Input: %s", tr.convert2string()), UVM_HIGH)
                item_collected_port.write(tr);
            end
        end
    endtask

    // Task to capture C matrix results
    protected task monitor_outputs();
        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.out_valid) begin
                systolic_seq_item#(DIN_WIDTH, N) tr;
                tr = systolic_seq_item#(DIN_WIDTH, N)::type_id::create("out_tr");
                
                tr.is_input = 0;
                tr.is_output = 1;
                tr.out_valid = 1;
                for (int i = 0; i < N; i++) begin
                    tr.c_dout[i] = vif.c_dout[i];
                end
                
                `uvm_info("MON_OUTPUT", $sformatf("Captured Output Result: %p", tr.c_dout), UVM_MEDIUM)
                item_collected_port.write(tr);
            end
        end
    endtask

endclass

`endif