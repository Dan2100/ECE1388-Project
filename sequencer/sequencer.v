module sequencer (
    input clk,
    input start,
    input reset,
    input cont,
    output ready,
    output [4:0] ctl_a,
    output [4:0] ctl_b,
    output [1:0] ctl_c,
    output [1:0] ctl_d,
    output ctl_e,
    output ctl_f,
    input p,
    input [7:0] addr,
    input [15:0] ctl
);

    wire [7:0] pc_out;
    
    seq u_seq (.clk(clk), .start(start), .reset(reset), .cont(cont), .ctl_c(ctl_c), .ready(ready), .pc_out(pc_out));
    
    control_word u_ctl (
    .dir(pc_out),
    .dout({ctl_a, ctl_b, ctl_c, ctl_d, ctl_e, ctl_f}),
    .p(p),
    .addr(addr),
    .ctl(ctl)
    );

endmodule

module seq (
    input clk,
    input start,
    input reset,
    input cont,
    input [1:0] ctl_c,
    output ready,
    output [7:0] pc_out
);
    wire [7:0] pc_inc;
    wire [7:0] pc_set;
    wire [7:0] pc_in;
//    wire [7:0] pc_out;
    wire pc_mux_sel;
    wire seq_reg_q;
    wire seq_reg_set;

    assign seq_reg_set = (~(&ctl_c)) | reset;

    assign ready = seq_reg_q;

    assign pc_in = (cont|seq_reg_q) ? pc_set : pc_inc;

    assign pc_inc = pc_out + 8'b1;

    assign pc_set = (seq_reg_set) ? 8'b0 : pc_out;

    seq_reg r0 (.clk(clk), .set(seq_reg_set), .clear(start), .q(seq_reg_q));
    pc_reg r_pc (.clk(clk), .w(cont), .din(pc_in), .q(pc_out));

//    control_word ctl_words (.dir(pc_out), .dout({ctl_a, ctl_b, ctl_c, ctl_d, ctl_e, ctl_f}), .p(p), .addr(addr), .ctl(ctl));

endmodule

module pc_reg (
    input clk,
    input w,
    input [7:0] din,
    output [7:0] q
);
    reg [7:0] reg_q;
    always @(posedge clk) begin
        if (w)
            reg_q <= din;
        else
            reg_q <= q;
    end
    assign q = reg_q;
endmodule

module seq_reg (
    input set,
    input clear,
    input clk,
    output q
);
    reg reg_q;
    always @(posedge clk) begin
        if (clear)
            reg_q <= 0;
        else if (set)
            reg_q <= 1;
    end
    assign q = reg_q;
endmodule


module control_word (
    input [7:0] dir,
    output [15:0] dout,
    input p,
    input [7:0] addr,
    input [15:0] ctl
);
    wire [15:0] q [0:255];
    genvar i;
    generate
        for (i=0; i<256; i=i+1) begin: gen_latches
            latch_16 u_latch (.p(addr==i[7:0] & p), .ctl(ctl), .word(q[i]));
        end
    endgenerate
    assign dout = q[dir];
endmodule

module latch_16 (
    input p,
    input [15:0] ctl,
    output [15:0] word
);
    reg [15:0] data;
    always @(*) begin
        if (p)
            data <= ctl;
        else
            data <= data;
    end
    assign word = data;
endmodule


