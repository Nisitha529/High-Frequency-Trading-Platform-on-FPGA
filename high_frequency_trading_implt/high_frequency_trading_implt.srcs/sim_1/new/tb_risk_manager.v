`timescale 1ns / 1ps

module tb_risk_manager;

  // Simulation parameters
  parameter CLK_PERIOD = 10;             // Clock period definition (10 ns → 100 MHz)

  // DUT input signals
  reg         clk;
  reg         rst_n;
  reg  [31:0] trade_data;
  reg         trade_valid;
  reg  [31:0] position_update;
  reg         position_update_valid;
  reg  [31:0] exposure_update;
  reg         exposure_update_valid;

  // DUT output signals
  wire        trade_approved;
  wire [31:0] current_position;
  wire [31:0] current_exposure;

  // Instantiate the device under test (DUT)
  risk_manager risk_manager_dut (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .trade_data             (trade_data),
    .trade_valid            (trade_valid),
    .trade_approved         (trade_approved),
    .position_update        (position_update),
    .position_update_valid  (position_update_valid),
    .current_position       (current_position),
    .exposure_update        (exposure_update),
    .exposure_update_valid  (exposure_update_valid),
    .current_exposure       (current_exposure),
    .max_exposure_limit     (32'h1000000),
    .max_position_limit     (32'h100000)
  );

  // Clock generation: toggles every half period
  always begin
    clk = 1'b0;
    #(CLK_PERIOD/2);
    clk = 1'b1;
    #(CLK_PERIOD/2);
  end

  // Test sequence
  initial begin
    // Reset sequence
    rst_n                  = 1'b0;
    trade_data             = 32'h0;
    trade_valid            = 1'b0;
    position_update        = 32'h0;
    position_update_valid  = 1'b0;
    exposure_update        = 32'h0;
    exposure_update_valid  = 1'b0;

    #(CLK_PERIOD*2);
    rst_n                  = 1'b1;

    // Case 1: Normal trade request within limits
    #(CLK_PERIOD*2);
    trade_data             = 32'h00010000;   
    trade_valid            = 1'b1;
    #(CLK_PERIOD);
    trade_valid            = 1'b0;

    // Case 2: Update position successfully
    #(CLK_PERIOD*2);
    position_update        = 32'h00020000;   
    position_update_valid  = 1'b1;
    #(CLK_PERIOD);
    position_update_valid  = 1'b0;

    // Case 3: Update exposure successfully
    #(CLK_PERIOD*2);
    exposure_update        = 32'h00030000;  
    exposure_update_valid  = 1'b1;
    #(CLK_PERIOD);
    exposure_update_valid  = 1'b0;

    // Case 4: Trade exceeds allowed exposure
    #(CLK_PERIOD*2);
    trade_data             = 32'h00800000;  
    trade_valid            = 1'b1;
    #(CLK_PERIOD);
    trade_valid            = 1'b0;

    // Case 5: Trade exceeds allowed position
    #(CLK_PERIOD*2);
    trade_data             = 32'h00100000;   
    trade_valid            = 1'b1;
    #(CLK_PERIOD);
    trade_valid            = 1'b0;

    // Finish simulation
    #(CLK_PERIOD*10);
    $finish;
  end

  // Monitor trade approval status
  always @(posedge clk) begin
    if (trade_valid) begin
      $display("Trade request: amount = %d, approved = %b", trade_data, trade_approved);
      if (trade_data <= 32'h00400000) begin
        if (!trade_approved)
          $display("Warning: trade should have been approved but was rejected");
      end else begin
        if (trade_approved)
          $display("Warning: trade should have been rejected but was approved");
      end
    end
  end

  // Monitor position and exposure updates
  always @(posedge clk) begin
    $display("Current position = %d, Current exposure = %d", current_position, current_exposure);
    if (current_position > 32'h100000)
      $display("Error: position limit exceeded");
    if (current_exposure > 32'h1000000)
      $display("Error: exposure limit exceeded");
  end

endmodule
