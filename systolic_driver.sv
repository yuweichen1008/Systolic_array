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

        cfg.start_simulation.wait_trigger(); // wait for signal to start sequences
        `uvm_info("SYSTOLIC_DRIVER", "Starting driver run_phase", UVM_LOW);

        while(!cfg.finish_simulation) begin
            // get next sequence item from sequencer
            seq_item_port.get_next_item(req);
            `uvm_info("SYSTOLIC_DRIVER", "Driving new seq_item to DUT", UVM_LOW);

            // pipeline data into DUT
            pipeline_data(req);

            // deassert in_valid and reset data on next cycle
            @(posedge vif.clk);
            vif.in_valid <= 0;
            for(int i = 0; i < N; i++) begin
                vif.a[i] <= '0;
                vif.b[i] <= '0;
            end
            `uvm_info("SYSTOLIC_DRIVER", "Set invalid and reset inputs", UVM_LOW);

            // wait until output is valid
            counter = 0;
            while(!cfg.finish_simulation && vif.out_valid !== 1) begin
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
    endtask

    task pipeline_data(systolic_seq_item#(DIN_WIDTH, N) req);
        bit[DIN_WIDTH-1:0] a_pipe [2*N][N/2]; // 2*N depth for systolic array
        bit[DIN_WIDTH-1:0] b_pipe [2*N][N/2]; // 2*N depth for systolic array

        // Create perfect matrix without deferred inputs
        for(int cycle = 0; cycle < N; cycle++) begin
            for(int i = 0; i < N/2; i++) begin
                a_pipe[cycle][i] = req.a[cycle*N/2 + i];
                b_pipe[cycle][i] = req.b[cycle*N/2 + i];
            end
        end
        // Diagonal shift: collect elements along shifted_cycle for all possible cycles
        for(int cycle = 0; cycle < 2*N-1; cycle++) begin
            for(int i = 0; i < N/2; i++) begin
                int shifted_cycle = cycle - i;
                if(shifted_cycle >= 0 && shifted_cycle < N) begin
                    a_pipe[cycle][i] = a_pipe[shifted_cycle][i];
                    b_pipe[cycle][i] = b_pipe[shifted_cycle][i];
                end else begin
                    a_pipe[cycle][i] = '0;
                    b_pipe[cycle][i] = '0;
                end
            end
        end
        // Introduce one cycle delay to simulate pipeline behavior
        vif.in_valid <= 1;
        for(int cycle = 0; cycle < 2*N-1; cycle++) begin
            // Apply inputs to DUT
            for(int i = 0; i < N/2; i++) begin
                vif.a[i] <= a_pipe[cycle][i];
                vif.b[i] <= b_pipe[cycle][i];
            end
            @(posedge vif.clk);
        end
        `uvm_info("SYSTOLIC_DRIVER", "Set valid and applied inputs to DUT", UVM_LOW);
    endtask
endclass

`endif