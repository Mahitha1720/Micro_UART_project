`timescale 1ns / 1ps

`include "uart_ref_model.v"
`include "UART_LOOPBACK.v"

module tb_uart;

    parameter data_width = 8;
    parameter CLK_FREQ   = 50000000;
    parameter BAUD       = 9600;

    reg                   sys_clk;
    reg                   sys_rst;
    reg                   xmitH;
    reg  [data_width-1:0] xmit_dataH;
    reg                   tb_rx_data;

    wire                  dut_xmit_doneH;
    wire                  dut_xmit_active;
    wire                  dut_uart_serial;
    wire                  dut_rec_readyh;
    wire                  dut_rec_busy;
    wire [data_width-1:0] dut_rec_datah;

    wire                  ref_xmit_doneH;
    wire                  ref_xmit_active;
    wire                  ref_uart_serial;
    wire                  ref_rec_readyh;
    wire                  ref_rec_busy;
    wire [data_width-1:0] ref_rec_datah;
    wire                  ref_uart_clk;

    UART_LOOPBACK #(
        .WORD     (data_width),
        .CLK_FREQ (CLK_FREQ),
        .BAUD     (BAUD)
    ) dut (
        .sys_clk         (sys_clk),
        .sys_rst_l       (sys_rst),
        .xmitH           (xmitH),
        .xmit_dataH      (xmit_dataH),
        .uart_REC_dataH  (dut_uart_serial),
        .rec_readyH      (dut_rec_readyh),
        .rec_busy        (dut_rec_busy),
        .rec_dataH       (dut_rec_datah),
        .xmit_active     (dut_xmit_active),
        .xmit_doneH      (dut_xmit_doneH)
    );

    uart_ref_model #(
        .clk_value  (CLK_FREQ),
        .baud       (BAUD),
        .data_width (data_width)
    ) ref (
        .sys_clk         (sys_clk),
        .sys_rst_l       (sys_rst),
        .xmitH           (xmitH),
        .xmit_dataH      (xmit_dataH),
        .uart_REC_dataH  (tb_rx_data),
        .uart_XMIT_dataH (ref_uart_serial),
        .xmit_doneH      (ref_xmit_doneH),
        .xmit_active     (ref_xmit_active),
        .rec_readyH      (ref_rec_readyh),
        .rec_busyH       (ref_rec_busy),
        .rec_dataH       (ref_rec_datah),
        .uart_clk_out    (ref_uart_clk)
    );

    integer pass_count;
    integer fail_count;
    integer test_count;

    initial begin
        sys_clk = 0;
        forever #10 sys_clk = ~sys_clk;
    end

    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, tb_uart);
    end

    function compare_tx;
        input d_done, d_active, d_serial;
        input r_done, r_active, r_serial;
        begin
            compare_tx = (d_done   === r_done) &&
                         (d_active === r_active) &&
                         (d_serial === r_serial);
        end
    endfunction

    function compare_rx;
        input d_ready, d_busy;
        input [data_width-1:0] d_data;
        input r_ready, r_busy;
        input [data_width-1:0] r_data;
        begin
            compare_rx = (d_ready === r_ready) &&
                         (d_busy  === r_busy) &&
                         (d_data  === r_data);
        end
    endfunction

    task sc_delay;
        input integer n;
        integer j;
        begin
            for (j = 0; j < n; j = j + 1)
                @(posedge sys_clk);
        end
    endtask

    task bc_delay;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                @(posedge ref_uart_clk);
        end
    endtask

    task wait_tx_done;
        begin
            wait(dut_xmit_active == 0);
            wait(ref_xmit_active == 0);
            bc_delay(4);
        end
    endtask

    task wait_rx_ready;
        integer t;
        begin
            t = 0;
            while (t < 100000) begin
                @(posedge sys_clk);
                if (dut_rec_readyh == 1'b1 &&
                    ref_rec_readyh == 1'b1)
                    disable wait_rx_ready;
                t = t + 1;
            end
            $display("ERROR: RX timeout");
        end
    endtask

    task check_pass;
        input ok;
        input [200:1] name;
        begin
            test_count = test_count + 1;

            if (ok) begin
                pass_count = pass_count + 1;
                $display("[PASS] %s", name);
            end
            else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %s", name);
            end
        end
    endtask

    task tx_send;
        input [data_width-1:0] data;
        begin
            wait(dut_xmit_active == 0);
            wait(ref_xmit_active == 0);

            bc_delay(1);

            xmit_dataH = data;
            xmitH      = 1'b1;

            bc_delay(1);

            xmitH = 1'b0;
        end
    endtask

    task apply_tx_test;
        input [data_width-1:0] data;
        input [200:1] tname;
        begin
            tx_send(data);

            wait_tx_done;

            check_pass(
                compare_tx(
                    dut_xmit_doneH,
                    dut_xmit_active,
                    dut_uart_serial,
                    ref_xmit_doneH,
                    ref_xmit_active,
                    ref_uart_serial
                ),
                tname
            );
        end
    endtask

    task rx_send_frame;
        input [data_width-1:0] data;

        integer i;
        reg [data_width-1:0] tmp;

        begin
            tmp = data;

            tb_rx_data = 1'b0;
            bc_delay(16);

            for (i = 0; i < data_width; i = i + 1) begin
                tb_rx_data = tmp[0];
                tmp = tmp >> 1;
                bc_delay(16);
            end

            tb_rx_data = 1'b1;
            bc_delay(16);
        end
    endtask

    task apply_rx_test;
        input [data_width-1:0] data;
        input [200:1] tname;

        begin
            rx_send_frame(data);

            wait_rx_ready;

            bc_delay(4);

            check_pass(
                compare_rx(
                    dut_rec_readyh,
                    dut_rec_busy,
                    dut_rec_datah,
                    ref_rec_readyh,
                    ref_rec_busy,
                    ref_rec_datah
                ),
                tname
            );
        end
    endtask

    task test_reset;
        begin

            sys_rst = 0;

            sc_delay(100);

            check_pass(
                dut_xmit_active == 0 &&
                dut_xmit_doneH == 0,
                "RESET: TX inactive"
            );

            check_pass(
                dut_rec_busy == 0,
                "RESET: RX inactive"
            );

            check_pass(
                dut_uart_serial == 1'b1,
                "RESET: TX idle high"
            );

            sys_rst = 1;

            sc_delay(100);

            check_pass(
                dut_rec_readyh == 1,
                "RESET: RX ready after release"
            );
        end
    endtask

    task test_transmitter;
        begin

            apply_tx_test(8'hCD, "TX 0xCD");
            apply_tx_test(8'h00, "TX 0x00");
            apply_tx_test(8'hFF, "TX 0xFF");
            apply_tx_test(8'hAA, "TX 0xAA");
            apply_tx_test(8'h55, "TX 0x55");
            apply_tx_test(8'hF0, "TX 0xF0");
            apply_tx_test(8'h0F, "TX 0x0F");
            apply_tx_test(8'h01, "TX 0x01");
            apply_tx_test(8'h80, "TX 0x80");

            tx_send(8'hA5);

            check_pass(
                dut_xmit_active == 1,
                "TX active asserted"
            );

            wait_tx_done;

            tx_send(8'h3C);

            wait(dut_xmit_doneH == 1);

            check_pass(
                dut_xmit_doneH == 1,
                "TX done asserted"
            );

            wait_tx_done;

            wait(dut_xmit_active == 0);

            xmit_dataH = 8'h55;
            xmitH      = 1'b1;

            bc_delay(1);

            xmitH = 1'b0;

            bc_delay(30);

            xmit_dataH = 8'hAA;

            wait_tx_done;

            check_pass(
                dut_uart_serial == ref_uart_serial,
                "TX ignores mid-transfer change"
            );

        end
    endtask

    task test_receiver;

        integer i;
        reg [7:0] tmp;

        begin

            apply_rx_test(8'hCD, "RX 0xCD");
            apply_rx_test(8'h00, "RX 0x00");
            apply_rx_test(8'hFF, "RX 0xFF");
            apply_rx_test(8'hAA, "RX 0xAA");
            apply_rx_test(8'h55, "RX 0x55");

            tmp = 8'h55;

            tb_rx_data = 1'b0;
            bc_delay(16);

            for(i=0;i<8;i=i+1) begin
                tb_rx_data = tmp[0];
                tmp = tmp >> 1;
                bc_delay(16);
            end

            tb_rx_data = 1'b0;

            bc_delay(16);

            tb_rx_data = 1'b1;

            bc_delay(20);

            check_pass(
                dut_rec_datah == ref_rec_datah,
                "RX framing error"
            );

            tb_rx_data = 1'b0;

            bc_delay(2);

            tb_rx_data = 1'b1;

            bc_delay(20);

            check_pass(
                dut_rec_busy == 0,
                "RX glitch reject"
            );

        end
    endtask

    task test_loopback;

        reg [7:0] lb;

        begin

            lb = 8'h4F;
            tx_send(lb);

            wait_tx_done;
            wait_rx_ready;

            check_pass(
                dut_rec_datah == lb,
                "LB 0x4F"
            );

            lb = 8'hA3;
            tx_send(lb);

            wait_tx_done;
            wait_rx_ready;

            check_pass(
                dut_rec_datah == lb,
                "LB 0xA3"
            );

            lb = 8'hFF;
            tx_send(lb);

            wait_tx_done;
            wait_rx_ready;

            check_pass(
                dut_rec_datah == lb,
                "LB 0xFF"
            );

        end
    endtask

    task test_reset_mid_tx;
        begin

            tx_send(8'h5A);

            bc_delay(20);

            sys_rst = 0;

            sc_delay(10);

            check_pass(
                dut_xmit_active == 0,
                "Reset clears TX"
            );

            sys_rst = 1;

            sc_delay(50);

        end
    endtask

    task test_reset_mid_rx;
        begin

            tb_rx_data = 1'b0;

            bc_delay(10);

            sys_rst = 0;

            sc_delay(10);

            check_pass(
                dut_rec_busy == 0,
                "Reset clears RX"
            );

            sys_rst = 1;

            bc_delay(30);

        end
    endtask

    task test_random;
        integer i;
        reg [7:0] r;
        begin

            for(i=0;i<30;i=i+1) begin

                r = $random;

                apply_tx_test(r, "Random TX");

                apply_rx_test(r, "Random RX");

            end

        end
    endtask

    initial begin

        pass_count = 0;
        fail_count = 0;
        test_count = 0;

        sys_rst    = 0;
        xmitH      = 0;
        xmit_dataH = 8'h00;
        tb_rx_data = 1'b1;

        sc_delay(10);

        sys_rst = 1;

        sc_delay(200);

        test_reset;

        test_transmitter;

        test_receiver;

        test_loopback;

        test_reset_mid_tx;

        test_reset_mid_rx;

        test_random;

        $display("================================");

        $display("TOTAL : %0d", test_count);
        $display("PASS  : %0d", pass_count);
        $display("FAIL  : %0d", fail_count);

        if(fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $display("================================");

        #100;

        $finish;

    end

    initial begin
        #700_000_000;

        $display("[WATCHDOG] TIMEOUT");

        $finish;
    end

endmodule
