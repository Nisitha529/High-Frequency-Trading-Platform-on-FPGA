`timescale 1ns / 1ps

module risk_manager (
  input  wire        clk,                  // system clock
  input  wire        rst_n,                // active-low reset
  input  wire [31:0] trade_data,           // incoming trade size
  input  wire        trade_valid,          // trade request valid
  output reg         trade_approved,       // approval result

  // position tracking
  input  wire [31:0] position_update,      // delta to apply to position
  input  wire        position_update_valid,
  output reg  [31:0] current_position,     // accumulated position

  // exposure tracking
  input  wire [31:0] exposure_update,      // delta to apply to exposure
  input  wire        exposure_update_valid,
  output reg  [31:0] current_exposure,     // accumulated exposure

  // external risk limits
  input  wire [31:0] max_exposure_limit,   // max allowable exposure
  input  wire [31:0] max_position_limit    // max allowable position
);

  // configurable switches for enabling/disabling checks
  parameter RISK_CHECK_EXPOSURE = 1;
  parameter RISK_CHECK_POSITION = 1;

  // main risk management process
  always @(posedge clk) begin
    if (!rst_n) begin
      // reset state
      trade_approved   <= 1;
      current_position <= 0;
      current_exposure <= 0;
    end else begin
      // accumulate position if update arrives
      if (position_update_valid) begin
        current_position <= current_position + position_update;
      end

      // accumulate exposure if update arrives
      if (exposure_update_valid) begin
        current_exposure <= current_exposure + exposure_update;
      end

      // validate new trade request
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
