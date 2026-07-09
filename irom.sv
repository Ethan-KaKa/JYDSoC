module IROM(
    input clk,
    input [10:0] a,
    output [63:0] spo
);

import "DPI-C" function void irom_read(input int addr, output int data);

/* 一次取回一个 8 字节组：spo[31:0] = 组基址处指令(slot0)，spo[63:32] = 基址+4(slot1) */
wire [31:0] base_addr = {16'h8000, 2'b00, a, 3'b000};

reg [31:0] inst_lo;
reg [31:0] inst_hi;

assign spo = {inst_hi, inst_lo};

/* 异步读 */

always @(*) begin
    irom_read(base_addr,         inst_lo);
    irom_read(base_addr + 32'd4, inst_hi);
end

/* 同步读 (待支持) */
/*
always @(posedge clk) begin
    irom_read(base_addr,         inst_lo);
    irom_read(base_addr + 32'd4, inst_hi);
end
*/

endmodule
