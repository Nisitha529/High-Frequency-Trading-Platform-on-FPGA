`timescale 1ns / 1ps

module tb_order_matcher;

  // Simulation parameters
  parameter CLK_PERIOD = 10;    // Clock period in ns

  // Input signals
  reg         clk;
  reg         rst_n;
  reg [31:0]  order_data;
  reg         order_valid;
  reg [31:0]  tcp_rx_data;
  reg         tcp_rx_valid;
  reg         m_axis_ready;

  // Output signals
  wire [31:0] trade_data;
  wire        trade_valid;
  wire [31:0] tcp_tx_data;
  wire        tcp_tx_valid;
  wire        s_axis_ready;
  wire [31:0] m_axis_data;
  wire        m_axis_valid;

  // DUT instantiation: order matching engine
  order_matcher order_matcher_dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .order_data    (order_data),
    .order_valid   (order_valid),
    .trade_data    (trade_data),
    .trade_valid   (trade_valid),
    .tcp_rx_data   (tcp_rx_data),
    .tcp_rx_valid  (tcp_rx_valid),
    .tcp_tx_data   (tcp_tx_data),
    .tcp_tx_valid  (tcp_tx_valid),
    .s_axis_data   (m_axis_data),
    .s_axis_valid  (m_axis_valid),
    .s_axis_ready  (s_axis_ready),
    .m_axis_data   (m_axis_data),
    .m_axis_valid  (m_axis_valid),
    .m_axis_ready  (m_axis_ready)
  );

  // Clock generation: toggles every half period
  always begin
    clk = 1'b0;
    #(CLK_PERIOD/2);
    clk = 1'b1;
    #(CLK_PERIOD/2);
  end

  // Testbench stimulus process
  initial begin
    // Reset phase
    rst_n          = 1'b0;
    order_data     = 32'h0;
    order_valid    = 1'b0;
    tcp_rx_data    = 32'h0;
    tcp_rx_valid   = 1'b0;
    m_axis_ready   = 1'b1;

    #(CLK_PERIOD*2);
    rst_n          = 1'b1;

    // Case 1: Submit a buy limit order
    #(CLK_PERIOD*2);
    order_data     = {2'b00, 2'b00, 8'h10, 8'h01, 8'h00, 4'h0};
    order_valid    = 1'b1;
    #(CLK_PERIOD);
    order_valid    = 1'b0;

    // Case 2: Submit a sell limit order
    #(CLK_PERIOD*2);
    order_data     = {2'b00, 2'b00, 8'h20, 8'h02, 8'h00, 4'h0};
    order_valid    = 1'b1;
    #(CLK_PERIOD);
    order_valid    = 1'b0;

    // Case 3: Matching buy order at same price/qty
    #(CLK_PERIOD*2);
    order_data     = {2'b00, 2'b00, 8'h20, 8'h02, 8'h00, 4'h0};
    order_valid    = 1'b1;
    #(CLK_PERIOD);
    order_valid    = 1'b0;

    // Case 4: Market buy order execution
    #(CLK_PERIOD*2);
    order_data     = {2'b01, 2'b00, 8'h00, 8'h03, 8'h00, 4'h0};
    order_valid    = 1'b1;
    #(CLK_PERIOD);
    order_valid    = 1'b0;

    // Case 5: Place a stop sell order
    #(CLK_PERIOD*2);
    order_data     = {2'b10, 2'b00, 8'h30, 8'h04, 8'h40, 4'h0};
    order_valid    = 1'b1;
    #(CLK_PERIOD);
    order_valid    = 1'b0;

    // Case 6: Place a trailing stop buy order
    #(CLK_PERIOD*2);
    order_data     = {2'b11, 2'b00, 8'h50, 8'h05, 8'h60, 4'h2};
    order_valid    = 1'b1;
    #(CLK_PERIOD);
    order_valid    = 1'b0;

    // Case 7: Receive TCP packet
    #(CLK_PERIOD*2);
    tcp_rx_data    = 32'h12345678;
    tcp_rx_valid   = 1'b1;
    #(CLK_PERIOD);
    tcp_rx_valid   = 1'b0;

    // Finish simulation
    #(CLK_PERIOD*10);
    $finish;
  end

  // Monitor executed trades
  always @(posedge clk) begin
    if (trade_valid) begin
      $display("Trade executed: price = %d, quantity = %d",
                trade_data[7:0], trade_data[15:8]);
      if (trade_data[7:0] == 8'h20 && trade_data[15:8] == 8'h02)
        $display("Trade data is correct");
      else
        $error("Incorrect trade data");
    end
  end

  // Monitor TCP transmissions
  always @(posedge clk) begin
    if (tcp_tx_valid) begin
      $display("TCP transmit data: %h", tcp_tx_data);
      if (tcp_tx_data == {2'b11, 30'h1234567})
        $display("TCP transmit data is correct");
      else
        $error("Incorrect TCP transmit data");
    end
  end

endmodule
