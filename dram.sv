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
always @(*) begin
    dram_read({12'h801, 2'b00, a, 2'b00}, spo);
end

always @(posedge clk) begin
    if (we) begin
        dram_write({12'h801, 2'b00, a, 2'b00}, d);
    end
end

endmodule

module blk_mem_gen_0(
    input clka,
    input [15:0] addra,
    output [31:0] douta,
    input wea,
    input [31:0] dina
); 

import "DPI-C" function void dram_read(input int addr, output int data);
import "DPI-C" function void dram_write(input int addr, input int data);
/* 同步读，同步写 */
assign douta = reg_douta;

reg [31:0] reg_douta;
reg [31:0] temp_douta;

always @(*) begin
    dram_read({12'h801, 2'b00, addra, 2'b00}, temp_douta);
end

always @(posedge clka) begin
    reg_douta <= temp_douta;
    if (wea) begin
        dram_write({12'h801, 2'b00, addra, 2'b00}, dina);
    end
end


endmodule