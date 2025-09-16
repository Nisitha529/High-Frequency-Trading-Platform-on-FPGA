`timescale 1ns / 1ps

module tb_ip_core;

  // Clock configuration
  parameter CLK_PERIOD = 10;   // Clock period in nanoseconds

  // Testbench stimulus signals
  reg         clk;
  reg         rst_n;
  reg [31:0]  s_axis_tdata;
  reg         s_axis_tvalid;
  reg         m_axis_tready;
  reg [31:0]  control_reg;

  // DUT output signals
  wire        s_axis_tready;
  wire [31:0] m_axis_tdata;
  wire        m_axis_tvalid;
  wire [31:0] status_reg;

  // Instantiate the DUT (custom IP core)
  ip_core ip_core_dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .s_axis_tdata  (s_axis_tdata),
    .s_axis_tvalid (s_axis_tvalid),
    .s_axis_tready (s_axis_tready),
    .m_axis_tdata  (m_axis_tdata),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tready (m_axis_tready),
    .control_reg   (control_reg),
    .status_reg    (status_reg)
  );

  // Generate periodic clock signal
  always begin
    clk = 1'b0;
    #(CLK_PERIOD/2);
    clk = 1'b1;
    #(CLK_PERIOD/2);
  end

  // Apply test sequences
  initial begin
    // Initialize all inputs
    rst_n         = 1'b0;
    s_axis_tdata  = 32'h0;
    s_axis_tvalid = 1'b0;
    m_axis_tready = 1'b1;
    control_reg   = 32'h0;

    // Apply reset
    #(CLK_PERIOD*2);
    rst_n = 1'b1;

    // Test 1: Send a simple input packet
    #(CLK_PERIOD*2);
    s_axis_tdata  = 32'h12345678;
    s_axis_tvalid = 1'b1;
    #(CLK_PERIOD);
    s_axis_tvalid = 1'b0;
    wait (m_axis_tvalid);
    #(CLK_PERIOD);

    // Test 2: Configure the control register
    #(CLK_PERIOD*2);
    control_reg = 32'hABCDEF01;
    #(CLK_PERIOD*2);

    // Test 3: Send packet with control influence
    #(CLK_PERIOD*2);
    s_axis_tdata  = 32'h87654321;
    s_axis_tvalid = 1'b1;
    #(CLK_PERIOD);
    s_axis_tvalid = 1'b0;
    wait (m_axis_tvalid);
    #(CLK_PERIOD);

    // Test 4: Check status register contents
    #(CLK_PERIOD*2);
    $display("Status register: %h", status_reg);
    if (status_reg[7:0] == 8'd1)
      $display("Status register update is correct");
    else
      $error("Unexpected status register value");

    // End simulation
    #(CLK_PERIOD*10);
    $finish;
  end

  // Monitor output stream during simulation
  always @(posedge clk) begin
    if (m_axis_tvalid) begin
      $display("Output data observed: %h", m_axis_tdata);
      if (m_axis_tdata == 32'h12345678 + control_reg)
        $display("Output matches expected result");
      else
        $error("Output mismatch detected");
    end
  end

endmodule
