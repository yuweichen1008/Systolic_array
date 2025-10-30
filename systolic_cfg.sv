class systolic_cfg extends uvm_object;

  `uvm_object_utils(systolic_cfg)

  // Configuration parameters
  int data_width;
  int array_size;

  function new(string name = "systolic_cfg");
    super.new(name);
    // Set default configuration values
    data_width = 8;
    array_size = 4;
  endfunction
  
endclass : systolic_cfg