`timescale 1ns / 1ps

module tcp_ip_stack (
  input  wire        clk,
  input  wire        rst_n,

  // Application layer interface
  input  wire [31:0] app_tx_data,
  input  wire        app_tx_valid,
  output reg         app_tx_ready,
  output reg [31:0]  app_rx_data,
  output reg         app_rx_valid,
  input  wire        app_rx_ready,

  // Ethernet interface
  output reg [31:0]  eth_tx_data,
  output reg         eth_tx_valid,
  input  wire        eth_tx_ready,
  input  wire [31:0] eth_rx_data,
  input  wire        eth_rx_valid,
  output reg         eth_rx_ready
);

  // TCP/IP configuration parameters
  parameter LOCAL_IP    = 32'hC0A80001;  // Local IP: 192.168.0.1
  parameter LOCAL_PORT  = 16'h1234;      // Local TCP port
  parameter REMOTE_IP   = 32'hC0A80002;  // Remote IP: 192.168.0.2
  parameter REMOTE_PORT = 16'h5678;      // Remote TCP port

  // TCP connection states
  parameter CLOSED      = 2'b00;
  parameter SYN_SENT    = 2'b01;
  parameter ESTABLISHED = 2'b10;
  parameter FIN_WAIT    = 2'b11;

  reg [1:0]  tcp_state;
  reg [31:0] tcp_seq_num;
  reg [31:0] tcp_ack_num;

  // Transmit and receive buffers
  reg [31:0] tx_buffer [0:255];
  reg [7:0]  tx_head, tx_tail;
  reg [31:0] rx_buffer [0:255];
  reg [7:0]  rx_head, rx_tail;

  // Main TCP/IP stack logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize all state and buffers
      tcp_state     <= CLOSED;
      tcp_seq_num   <= 0;
      tcp_ack_num   <= 0;
      tx_head       <= 0;
      tx_tail       <= 0;
      rx_head       <= 0;
      rx_tail       <= 0;
      app_tx_ready  <= 0;
      app_rx_valid  <= 0;
      eth_tx_valid  <= 0;
      eth_rx_ready  <= 0;
    end else begin
      // TCP state machine
      case (tcp_state)
        CLOSED: begin
          // Initiate connection if application has data
          if (app_tx_valid) begin
            tcp_state   <= SYN_SENT;
            tcp_seq_num <= {$random} % 32'hFFFFFFFF;
            tx_buffer[tx_tail] <= {tcp_seq_num, 16'h0002}; // SYN flag
            tx_tail     <= tx_tail + 1;
          end
        end

        SYN_SENT: begin
          // Wait for SYN-ACK from remote
          if (eth_rx_valid &&
              eth_rx_data[31:16] == {LOCAL_IP, LOCAL_PORT} &&
              eth_rx_data[15:0]  == {REMOTE_IP, REMOTE_PORT} &&
              eth_rx_data[15]    == 1'b1) begin
            tcp_state   <= ESTABLISHED;
            tcp_ack_num <= eth_rx_data[31:0] + 1;
            tx_buffer[tx_tail] <= {tcp_seq_num, tcp_ack_num, 16'h0010}; // ACK
            tx_tail     <= tx_tail + 1;
          end
        end

        ESTABLISHED: begin
          // Send application data if valid
          if (app_tx_valid && app_tx_ready) begin
            tx_buffer[tx_tail] <= {tcp_seq_num, tcp_ack_num, 16'h0018, app_tx_data}; // PSH-ACK
            tx_tail            <= tx_tail + 1;
            tcp_seq_num        <= tcp_seq_num + 1;
          end

          // Handle received Ethernet packets
          if (eth_rx_valid &&
              eth_rx_data[31:16] == {LOCAL_IP, LOCAL_PORT} &&
              eth_rx_data[15:0]  == {REMOTE_IP, REMOTE_PORT}) begin

            if (eth_rx_data[15] == 1'b1 && eth_rx_data[14] == 1'b1) begin
              // FIN-ACK received, initiate connection teardown
              tcp_state   <= FIN_WAIT;
              tcp_ack_num <= eth_rx_data[31:0] + 1;
              tx_buffer[tx_tail] <= {tcp_seq_num, tcp_ack_num, 16'h0011}; // FIN-ACK
              tx_tail     <= tx_tail + 1;

            end else if (eth_rx_data[13] == 1'b1) begin
              // Data packet received, update buffers
              rx_buffer[rx_tail] <= eth_rx_data[31:0];
              rx_tail            <= rx_tail + 1;
              tcp_ack_num        <= eth_rx_data[31:0] + 1;
              tx_buffer[tx_tail] <= {tcp_seq_num, tcp_ack_num, 16'h0010}; // ACK
              tx_tail            <= tx_tail + 1;
            end
          end
        end

        FIN_WAIT: begin
          // Close connection when application consumes all data
          if (app_rx_ready && app_rx_valid) begin
            tcp_state <= CLOSED;
          end
        end
      endcase

      // Transmit packet if Ethernet ready and buffer not empty
      if (eth_tx_ready && tx_head != tx_tail) begin
        eth_tx_data  <= {LOCAL_IP, LOCAL_PORT, REMOTE_IP, REMOTE_PORT, tx_buffer[tx_head]};
        eth_tx_valid <= 1;
        tx_head      <= tx_head + 1;
      end else begin
        eth_tx_valid <= 0;
      end

      // Forward received packets to application layer
      if (app_rx_ready && rx_head != rx_tail) begin
        app_rx_data  <= rx_buffer[rx_head];
        app_rx_valid <= 1;
        rx_head      <= rx_head + 1;
      end else begin
        app_rx_valid <= 0;
      end

      // Update ready signals for application and Ethernet interfaces
      app_tx_ready <= (tcp_state == ESTABLISHED) && ((tx_tail - tx_head) < 256);
      eth_rx_ready <= (tcp_state == ESTABLISHED) && ((rx_tail - rx_head) < 256);
    end
  end

endmodule
