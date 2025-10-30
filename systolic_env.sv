`ifndef SYSTOLIC_ENV_SV
`define SYSTOLIC_ENV_SV

class systolic_env#(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_env;
  typedef virtual systolic_if#(DIN_WIDTH, N) systolic_vif_t;

  `uvm_component_param_utils(systolic_env#(DIN_WIDTH, N))

  // Declare sub-components here
  systolic_vif_t  vif;
  systolic_cfg    cfg;
  systolic_agent#(DIN_WIDTH, N)      agt;
  systolic_scoreboard#(DIN_WIDTH, N) sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(systolic_vif_t)::get(this, "*", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface 'vif' not found in config_db for systolic_agent")
    end 
    cfg = systolic_cfg::type_id::create("cfg");
    cfg.data_width = 8;
    cfg.array_size = 4;
    cfg.start_simulation = new("start_simulation_event");

    uvm_config_db#(systolic_cfg)::set(null, "*", "cfg", cfg); // for sub-components

    // Instantiate sub-components
    agt = systolic_agent#(DIN_WIDTH, N)::type_id::create("agt", this);
    sb = systolic_scoreboard#(DIN_WIDTH, N)::type_id::create("sb", this);

  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // connect monitor to scoreboard
    if (agt.mon != null) begin
      agt.mon.analysis_port.connect(sb.analysis_export);
    end else begin
      `uvm_error("NOMON", "Monitor 'mon' is not instantiated in systolic_agent")
    end
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    wait(vif.rst_n == 1); // wait for reset deassertion
    cfg.start_simulation.trigger(); // signal to start sequences
    `uvm_info("SYSTOLIC_ENV", "Starting environment run_phase", UVM_LOW);

    phase.drop_objection(this);
  endtask

endclass : systolic_env
`endif