`timescale 1ns / 1ps

module risk_manager #(
  // Configurable switches for enabling/disabling checks
  parameter RISK_CHECK_EXPOSURE = 1,
  parameter RISK_CHECK_POSITION = 1,
  
  parameter DATA_WIDTH          = 32
)(
  input                          clk,                  // system clock
  input                          rst_n,                // active-low reset
  
  input      [DATA_WIDTH - 1 :0] trade_data,           // incoming trade size
  input                          trade_valid,          // trade request valid
  output reg                     trade_approved,       // approval result

  // Position tracking
  input      [DATA_WIDTH - 1 :0] position_update,      // delta to apply to position
  input                          position_update_valid,
  output reg [DATA_WIDTH - 1 :0] current_position,     // accumulated position

  // Exposure tracking
  input      [DATA_WIDTH - 1 :0] exposure_update,      // delta to apply to exposure
  input                          exposure_update_valid,
  output reg [DATA_WIDTH - 1 :0] current_exposure,     // accumulated exposure

  // External risk limits
  input      [DATA_WIDTH - 1 :0] max_exposure_limit,   // max allowable exposure
  input      [DATA_WIDTH - 1 :0] max_position_limit    // max allowable position
);
  // Main risk management process
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset state
      trade_approved     <= 1;
      current_position   <= 0;
      current_exposure   <= 0;
    end else begin
      // Accumulate position if update arrives
      if (position_update_valid) begin
        current_position <= current_position + position_update;
      end

      // Accumulate exposure if update arrives
      if (exposure_update_valid) begin
        current_exposure <= current_exposure + exposure_update;
      end

      // Validate new trade request
      if (trade_valid) begin
        if (RISK_CHECK_EXPOSURE) begin
          if (current_exposure + trade_data > max_exposure_limit) begin
            trade_approved <= 0;   // reject if exposure limit exceeded
          end else begin
            trade_approved <= 1;
          end
        end

        if (RISK_CHECK_POSITION) begin
          if (current_position + trade_data > max_position_limit) begin
            trade_approved <= 0;   // reject if position limit exceeded
          end else begin
            trade_approved <= 1;
          end
        end
      end else begin
        trade_approved <= 1;       // no trade means nothing to reject
      end
    end
  end

endmodule
