// Testbench for AU multiplicative inverse (24-cycle operation)
`timescale 1ns/1ps

module au_inv_tb();
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

    // Task to test inverse operation
    task test_inverse;
        input integer val;
        real expected_real, result_real;
        real error;
        integer cycles;
        begin
            $display("\nTesting 1/%0d:", val);
            
            // Set up DIV operation (R * 1/S)
            R_in = to_fixed(1);  // R = 1.0
            S_in = to_fixed(val); // S = val
            op_sel = 2'b11;       // DIV operation
            mul_y_sel = 2'b10;    // Use reciprocal of S
            
            start = 1;
            @(posedge clk);
            start = 0;
            
            cycles = 0;
            // Wait for done signal (should take ~24 cycles)
            while (!done) begin
                @(posedge clk);
                cycles = cycles + 1;
                if (cycles < 5 || cycles % 10 == 0) 
                    $display("  cycle %0d: done=%b, busy=%b, recip_start=%b, recip_rdy=%b, recip_run=%b, state=%d", 
                             cycles, done, busy, dut.recip_start, dut.U_RECI.rdy, dut.U_RECI.run, dut.state);
                if (cycles > 100) begin
                    $display("  ✗ TIMEOUT - done never asserted!");
                    $finish;
                end
            end
            
            @(posedge clk);
            
            // Check result
            expected_real = 1.0 / val;
            result_real = to_real(result);
            error = ((result_real - expected_real) / expected_real) * 100.0;
            if (expected_real < 0) error = -error;
            
            $display("  S = %0d", val);
            $display("  Expected 1/S = %.6f", expected_real);
            $display("  Got result = %.6f", result_real);
            $display("  Error = %.2f%%", error);
            $display("  Cycles = %0d", cycles);
            
            if (error > 10.0 || error < -10.0) begin
                $display("  ✗ FAIL - Error too large!");
            end else begin
                $display("  ✓ PASS");
            end
        end
    endtask

    initial begin
        start = 0;
        Iimm_in = to_fixed(1);
        
        // Wait a few cycles
        repeat(3) @(posedge clk);

        $display("========================================");
        $display("Testing AU Multiplicative Inverse");
        $display("(24-cycle operation)");
        $display("========================================");

        // Test various inverse values
        test_inverse(1);   // 1/1 = 1.0
        test_inverse(2);   // 1/2 = 0.5
        test_inverse(4);   // 1/4 = 0.25
        test_inverse(8);   // 1/8 = 0.125
        test_inverse(-2);  // 1/-2 = -0.5
        test_inverse(-4);  // 1/-4 = -0.25

        $display("\n========================================");
        $display("Multiplicative Inverse Tests Completed");
        $display("========================================\n");

        $finish;
    end
endmodule
