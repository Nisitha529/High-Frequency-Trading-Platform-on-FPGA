module order_matcher (
  input  wire        clk,
  input  wire        rst_n,
  input  wire [31:0] order_data,
  input  wire        order_valid,
  output reg  [31:0] trade_data,
  output reg         trade_valid,

  // TCP/IP stack interfaces
  input  wire [31:0] tcp_rx_data,
  input  wire        tcp_rx_valid,
  output reg  [31:0] tcp_tx_data,
  output reg         tcp_tx_valid,

  // AXI stream interfaces
  input  wire [31:0] s_axis_data,
  input  wire        s_axis_valid,
  output reg         s_axis_ready,
  output reg  [31:0] m_axis_data,
  output reg         m_axis_valid,
  input  wire        m_axis_ready
);

  // Encodings for order types
  parameter LIMIT_ORDER         = 2'b00;
  parameter MARKET_ORDER        = 2'b01;
  parameter STOP_ORDER          = 2'b10;
  parameter TRAILING_STOP_ORDER = 2'b11;

  // Encodings for execution strategies
  parameter AGGRESSIVE_STRATEGY = 2'b00;
  parameter PASSIVE_STRATEGY    = 2'b01;
  parameter ICEBERG_STRATEGY    = 2'b10;
  parameter VWAP_STRATEGY       = 2'b11;

  // Bid-side order book
  reg [1:0]   bid_order_type        [0:255];
  reg [1:0]   bid_execution_strategy[0:255];
  reg [31:0]  bid_price             [0:255];
  reg [31:0]  bid_quantity          [0:255];
  reg [31:0]  bid_stop_price        [0:255];
  reg [31:0]  bid_iceberg_quantity  [0:255];

  // Ask-side order book
  reg [1:0]   ask_order_type        [0:255];
  reg [1:0]   ask_execution_strategy[0:255];
  reg [31:0]  ask_price             [0:255];
  reg [31:0]  ask_quantity          [0:255];
  reg [31:0]  ask_stop_price        [0:255];
  reg [31:0]  ask_iceberg_quantity  [0:255];

  // Current book sizes
  reg [7:0]   bid_book_size;
  reg [7:0]   ask_book_size;

  // Main matching logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset all state
      bid_book_size <= 0;
      ask_book_size <= 0;
      trade_valid   <= 0;
      tcp_tx_valid  <= 0;
      s_axis_ready  <= 1;
      m_axis_valid  <= 0;
    end else begin
      // Accept new incoming order
      if (order_valid) begin
        bid_order_type[bid_book_size]         <= order_data[1:0];
        bid_execution_strategy[bid_book_size] <= order_data[3:2];
        bid_price[bid_book_size]              <= order_data[11:4];
        bid_quantity[bid_book_size]           <= order_data[19:12];
        bid_stop_price[bid_book_size]         <= order_data[27:20];
        bid_iceberg_quantity[bid_book_size]   <= order_data[31:28];
        
        // Handle order type
        case (order_data[1:0])
          LIMIT_ORDER: begin
            if (order_data[0])
              bid_book_size <= bid_book_size + 1;   // New buy limit order
            else
              ask_book_size <= ask_book_size + 1;   // New sell limit order
          end

          MARKET_ORDER: begin
            if (order_data[0]) begin
              if (ask_book_size > 0) begin
                trade_data    <= {ask_price[ask_book_size - 1], ask_quantity[ask_book_size - 1]};
                trade_valid   <= 1;
                ask_book_size <= ask_book_size - 1; // Match buy with best sell
              end
            end else begin
              if (bid_book_size > 0) begin
                trade_data    <= {bid_price[bid_book_size - 1], bid_quantity[bid_book_size - 1]};
                trade_valid   <= 1;
                bid_book_size <= bid_book_size - 1; // Match sell with best buy
              end
            end
          end

          STOP_ORDER: begin
            if (order_data[0]) begin
              if (order_data[27:20] <= bid_price[bid_book_size - 1])
                bid_book_size <= bid_book_size + 1; // Trigger buy stop
            end else begin
              if (order_data[27:20] >= ask_price[ask_book_size - 1])
                ask_book_size <= ask_book_size + 1; // Trigger sell stop
            end
          end

          TRAILING_STOP_ORDER: begin
            if (order_data[0]) begin
              if (order_data[27:20] <= bid_price[bid_book_size - 1])
                bid_book_size <= bid_book_size + 1; // Activate trailing buy
              else
                bid_stop_price[bid_book_size] <= bid_price[bid_book_size - 1] - order_data[31:28];
            end else begin
              if (order_data[27:20] >= ask_price[ask_book_size - 1])
                ask_book_size <= ask_book_size + 1; // Activate trailing sell
              else
                ask_stop_price[ask_book_size] <= ask_price[ask_book_size - 1] + order_data[31:28];
            end
          end
        endcase
        
        // Apply execution strategy
        case (order_data[3:2])
          AGGRESSIVE_STRATEGY: begin
            if (order_data[1:0] == LIMIT_ORDER) begin
              if (order_data[0] && ask_book_size > 0 &&
                  order_data[11:4] >= ask_price[ask_book_size - 1]) begin
                trade_data    <= {ask_price[ask_book_size - 1], order_data[19:12]};
                trade_valid   <= 1;
                ask_book_size <= ask_book_size - 1; // Cross aggressively on buy
              end else if (!order_data[0] && bid_book_size > 0 &&
                           order_data[11:4] <= bid_price[bid_book_size - 1]) begin
                trade_data    <= {bid_price[bid_book_size - 1], order_data[19:12]};
                trade_valid   <= 1;
                bid_book_size <= bid_book_size - 1; // Cross aggressively on sell
              end
            end
          end

          PASSIVE_STRATEGY: begin
            if (order_data[1:0] == LIMIT_ORDER) begin
              if (order_data[0])
                bid_book_size <= bid_book_size + 1; // Resting buy
              else
                ask_book_size <= ask_book_size + 1; // Resting sell
            end
          end

          ICEBERG_STRATEGY: begin
            if (order_data[1:0] == LIMIT_ORDER) begin
              if (order_data[0]) begin
                bid_book_size               <= bid_book_size + 1;
                bid_quantity[bid_book_size] <= order_data[31:28]; // Show only partial qty
              end else begin
                ask_book_size               <= ask_book_size + 1;
                ask_quantity[ask_book_size] <= order_data[31:28]; // Show only partial qty
              end
            end
          end

          VWAP_STRATEGY: begin
            // Placeholder for VWAP scheduling
          end
        endcase
      end

      // Match best bid and ask if they cross
      if (bid_book_size > 0 && ask_book_size > 0) begin
        if (bid_price[bid_book_size - 1] >= ask_price[ask_book_size - 1]) begin
          trade_data    <= {bid_price[bid_book_size - 1], bid_quantity[bid_book_size - 1]};
          trade_valid   <= 1;
          bid_book_size <= bid_book_size - 1;
          ask_book_size <= ask_book_size - 1;
        end else begin
          trade_valid   <= 0;
        end
      end else begin
        trade_valid     <= 0;
      end
      
      // Handle TCP commands
      if (tcp_rx_valid) begin
        case (tcp_rx_data[1:0])
          2'b01: begin
            if (tcp_rx_data[0])
              bid_book_size <= bid_book_size + 1; // New buy via TCP
            else
              ask_book_size <= ask_book_size + 1; // New sell via TCP
          end
          2'b10: begin
            // Order cancellation not yet implemented
          end
        endcase
      end

      // Send trade reports back over TCP
      tcp_tx_valid <= 0;
      if (trade_valid) begin
        tcp_tx_data  <= {2'b11, trade_data[29:0]};
        tcp_tx_valid <= 1;
      end

      // Drive AXI-Stream outputs
      s_axis_ready <= 1;
      m_axis_data  <= trade_data;
      m_axis_valid <= trade_valid;
    end
  end

endmodule
