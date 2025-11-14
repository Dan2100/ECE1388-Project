// Testbench for 1-cycle AU operations: ADD, SUB, MULT
`timescale 1ns/1ps

module au_basic_tb();
    parameter W = 24;
    parameter FRAC = 14;
    
    reg clk;
    reg [W-1:0] R_in, S_in, Iimm_in;
    reg [1:0] op_sel, mul_y_sel;
    reg start;
    wire [W-1:0] result;
    wire done, busy;

    // Instantiate AU
    au #(.W(W), .FRAC(FRAC)) dut (
        .clk(clk),
        .start(start),
        .R_in(R_in),
        .S_in(S_in),
        .Iimm_in(Iimm_in),
        .op_sel(op_sel),
        .mul_y_sel(mul_y_sel),
        .result(result),
        .done(done),
        .busy(busy)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Convert integer to S9.14 format
    function [W-1:0] to_fixed;
        input integer val;
        reg sign_bit;
        reg [W-2:0] magnitude;
        begin
            sign_bit = (val < 0);
            if (val < 0)
                val = -val;
            magnitude = val << FRAC;
            to_fixed = {sign_bit, magnitude};
        end
    endfunction

    // Convert S9.14 to real for display
    function real to_real;
        input [W-1:0] fixed_val;
        integer signed_mag;
        integer signed_val;
        begin
            signed_mag = fixed_val[W-2:0];
            signed_val = (fixed_val[W-1]) ? -signed_mag : signed_mag;
            to_real = signed_val / (16384.0); // 2^14
        end
    endfunction

    // Compare two sign-magnitude values (handles +0 vs -0)
    function values_match;
        input [W-1:0] a, b;
        begin
            // If both magnitudes are zero, they match regardless of sign
            if (a[W-2:0] == 0 && b[W-2:0] == 0)
                values_match = 1;
            else
                values_match = (a === b);
        end
    endfunction

    integer i, j;
    reg passed;
    reg [W-1:0] expected;

    initial begin
        start = 0;
        passed = 1;
        mul_y_sel = 2'b00; // Use S_in as Y
        Iimm_in = to_fixed(1);
        
        // Wait a few cycles
        repeat(3) @(posedge clk);

        $display("========================================");
        $display("Testing AU Basic Operations (1-cycle)");
        $display("========================================");

        // Test ADD operations
        $display("\n--- Testing ADD ---");
        op_sel = 2'b00; // ADD
        for (i = -4; i <= 4; i = i + 1) begin
            for (j = -4; j <= 4; j = j + 1) begin
                R_in = to_fixed(i);
                S_in = to_fixed(j);
                start = 1;
                @(posedge clk);
                start = 0;
                @(posedge clk); // Wait 1 cycle for result
                
                expected = to_fixed(i + j);
                if (!values_match(result, expected)) begin
                    passed = 0;
                    $display("FAIL: %0d + %0d = %.3f (expected %.3f, got %h, expected %h)", 
                             i, j, to_real(result), to_real(expected), result, expected);
                end
            end
        end
        $display("ADD tests completed");

        // Test SUB operations
        $display("\n--- Testing SUB ---");
        op_sel = 2'b01; // SUB
        for (i = -4; i <= 4; i = i + 1) begin
            for (j = -4; j <= 4; j = j + 1) begin
                R_in = to_fixed(i);
                S_in = to_fixed(j);
                start = 1;
                @(posedge clk);
                start = 0;
                @(posedge clk); // Wait 1 cycle for result
                
                expected = to_fixed(i - j);
                if (!values_match(result, expected)) begin
                    passed = 0;
                    $display("FAIL: %0d - %0d = %.3f (expected %.3f, got %h, expected %h)", 
                             i, j, to_real(result), to_real(expected), result, expected);
                end
            end
        end
        $display("SUB tests completed");

        // Test MULT operations
        $display("\n--- Testing MULT ---");
        op_sel = 2'b10; // MULT
        for (i = -4; i <= 4; i = i + 1) begin
            for (j = -4; j <= 4; j = j + 1) begin
                R_in = to_fixed(i);
                S_in = to_fixed(j);
                start = 1;
                @(posedge clk);
                start = 0;
                @(posedge clk); // Wait 1 cycle for result
                
                expected = to_fixed(i * j);
                if (!values_match(result, expected)) begin
                    passed = 0;
                    $display("FAIL: %0d * %0d = %.3f (expected %.3f, got %h, expected %h)", 
                             i, j, to_real(result), to_real(expected), result, expected);
                end
            end
        end
        $display("MULT tests completed");

        // Summary
        $display("\n========================================");
        if (passed)
            $display("ALL BASIC TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");
        $display("========================================\n");

        $finish;
    end
endmodule
