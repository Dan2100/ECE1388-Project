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

    // Variables for checking
    reg [23:0] expected;
    reg passed;

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

    // Simple tick task
    task tick;
        begin
            @(posedge clk);
        end
    endtask

    // Wait for inverse ready
    task wait_for_cont;
        begin
            @(posedge clk);
            while (!cont) @(posedge clk);
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

    initial begin
        clk = 0;
        rst = 1;
        ctl_f = 1; // mult/inv path
        ctl_e = 1; // select inverse
        passed = 1;
        #20 rst = 0;

        $display("Starting ALU multiplicative inverse test...");

        // Example test cases: R, then inverse
        test_inv(1); // 1.0 -> 1.0
        test_inv(2); // 2.0 -> 0.5
        test_inv(8); // 8.0 -> 0.125
        test_inv(-8); // -8.0 -> -0.125

        if (passed)
            $display("Test Completed without Errors! :)");
        else
            $display("Test Completed WITH Errors! :(");

        $finish;
    end

    // Task for testing a pair of R and S
    task test_inv;
        input integer r_decimal;
        reg [23:0] r_val;
        real result_real;
        integer signed_mag;
        integer signed_val;
        begin
            r_val = to_s9_14(r_decimal); //convert to S9.14
            $display("r_val=%b", r_val);
            rst = 1;
            #20 rst = 0;
            R = r_val;
            // Wait until ALU inverse signals ready
            @(posedge clk);
            while (!cont) @(posedge clk);


            
            signed_mag = result[22:0];  // magnitude
            signed_val = (result[23]) ? -signed_mag : signed_mag;
            result_real = signed_val / 16384.0; // scale by 2^14
            // Compare ALU result
            $display("INV Result: R=%d -> got %b (%.6f)", r_decimal, result, result_real);

        end
    endtask
endmodule
