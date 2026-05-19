`timescale 1ns/1ps

module tb_uart;

parameter freq=50000000;
parameter baudr=2400;
parameter width=8;

reg sys_clk;
reg sys_rst;
reg xmit_h;
reg [width-1:0] xmit_data_h;
reg uart_rec_data_h;

wire uart_clk;
wire uart_xmit_data_h;
wire xmit_done_h;
wire [width-1:0] rec_data_h;
wire rec_ready;
wire rec_busy;
wire xmit_active;

integer pass_count=0;
integer fail_count=0;
integer test_count=0;

uart #(.freq(freq),.baudr(baudr),.width(width)) dut(
.sys_clk(sys_clk),
.sys_rst(sys_rst),
.xmit_h(xmit_h),
.xmit_data_h(xmit_data_h),
.uart_rec_data_h(uart_rec_data_h),
.uart_clk(uart_clk),
.uart_xmit_data_h(uart_xmit_data_h),
.xmit_done_h(xmit_done_h),
.rec_data_h(rec_data_h),
.rec_ready(rec_ready),
.rec_busy(rec_busy),
.xmit_active(xmit_active)
);

initial begin
    sys_clk=0;
    forever #10 sys_clk=~sys_clk;
end

initial begin

    sys_rst=0;
    xmit_h=0;
    xmit_data_h=0;
    uart_rec_data_h=1;

    #100;
    sys_rst=1;

    @(posedge sys_clk);

    $display("\n===== UART LOOPBACK TEST =====\n");

    uart_send(8'hA5,"TEST1_A5");
    uart_send(8'h3C,"TEST2_3C");
    uart_send(8'hF0,"TEST3_F0");
    uart_send(8'h55,"TEST4_55");

    $display("\n===== TEST SUMMARY =====");
    $display("TOTAL=%0d",test_count);
    $display("PASS=%0d",pass_count);
    $display("FAIL=%0d",fail_count);

    #1000;
    $finish;

end

task uart_send;

input [width-1:0] data;
input [80*8:1] test_name;

begin

    @(posedge uart_clk);

    xmit_data_h=data;
    xmit_h=1'b1;

    @(posedge uart_clk);
    xmit_h=1'b0;

    wait(rec_busy==1'b1);
    wait(rec_busy==1'b0);

    @(posedge uart_clk);

    test_count=test_count+1;

    if(rec_data_h==data) begin
        $display("[PASS] %s DATA=0x%h RECEIVED=0x%h",test_name,data,rec_data_h);
        pass_count=pass_count+1;
    end
    else begin
        $display("[FAIL] %s DATA=0x%h RECEIVED=0x%h",test_name,data,rec_data_h);
        fail_count=fail_count+1;
    end

end
endtask

initial begin
    $dumpfile("uart.vcd");
    $dumpvars(0,tb_uart);
end

endmodule
