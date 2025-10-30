`ifndef SYSTOLIC_DRIVER_SV
`define SYSTOLIC_DRIVER_SV 

class systolic_driver #(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_driver#(systolic_seq_item#(DIN_WIDTH, N));

    typedef virtual systolic_if #(DIN_WIDTH, N) systolic_vif_t;
    systolic_vif_t vif;
    systolic_cfg cfg;
    `uvm_component_param_utils(systolic_driver#(DIN_WIDTH, N))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(systolic_vif_t)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface 'vif' not found in config_db")
        end
        if(!uvm_config_db#(systolic_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("NOCFG", "systolic_cfg not found in config_db for systolic_driver")
        end
    endfunction

    task run_phase(uvm_phase phase);
        systolic_seq_item#(DIN_WIDTH, N) req; // non-parameterized type
        int counter;

        phase.raise_objection(this);
        
        cfg.start_simulation.wait_trigger(); // wait for signal to start sequences
        `uvm_info("SYSTOLIC_DRIVER", "Starting driver run_phase", UVM_LOW);

        forever begin
            // get next sequence item from sequencer
            seq_item_port.get_next_item(req);
            `uvm_info("SYSTOLIC_DRIVER", "Driving new seq_item to DUT", UVM_LOW);

            // TODO add some delay or handshake mechanism if needed
            // drive inputs to DUT
            @(posedge vif.clk);
            vif.in_valid <= 1;
            `uvm_info("SYSTOLIC_DRIVER", "Set valid", UVM_LOW);

            // simple handshake: put data on interface and wait for ready
            for(int i = 0; i < N; i++) begin
                vif.a[i] <= req.a[i];
                vif.b[i] <= req.b[i];
            end

            // deassert in_valid on next cycle
            @(posedge vif.clk);
            vif.in_valid <= 0;
            for(int i = 0; i < N; i++) begin
                vif.a[i] <= '0;
                vif.b[i] <= '0;
            end
            `uvm_info("SYSTOLIC_DRIVER", "Set invalid and reset inputs", UVM_LOW);

            // wait until output is valid
            counter = 0;
            while(vif.out_valid !== 1) begin
                @(posedge vif.clk);
                counter++;
                if (counter > 1000) begin
                    `uvm_error("TIMEOUT", "Timeout waiting for out_valid from DUT")
                end
            end

            // notify sequencer the item is processed
            seq_item_port.item_done();
        end

        `uvm_info("SYSTOLIC_DRIVER", "Ending driver run_phase", UVM_LOW);
        phase.drop_objection(this);
    endtask
endclass

`endif