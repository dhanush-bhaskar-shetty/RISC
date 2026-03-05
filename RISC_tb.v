`timescale 1ns / 1ps


module tb_top;

reg clk;
reg reset;

// Instantiate 
top uut (
    .clk(clk),
    .reset(reset)
);

// Clock 10 ns period
always #5 clk = ~clk;

initial begin
    // Initialize
    clk   = 0;
    reset = 1;

    
    #20;
    reset = 0;

    
    #500;

    $stop;
end

endmodule
