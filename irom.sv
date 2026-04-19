module IROM(
    input clk,
    input [11:0] a,
    output [31:0] spo
);

import "DPI-C" function void irom_read(input int addr, output int data);

/* 异步读 */

always @(*) begin
    irom_read({16'h8000, 2'b0000, a, 2'b00}, spo);
end

/* 同步读 (待支持) */
/*
always @(posedge clk) begin
    irom_read({16'h8000, 2'b0000, a, 2'b00}, spo);
end
*/

endmodule