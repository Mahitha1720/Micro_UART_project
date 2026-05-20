`timescale 1ns / 1ps

`include "UART_LOOPBACK.v"
`include "uart_ref_model.v"

module tb_uart;

parameter WORD = 8;
parameter CLK_FREQ = 50000000;
parameter BAUD = 2400;

reg sys_clk;
reg sys_rst_l;

reg xmitH;
reg [WORD-1:0] xmit_dataH;

wire rec_readyH;
wire uart_REC_dataH;
wire rec_busy;
wire [WORD-1:0] rec_dataH;
wire xmit_active;
wire xmit_doneH;

wire ref_rec_readyH;
wire ref_uart_REC_dataH;
wire ref_rec_busy;
wire [WORD-1:0] ref_rec_dataH;
wire ref_xmit_active;
wire ref_xmit_doneH;

integer pass_count;
integer fail_count;
integer test_count;
integer i;

UART_LOOPBACK #(
    .WORD(WORD),
    .CLK_FREQ(CLK_FREQ),
    .BAUD(BAUD)
) dut (
    .sys_clk(sys_clk),
    .sys_rst_l(sys_rst_l),

    .xmitH(xmitH),
    .xmit_dataH(xmit_dataH),

    .rec_readyH(rec_readyH),
    .uart_REC_dataH(uart_REC_dataH),
    .rec_busy(rec_busy),
    .rec_dataH(rec_dataH),

    .xmit_active(xmit_active),
    .xmit_doneH(xmit_doneH)
);

uart_ref_model #(
    .WORD(WORD)
) ref_model (
    .sys_clk(sys_clk),
    .sys_rst_l(sys_rst_l),

    .xmitH(xmitH),
    .xmit_dataH(xmit_dataH),

    .rec_readyH(ref_rec_readyH),
    .uart_REC_dataH(ref_uart_REC_dataH),
    .rec_busy(ref_rec_busy),
    .rec_dataH(ref_rec_dataH),

    .xmit_active(ref_xmit_active),
    .xmit_doneH(ref_xmit_doneH)
);

initial
begin
    sys_clk = 0;
    forever #10 sys_clk = ~sys_clk;
end

initial
begin
    $dumpfile("tb_uart.vcd");
    $dumpvars(0,tb_uart);
end

task send_data;
input [WORD-1:0] data;
begin

    @(posedge dut.B1.baud_clk);

    xmit_dataH = data;
    xmitH = 1'b1;

    @(posedge dut.B1.baud_clk);

    xmitH = 1'b0;

    wait(xmit_doneH == 1'b1);

    repeat(5) @(posedge dut.B1.baud_clk);

    test_count = test_count + 1;

    if(rec_dataH == ref_rec_dataH)
    begin
        $display("[PASS] DATA = %h DUT_RX = %h REF_RX = %h",
                 data,
                 rec_dataH,
                 ref_rec_dataH);

        pass_count = pass_count + 1;
    end
    else
    begin
        $display("[FAIL] DATA = %h DUT_RX = %h REF_RX = %h",
                 data,
                 rec_dataH,
                 ref_rec_dataH);

        fail_count = fail_count + 1;
    end

end
endtask

task reset_test;
begin

    sys_rst_l = 0;

    repeat(20) @(posedge sys_clk);

    sys_rst_l = 1;

    repeat(20) @(posedge sys_clk);

    test_count = test_count + 1;

    if((xmit_active == 0) &&
       (rec_busy == 0))
    begin
        $display("[PASS] RESET TEST");
        pass_count = pass_count + 1;
    end
    else
    begin
        $display("[FAIL] RESET TEST");
        fail_count = fail_count + 1;
    end

end
endtask

initial
begin

    pass_count = 0;
    fail_count = 0;
    test_count = 0;

    sys_rst_l = 0;
    xmitH = 0;
    xmit_dataH = 0;

    #200;

    sys_rst_l = 1;

    repeat(20) @(posedge dut.B1.baud_clk);

    reset_test();

    send_data(8'h00);
    send_data(8'hFF);
    send_data(8'hAA);
    send_data(8'h55);
    send_data(8'h0F);
    send_data(8'hF0);
    send_data(8'h81);
    send_data(8'h7E);

    for(i=0;i<100;i=i+1)
    begin
        send_data($random);
    end

    for(i=0;i<20;i=i+1)
    begin
        send_data(i);
    end

    @(posedge dut.B1.baud_clk);

    xmit_dataH = 8'h3C;
    xmitH = 1'b1;

    @(posedge dut.B1.baud_clk);

    xmitH = 1'b0;

    repeat(10) @(posedge dut.B1.baud_clk);

    sys_rst_l = 0;

    repeat(5) @(posedge dut.B1.baud_clk);

    sys_rst_l = 1;

    repeat(20) @(posedge dut.B1.baud_clk);

    send_data(8'hA5);

    $display("----------------------------------");
    $display("TOTAL TESTS = %0d", test_count);
    $display("PASS COUNT  = %0d", pass_count);
    $display("FAIL COUNT  = %0d", fail_count);
    $display("----------------------------------");

    #1000;

    $finish;

end

initial
begin

    #50000000;

    $display("SIMULATION TIMEOUT");

    $finish;

end

endmodule
