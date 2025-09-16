`timescale 1ns / 1ps

module tb_top_hft;

  // Clock period parameter
  parameter CLK_PERIOD = 10;  // ns

  reg         clk;
  reg         rst_n;
  reg  [47:0] eth_rx_data;
  reg         eth_rx_valid;
  reg         eth_tx_ready;
  reg  [31:0] custom_ip_control;

  wire        eth_rx_ready;
  wire [47:0] eth_tx_data;
  wire        eth_tx_valid;
  wire [31:0] custom_ip_status;

  top_hft top_hft (
    .clk               (clk),
    .rst_n             (rst_n),
    .eth_rx_data       (eth_rx_data),
    .eth_rx_valid      (eth_rx_valid),
    .eth_rx_ready      (eth_rx_ready),
    .eth_tx_data       (eth_tx_data),
    .eth_tx_valid      (eth_tx_valid),
    .eth_tx_ready      (eth_tx_ready),
    .custom_ip_control (custom_ip_control),
    .custom_ip_status  (custom_ip_status)
  );

  // Generate clock signal
  always begin
    clk = 1'b0;
    #(CLK_PERIOD/2);
    clk = 1'b1;
    #(CLK_PERIOD/2);
  end

  // Provide stimulus to DUT
  initial begin
    // Initialize inputs
    rst_n              = 1'b0;
    eth_rx_data        = 48'h0;
    eth_rx_valid       = 1'b0;
    eth_tx_ready       = 1'b1;
    custom_ip_control  = 32'h0;

    // Release reset
    #(CLK_PERIOD*2);
    rst_n = 1'b1;

    // Test 1: Send Ethernet frame
    #(CLK_PERIOD*2);
    eth_rx_data  = {16'h1234, 32'h12345678};
    eth_rx_valid = 1'b1;
    #(CLK_PERIOD);
    eth_rx_valid = 1'b0;
    wait(eth_tx_valid);
    #(CLK_PERIOD);

    // Test 2: Write to custom IP control register
    #(CLK_PERIOD*2);
    custom_ip_control = 32'hABCDEF01;
    #(CLK_PERIOD*2);

    // Test 3: Send order packet
    #(CLK_PERIOD*2);
    eth_rx_data  = {16'h5678, 2'b00, 2'b00, 8'h10, 8'h20, 8'h30, 4'h4};
    eth_rx_valid = 1'b1;
    #(CLK_PERIOD);
    eth_rx_valid = 1'b0;
    wait(eth_tx_valid);
    #(CLK_PERIOD);

    // Test 4: Read custom IP status
    #(CLK_PERIOD*2);
    $display("Custom IP status register: %h", custom_ip_status);
    if (custom_ip_status[7:0] == 8'd1)
      $display("Custom IP status is correct");
    else
      $error("Custom IP status incorrect");

    // Test 5: Send multiple order packets
    #(CLK_PERIOD*2);
    eth_rx_data  = {16'hAABB, 2'b01, 2'b01, 8'h40, 8'h50, 8'h60, 4'h7};
    eth_rx_valid = 1'b1;
    #(CLK_PERIOD);
    eth_rx_data  = {16'hCCDD, 2'b10, 2'b10, 8'h70, 8'h80, 8'h90, 4'hA};
    #(CLK_PERIOD);
    eth_rx_valid = 1'b0;
    wait(eth_tx_valid);
    #(CLK_PERIOD);

    // End simulation
    #(CLK_PERIOD*10);
    $finish;
  end

  // Monitor Ethernet transmit data
  always @(posedge clk) begin
    if (eth_tx_valid) begin
      $display("Ethernet transmit data: %h", eth_tx_data);
    end
  end

  // Monitor trade outputs
  always @(posedge clk) begin
    if (dut.order_matching_inst.trade_valid) begin
      $display("Trade data: %h", dut.order_matching_inst.trade_data);
    end
  end

  // Monitor risk management approval
  always @(posedge clk) begin
    if (dut.risk_mgmt_inst.trade_approved) begin
      $display("Trade approved by risk management");
    end else if (dut.order_matching_inst.trade_valid) begin
      $display("Trade rejected by risk management");
    end
  end

endmodule
