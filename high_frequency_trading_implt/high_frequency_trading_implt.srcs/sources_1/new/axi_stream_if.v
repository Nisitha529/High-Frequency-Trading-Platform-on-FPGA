module axi_stream_if #(
  parameter DATA_WIDTH = 32,
  parameter DEST_WIDTH = 4,
  parameter USER_WIDTH = 4,
  parameter ID_WIDTH   = 4,
  parameter HAS_STRB   = 0,
  parameter HAS_KEEP   = 0,
  parameter HAS_LAST   = 1,
  parameter HAS_DEST   = 0,
  parameter HAS_USER   = 0,
  parameter HAS_ID     = 0
)(
  // Clock and reset
  input  wire                        aclk,
  input  wire                        aresetn,

  // AXI-Stream payload
  input  wire [DATA_WIDTH-1:0]       tdata,
  input  wire [DEST_WIDTH-1:0]       tdest,
  input  wire [USER_WIDTH-1:0]       tuser,
  input  wire [ID_WIDTH-1:0]         tid,
  input  wire [(DATA_WIDTH/8)-1:0]   tstrb,
  input  wire [(DATA_WIDTH/8)-1:0]   tkeep,
  input  wire                        tlast,
  input  wire                        tvalid,
  output wire                        tready
);

  assign tready = 1'b1;

  always @(posedge aclk) begin
    if (tvalid && tready) begin
      $display("AXIS transfer: data=%h, dest=%h, user=%h, id=%h, strb=%h, keep=%h, last=%b",
                tdata, tdest, tuser, tid, tstrb, tkeep, tlast);
    end
  end

endmodule
