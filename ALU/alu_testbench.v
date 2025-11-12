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

    function [23:0] sm;
        input sign_bit;
        input [22:0] mag;
        sm = {sign_bit, mag};
    endfunction

    integer i;
    integer j;

    initial begin
        clk = 0;
        rst = 1;
        ctl_f = 0;
        ctl_e = 0;
        R = 0;
        S = 0;

        repeat(3) tick;
        rst = 0;
        tick;

        // Randomized tests
        for (i = 0; i < 20; i = i + 1) begin
            R = sm($random % 2, $random % (1<<23));
            S = sm($random % 2, $random % (1<<23));
            ctl_f = $random % 2;
            ctl_e = $random % 2;
            tick;
        end

        // Test inverse path explicitly
        R = sm(0, 23'd20000);
        S = sm(0, 23'd3000);
        ctl_f = 0;
        ctl_e = 0;
        tick;

        wait(cont == 1);
        tick;

        $finish;
    end
    reg passed;
    reg [23:0] expected;

    initial begin : init
        passed = 1;
        rst = 1;
        repeat(3) tick;
        rst = 0;
        tick;

        // Deterministic sweep for add/sub and mult
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                // construct sign-mag positives
                R = {1'b0, i[22:0]};
                S = {1'b0, j[22:0]};

                // test add/sub
                ctl_f = 1;
                ctl_e = 0;
                tick;
                expected = {1'b0,(i+j)};
                if (result !== expected) begin
                    passed = 0;
                    $display("ADD Failed %d + %d => got %d", i, j, result[22:0]);
                end

                // test mult
                ctl_f = 0;
                ctl_e = 0;
                tick;
                expected = {1'b0,(i*j)};
                if (result !== expected) begin
                    passed = 0;
                    $display("MULT Failed %d * %d => got %d", i, j, result[22:0]);
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
