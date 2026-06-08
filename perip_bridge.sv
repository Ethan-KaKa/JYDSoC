`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/22 10:25:24
// Design Name: 
// Module Name: perip_bridge
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

module perip_bridge(
    input  logic         clk				,
    input  logic         cnt_clk			,
    input  logic         rst                ,

    // DRAM 端口（地址分流已在 JYD_top 完成）
    input  logic [31:0]  dram_addr			,
    input  logic [31:0]  dram_wdata		,
    input  logic         dram_wen			,
	input  logic [1:0]	 dram_mask			,
    output logic [31:0]  dram_rdata		,

    // MMIO 端口
    input  logic [31:0]  mmio_addr			,
    input  logic [31:0]  mmio_wdata		,
    input  logic         mmio_wen			,
	input  logic [1:0]	 mmio_mask			,
    output logic [31:0]  mmio_rdata		,

    input  logic [63:0]  virtual_sw_input	,
    input  logic [7:0]   virtual_key_input	,

	output logic [39:0]  virtual_seg_output	,
    output logic [31:0]  virtual_led_output
);
    localparam SW0_ADDR  = 32'h8020_0000;  // sw[31:0]
    localparam SW1_ADDR  = 32'h8020_0004;  // sw[63:32]
    localparam KEY_ADDR  = 32'h8020_0010;  // key[7:0]
    localparam SEG_ADDR  = 32'h8020_0020;  // seg
    localparam LED_ADDR  = 32'h8020_0040;  // led[31:0]
    localparam CNT_ADDR  = 32'h8020_0050;  // counter

    logic [31:0] LED;
    logic [31:0] seg_wdata, cnt_rdata, mmio_mux_rdata;
    logic [39:0] seg_output;

    //从输入寄存判断出输出的类型（减少输出端延迟）
    reg is_SW0, is_SW1, is_KEY, is_SEG, is_CNT;
    always @(posedge clk) begin
        if (rst) begin
            is_SW0 <= 0;
            is_SW1 <= 0;
            is_KEY <= 0;
            is_SEG <= 0;
            is_CNT <= 0;
        end
        else begin
            is_SW0 <= mmio_addr == SW0_ADDR;
            is_SW1 <= mmio_addr == SW1_ADDR;
            is_KEY <= mmio_addr == KEY_ADDR;
            is_SEG <= mmio_addr == SEG_ADDR;
            is_CNT <= mmio_addr == CNT_ADDR;
        end
    end


    // we don't care mmio_mask in LED, SEG, SW & KEY
    // write process
    always_ff @(posedge clk) begin
        if (mmio_wen) begin
            case (mmio_addr)
                LED_ADDR:   LED <= mmio_wdata;
                SEG_ADDR:   seg_wdata <= mmio_wdata;
            endcase
        end
    end

    // read process: in one cycle
    always @(posedge clk) begin
        if (~mmio_wen) begin
            case (mmio_addr)
                SW0_ADDR:  mmio_mux_rdata <= virtual_sw_input[31:0];
                SW1_ADDR:  mmio_mux_rdata <= virtual_sw_input[63:32];
                KEY_ADDR:  mmio_mux_rdata <= {24'd0, virtual_key_input};
                SEG_ADDR:  mmio_mux_rdata <= seg_wdata;
                default:   mmio_mux_rdata <= 32'hDEAD_BEEF;
            endcase
        end else begin
            mmio_mux_rdata = 32'h0;
        end
    end

    // seg driver
    display_seg seg_driver (
        .clk    (clk),
        .rst    (rst),
        .s      (seg_wdata),
        .seg1   (seg_output[6:0]),
        .seg2   (seg_output[16:10]),
        .seg3   (seg_output[26:20]),
        .seg4   (seg_output[36:30]),
        .ans    ({seg_output[39:38], seg_output[29:28], seg_output[19:18], seg_output[9:8]})
    ); 
   
    assign seg_output[7]  = 0;
    assign seg_output[17] = 0;
    assign seg_output[27] = 0;
    assign seg_output[37] = 0;
    

    // dram rw（地址分流已在 JYD_top 完成，dram_wen 直接使用）
    dram_driver dram_driver_inst (
        .clk				(clk),
        .rst				(rst),
        .perip_addr			(dram_addr[17:0]),
        .perip_wdata		(dram_wdata),
        .perip_mask			(dram_mask),
        .dram_wen 			(dram_wen),
        .perip_rdata		(dram_rdata)
    );

    // counter rw
    counter counter_inst (
        .clk				(cnt_clk),
        .rst                (rst),
        .perip_wdata		(mmio_wdata),
        .cnt_wen 			(mmio_wen & (mmio_addr == CNT_ADDR)),
        .perip_rdata		(cnt_rdata)
    );


    assign mmio_rdata = {32{is_SW0}} & mmio_mux_rdata |
                        {32{is_SW1}} & mmio_mux_rdata |
                        {32{is_KEY}} & mmio_mux_rdata |
                        {32{is_SEG}} & mmio_mux_rdata |
                        {32{is_CNT}} & cnt_rdata;
    
    assign virtual_led_output = LED;
    assign virtual_seg_output = seg_output;

endmodule
