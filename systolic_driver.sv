`ifndef SYSTOLIC_DRIVER_SV
`define SYSTOLIC_DRIVER_SV

class systolic_driver #(parameter int DIN_WIDTH = 8, parameter int N = 4) extends uvm_driver#(systolic_seq_item#(DIN_WIDTH, N));
    typedef virtual systolic_if #(DIN_WIDTH, N) systolic_vif_t;
    systolic_vif_t vif;
    `uvm_component_param_utils(systolic_driver#(DIN_WIDTH, N))

    // internal buffers (NxN)
    logic signed [DIN_WIDTH-1:0] a_matrix [N][N];
    logic signed [DIN_WIDTH-1:0] b_matrix [N][N];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        // initial state
        vif.in_valid <= 0;
        vif.a <= '{default:0};
        vif.b <= '{default:0};

        forever begin
            // 1. fetch a full matrix transaction (N rows) from the sequence
            for (int i = 0; i < N; i++) begin
                seq_item_port.get_next_item(req);
                for (int j = 0; j < N; j++) begin
                    a_matrix[i][j] = req.a[j];
                    b_matrix[i][j] = req.b[j];
                end
                seq_item_port.item_done();
            end

            // 2. perform skewed driving
            drive_skewed_matrix();
        end
    endtask

    // Core driving logic: Implement 2N-1 cycles of skewed input [cite: 92]
    task drive_skewed_matrix();
        // Matrix operations require 2N-1 input cycles to flow through the entire array
        for (int t = 0; t < 2*N - 1; t++) begin
            @(posedge vif.clk);
            vif.in_valid <= 1;
            
            for (int i = 0; i < N; i++) begin
                // Row i of A starts at cycle t = i
                if (t >= i && (t - i) < N)
                    vif.a[i] <= a_matrix[i][t-i];
                else
                    vif.a[i] <= 0;

                // Column i of B starts at cycle t = i
                if (t >= i && (t - i) < N)
                    vif.b[i] <= b_matrix[t-i][i];
                else
                    vif.b[i] <= 0;
            end
        end
        
        // finish driving the current matrix, deassert valid and clear inputs
        @(posedge vif.clk);
        vif.in_valid <= 0;
        vif.a <= '{default:0};
        vif.b <= '{default:0};
    endtask

endclass
`endif