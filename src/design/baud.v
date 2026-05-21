//baud 
`include "inc.h"
module baud #(parameter freq=`freq,baudr=`baudr)(
    input sys_clk,
    input sys_rst,
    output reg uart_clk
    );
    localparam endcount=(freq/(baudr*16*2));
    reg [$clog2(endcount)-1:0] count=0;
    always @(posedge sys_clk or negedge sys_rst)
        begin   
            if(!sys_rst) begin uart_clk <=0;count<=0; end
            else if(count == endcount-1) begin uart_clk <= ~uart_clk;count<=0;end
            else count <= count+1;
        end       
endmodule
