`timescale 1ns/1ps

module tb_alu_mult_inv;

    // Inputs
    reg clk;
    reg rst;
    reg [23:0] R;
    reg [23:0] S;
    reg ctl_f;
    reg ctl_e;

    // Outputs
    wire [23:0] result;
    wire sign;
    wire cont;

    // Instantiate the ALU
    alu uut (
        .clk(clk),
        .rst(rst),
        .R(R),
        .S(S),
        .ctl_f(ctl_f),
        .ctl_e(ctl_e),
        .result(result),
        .sign(sign),
        .cont(cont)
    );

    // Clock generation: 10 ns period
    always #5 clk = ~clk;

    initial begin
        // Initialize inputs
        clk = 0;
        rst = 1;
        R = 24'h000100; // example input (1 in Q9.14)
        S = 24'h000000; // S is ignored for inv
        ctl_f = 1;      // select mult/inverse path
        ctl_e = 1;      // select inverse output
        #20;            // hold reset
        rst = 0;

        $display("Starting ALU multiplicative inverse test...");

        // Test 1: R = 1
        R = 24'h000100;
        wait_for_cont();
        
        // Test 2: R = 2
        R = 24'h000200;
        wait_for_cont();

        // Test 3: R = 0.5
        R = 24'h000080;
        wait_for_cont();

        // Test 4: R = 3
        R = 24'h000300;
        wait_for_cont();

        $display("All tests done.");
        $stop;
    end

    // Task to wait until cont goes high (inverse ready) and display result
    task wait_for_cont;
        begin
            @(posedge clk);
            while (!cont) @(posedge clk);
            $display("Time: %0t | Input R: %h | Inverse Result: %h | cont=%b", $time, R, result, cont);
            #10; // small delay before next test
        end
    endtask

endmodule