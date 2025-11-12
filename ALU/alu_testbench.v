// Testbench for Arithmetic Unit with randomized stimulus

`timescale 1ns/1ps

module alu_tb();
    reg clk, rst;
    reg [23:0] R, S;
    reg ctl_f, ctl_e;
    wire [23:0] result;
    wire sign;
    wire cont;

    alu dut (
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

    task tick;
    begin
        clk = 0; #5;
        clk = 1; #5;
    end
    endtask
    
    function [23:0] to_s9_14;
        input integer val; // e.g., -2, 1, etc.
        reg sign;
        reg [22:0] mag;
        begin
            sign = (val < 0);
            if (val < 0)
                val = -val;  // take absolute value
            mag = val << 14; // scale by 2^14
            to_s9_14 = {sign, mag};
        end
    endfunction

    integer i;
    integer j;
    reg passed;
    reg [23:0] expected;

    initial begin
        passed = 1;
        rst = 1;
        repeat(3) tick;
        rst = 0;
        tick;

        // Deterministic sweep for add/sub and mult
        for (i = -8; i < 8; i = i + 1) begin
            for (j = -8; j < 8; j = j + 1) begin
                // construct sign-mag positives
                R = to_s9_14(i);
                S = to_s9_14(j);
                
                //$display("R=%h, S=%h", R, S);

                // test add/sub
                ctl_f = 0;
                ctl_e = 0;
                tick;
                
                expected = to_s9_14(i+j);
                if (result !== expected) begin
                    passed = 0;
                    $display("ADD Failed %0d + %0d => got %0h expected %0h", i, j, result[23:0], expected[23:0]);
                end

                // test mult
                ctl_f = 1;
                ctl_e = 0;
                tick;
                expected = to_s9_14(i*j);
                if (result !== expected) begin
                    passed = 0;
                    $display("MULT Failed %0d * %0d => got %0h expected %0h", i, j, result[23:0], expected[23:0]);
                end
            end
        end

        if (passed)
            $display("Test Completed without Errors! :)");
        else
            $display("Test Completed WITH Errors! :(");

        $finish;
    end
endmodule
