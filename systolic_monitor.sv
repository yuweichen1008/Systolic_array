`ifndef SYSTOLIC_MONITOR_SV
`define SYSTOLIC_MONITOR_SV
class systolic_monitor #(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_monitor;
  typedef virtual systolic_if#(DIN_WIDTH, N) systolic_vif_t;

  uvm_analysis_export#(systolic_seq_item#(DIN_WIDTH, N)) analysis_port;
  systolic_vif_t vif;
  `uvm_component_param_utils(systolic_monitor#(DIN_WIDTH, N))

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(systolic_vif_t)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface 'vif' not found in config_db")
    end
  endfunction

  task run_phase(uvm_phase phase);
    systolic_seq_item#(DIN_WIDTH, N) req; // non-parameterized type
    bit[DIN_WIDTH-1:0] a [0:N-1];
    bit[DIN_WIDTH-1:0] b [0:N-1];
    bit[2*DIN_WIDTH-1:0] expected_result[0:N-1];
    phase.raise_objection(this);

    forever begin
        
        // wait for valid signal
        while(vif.in_valid !== 1) begin
            @(posedge vif.clk);
        end

        // matrix multiplication input capture for N cycles
        for(int i = 0; i < N; i++) begin
            if(vif.in_valid == 1) begin
                a[i] = vif.a[i];
                b[i] = vif.b[i];
            end else begin
                `uvm_error("SYSTOLIC_MONITOR", "in_valid deasserted unexpectedly")
            end
        end

        // matrix multiplication calculation and expected result generation
        matrix_multiplication_calculation(a, b, expected_result);

        // matrix multiplication result capture
        // possibly invalid output wait (TODO: timeout?)
        while(vif.out_valid !== 1) begin
            @(posedge vif.clk);
            // if(vif.c_dout !== '0) begin
            //     `uvm_error("SYSTOLIC_MONITOR", "out_valid not asserted but c_dout has data")
            // end
        end

        // check received output against expected result
        for(int i = 0; i < N; i++) begin
            if (vif.c_dout[i] !== expected_result[i]) begin
                `uvm_error("SYSTOLIC_MONITOR", $sformatf("Mismatch: expected %0d, got %0d", expected_result[i], vif.c_dout[i]))
            end
        end

        // Create and send seq_item to scoreboard
        req = systolic_seq_item#(DIN_WIDTH, N)::type_id::create("req");
        for(int i = 0; i < N; i++) begin
            req.a[i] = a[i];
            req.b[i] = b[i];
        end
        analysis_port.write(req); // to scoreboard

    end
    phase.drop_objection(this);
  endtask

task automatic matrix_multiplication_calculation (
    input  bit [DIN_WIDTH-1:0]        a [0:N-1],
    input  bit [DIN_WIDTH-1:0]        b [0:N-1],
    output bit [2*DIN_WIDTH-1:0] expected_res [0:N-1]
);
    for (int i = 0; i < N; i++) begin
        // element-wise signed multiplication (adjust if a different relation is desired)
        expected_res[i] = $signed(a[i]) * $signed(b[i]);
    end
endtask

endclass : systolic_monitor
`endif