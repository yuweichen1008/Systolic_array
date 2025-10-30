`ifndef SYSTOLIC_AGENT_SV
`define SYSTOLIC_AGENT_SV
class systolic_agent#(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_component;

    `uvm_component_param_utils(systolic_agent#(DIN_WIDTH, N))

    bit is_active_agent;
    systolic_cfg cfg;
    systolic_sequencer #(DIN_WIDTH, N) seqr;
    systolic_driver #(DIN_WIDTH, N) drv;
    systolic_monitor #(DIN_WIDTH, N) mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        is_active_agent = 1;
        void'(uvm_config_db#(systolic_cfg)::get(this, "", "cfg", cfg));
        if( cfg == null ) begin
            `uvm_fatal("NOCFG", "systolic_cfg not found in config_db")
        end
        seqr = systolic_sequencer#(DIN_WIDTH, N)::type_id::create("seqr", this);
        // Instantiate driver and monitor
        mon = systolic_monitor#(DIN_WIDTH, N)::type_id::create("mon", this);
        if( is_active_agent ) begin
            drv = systolic_driver#(DIN_WIDTH, N)::type_id::create("drv", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Connect driver and monitor if needed
        if( is_active_agent ) begin
            drv.seq_item_port.connect(seqr.seq_item_export);
        end
    endfunction
endclass : systolic_agent
`endif