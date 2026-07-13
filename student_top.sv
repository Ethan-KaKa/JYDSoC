`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/16/2025 06:21:13 PM
// Design Name: 
// Module Name: student_top
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


module student_top#(
    parameter                           P_SW_CNT            = 64,
    parameter                           P_LED_CNT           = 32,
    parameter                           P_SEG_CNT           = 40,
    parameter                           P_KEY_CNT           = 8
) (
    input                                       w_cpu_clk     ,
    input                                       w_clk_50Mhz   ,
    input                                       w_clk_rst     ,
    input  [P_KEY_CNT - 1:0]                    virtual_key   ,
    input  [P_SW_CNT  - 1:0]                    virtual_sw    ,

    output [P_LED_CNT - 1:0]                    virtual_led   ,
    output [P_SEG_CNT - 1:0]                    virtual_seg   
);

    // IROM
    logic [31:0] pc;
    logic [10:0] inst_addr;
    logic [63:0] instruction;

    // perip: DRAM 端口 + MMIO 端口
    // DRAM 读一次回 64 位整行（dcache 的块 = 8 字节）；写通道仍是 32 位
    logic [31:0] dram_addr, dram_wdata;
    logic [63:0] dram_rdata;
    logic        dram_wen;
    logic [1:0]  dram_mask;
    logic [31:0] mmio_addr, mmio_wdata, mmio_rdata;
    logic        mmio_wen;
    logic [1:0]  mmio_mask;

    // 16KB = 2^11 * 64bit
    assign inst_addr = pc[13:3];

    myCPU Core_cpu (
        .cpu_rst            (w_clk_rst),
        .cpu_clk            (w_cpu_clk),

        // Interface to IROM
        .irom_addr          (pc),             
        .irom_data          (instruction),   

        // Interface to DRAM
        .dram_addr          (dram_addr),
        .dram_wen           (dram_wen),
        .dram_mask          (dram_mask),
        .dram_wdata         (dram_wdata),
        .dram_rdata         (dram_rdata),

        // Interface to MMIO peripherals
        .mmio_addr          (mmio_addr),
        .mmio_wen           (mmio_wen),
        .mmio_mask          (mmio_mask),
        .mmio_wdata         (mmio_wdata),
        .mmio_rdata         (mmio_rdata)
    );

    IROM Mem_IROM (
        .clk        (w_cpu_clk),
        .a          (inst_addr),
        .spo        (instruction)
    );
    
    perip_bridge bridge_inst (
        .clk				(w_cpu_clk),
        .cnt_clk            (w_clk_50Mhz),
        .rst                (w_clk_rst),
        .dram_addr			(dram_addr),
        .dram_wdata			(dram_wdata),
        .dram_wen			(dram_wen),
        .dram_mask			(dram_mask),
        .dram_rdata			(dram_rdata),
        .mmio_addr			(mmio_addr),
        .mmio_wdata			(mmio_wdata),
        .mmio_wen			(mmio_wen),
        .mmio_mask			(mmio_mask),
        .mmio_rdata			(mmio_rdata),
        .virtual_sw_input	(virtual_sw),
        .virtual_key_input	(virtual_key),	
        .virtual_seg_output	(virtual_seg),
        .virtual_led_output (virtual_led)
    );

endmodule
