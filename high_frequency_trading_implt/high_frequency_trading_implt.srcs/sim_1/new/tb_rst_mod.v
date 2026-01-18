`timescale 1ns/1ps

module tb_reset_idelayctrl;

    // Parameters
    localparam CLK_PERIOD = 10;
    localparam kDlyRstDelay = 8;

    // Signals
    reg RefClk;
    reg rIntRst;
    wire rDlyRst;

    // DUT instance (VHDL module can be mixed with Verilog in most simulators)
    reset_idelayctrl #(
        .kDlyRstDelay(kDlyRstDelay)
    ) dut (
        .RefClk(RefClk),
        .rIntRst(rIntRst),
        .rDlyRst(rDlyRst)
    );

    // Clock generation
    initial begin
        RefClk = 0;
        forever #(CLK_PERIOD/2) RefClk = ~RefClk;
    end

    // Stimulus
    initial begin
        $display("Simulation started...");
        rIntRst = 0;
        #(5);

        // Apply reset pulse
        rIntRst = 1;
        #(3*CLK_PERIOD);
        rIntRst = 0;

        // Wait for countdown
        #(100);

        // Apply another reset pulse
        rIntRst = 1;
        #(2*CLK_PERIOD);
        rIntRst = 0;

        #(100);
        $display("Simulation finished.");
        $stop;
    end

    // Monitor outputs
    initial begin
        $monitor("Time=%0t | rIntRst=%b | rDlyRst=%b", $time, rIntRst, rDlyRst);
    end

endmodule
