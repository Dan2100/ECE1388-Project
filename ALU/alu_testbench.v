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

    initial begin
        clk = 0;
        rst = 1;
        ctl_f = 1; // mult/inv path
        ctl_e = 1; // select inverse
        passed = 1;
        #20 rst = 0;

        $display("Starting ALU multiplicative inverse test...");

        // Example test cases: R, then inverse
        test_inv(24'h004000); // 1.0 -> 1.0
        test_inv(24'h002000); // 0.5 -> 2.0
        test_inv(24'h008000); // 2.0 -> 0.5
        //test_inv(24'h004000); // 

        if (passed)
            $display("Test Completed without Errors! :)");
        else
            $display("Test Completed WITH Errors! :(");

        $finish;
    end

    // Task for testing a pair of R and S
    task test_inv;
        input [23:0] r_val;
        reg [47:0] product;
        begin
            R = r_val;
            // Wait until ALU inverse signals ready
            @(posedge clk);
            while (!cont) @(posedge clk);

            // Compare ALU result
            $display("INV Result: R=%h -> got %h", R, result);

        end
        #50;
endtask

endmodule
