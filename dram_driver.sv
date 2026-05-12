`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2025 11:42:01 AM
// Design Name: 
// Module Name: dram_driver
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dram_driver(
    input  logic         clk				,
    input  logic         rst				,

    input  logic [17:0]  perip_addr			,
    input  logic [31:0]  perip_wdata		,
	input  logic [1:0]	 perip_mask			,
    input  logic         dram_wen           ,
    output logic [31:0]  perip_rdata		
);
    logic [15:0] dram_addr;
    wire [ 1:0] offset;
    logic [31:0] dram_data, dram_rdata_raw, dout;
    reg [31:0] reg_dram_rdata_raw;

    reg [15:0] reg_addr;
    reg [1:0] reg_mask;
    reg [1:0] reg_offset;
    reg [31:0] reg_wdata;
    reg [31:0] reg_rdata_raw;
    reg reg_wen;

    assign offset = perip_addr[1:0];
    assign perip_rdata = dout;


    /*
    DRAM Mem_DRAM (
        .clk        (clk),
        .a          (dram_addr),
        .spo        (dram_rdata_raw),
        .we         (dram_wen),
        .d          (dram_data)
    );
    */

    blk_mem_gen_0 Mem_blk_DRAM (
        .clka        (clk),
        .addra          (dram_addr),
        .douta        (dram_rdata_raw),
        .wea         (reg_wen),
        .dina          (dram_data)
    );

    /* 正常读 */
    always_comb begin
        dout = reg_dram_rdata_raw;
    end
    always @(posedge clk) begin
        if (rst) begin
            reg_dram_rdata_raw <= 0;
        end
        else begin
            reg_dram_rdata_raw <= dram_rdata_raw;
        end
    end

    /* 延迟1周期写 */

    assign dram_addr = reg_wen ? reg_addr : perip_addr[17:2] ;
    
    //寄存信息
    always @(posedge clk) begin
        if (rst) begin
            reg_addr <= 0;
            reg_mask <= 0;
            reg_offset <= 0;
            reg_wdata <= 0;
            reg_rdata_raw <= 0;
            reg_wen <= 0;
        end
        else if (dram_wen) begin
            reg_addr <= perip_addr[17:2];
            reg_mask <= perip_mask;
            reg_offset <= perip_addr[1:0];
            reg_wdata <= perip_wdata;
            reg_rdata_raw <= dram_rdata_raw;
            reg_wen <= 1;
        end
        else begin
            reg_wen <= 0;
        end
    end

    // dram_data_raw process, sh, sb(全部使用寄存过的信号)
    always_comb begin
        case (reg_mask)
            2'b10: dram_data = reg_wdata;  // sw
            2'b01: begin           // sh
                case (reg_offset[1])
                    1'b0: dram_data = {reg_rdata_raw[31:16], reg_wdata[15:0]};
                    1'b1: dram_data = {reg_wdata[15:0], reg_rdata_raw[15:0]};
                endcase
            end
            2'b00: begin           // sb
                case (reg_offset)
                    2'b00: dram_data = {reg_rdata_raw[31:8], reg_wdata[7:0]};
                    2'b01: dram_data = {reg_rdata_raw[31:16], reg_wdata[7:0], reg_rdata_raw[7:0]};
                    2'b10: dram_data = {reg_rdata_raw[31:24], reg_wdata[7:0], reg_rdata_raw[15:0]};
                    2'b11: dram_data = {reg_wdata[7:0], reg_rdata_raw[23:0]};
                endcase
            end
            default: dram_data = reg_wdata;
        endcase
    end
endmodule
