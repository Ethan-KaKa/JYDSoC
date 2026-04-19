module DRAM(
    input clk,
    input [15:0] a,
    output [31:0] spo,
    input we,
    input [31:0] d
); 

import "DPI-C" function void dram_read(input int addr, output int data);
import "DPI-C" function void dram_write(input int addr, input int data);

/* 异步读，同步写 */
/*
always @(*) begin
    dram_read({12'h801, 2'b00, a, 2'b00}, spo);
end

always @(posedge clk) begin
    if (we) begin
        dram_write({12'h801, 2'b00, a, 2'b00}, d);
    end
end
*/

/* 同步读，同步写 */

always @(posedge clk) begin
    dram_read({12'h801, 2'b00, a, 2'b00}, spo);
    if (we) begin
        dram_write({12'h801, 2'b00, a, 2'b00}, d);
    end
end


endmodule