`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: dram_driver
//
// DRAM(BRAM) 读写适配层。BRAM = 32768 x 64bit（256KB），单口，同步读 + 同步写。
//
// 读：一次返回【64 位整行】，不做字选。
//     字选由 dcache 完成（它的 dbank 仍是字宽，字偏移直接落在 BRAM 地址里，
//     一个 LUT 都不花），所以这里把整行原样交上去。
//       perip_rdata[31:0]  = 行基址处的字      (byte addr[2] == 0)
//       perip_rdata[63:32] = 行基址 + 4 处的字 (byte addr[2] == 1)
//
// 写：CPU 侧写通道仍是 32 位（perip_wdata 低位有效、未定位 + perip_mask 给 b/h/w）。
//     BRAM 没开 byte-write-enable（wea 只有 1 位）⇒ 一次写整行 ⇒ 【sb/sh/sw 全部
//     走 read-modify-write】。注意 sw 也要 RMW（不能直写），因为要保住同一行里
//     另外那 4 个字节。
//
//     RMW 的旧行一定是最新的，依据是 dcache 【写直通】：每条 store 都落 DRAM，
//     DRAM 里永远没有脏数据。
//
// 写时序（3 拍，与改宽前逐拍相同，JYD_top 的 WRITE_DELAY=1 与之对齐）：
//     B 拍  dram_wen=1        → 锁存 addr/mask/offset/wdata，置 reg_wen_delay
//                               （此拍 BRAM 地址端已是写地址，读已经发出）
//     C 拍  reg_wen_delay=1   → 捕获旧行 reg_rdata_raw，置 reg_wen
//     D 拍  reg_wen=1         → 合并后的整行写回，本拍末尾落盘
//     D 拍末 doing_delay 清零 ⇒ 下一拍 refill 才拿得到端口，无读写冲突。
//////////////////////////////////////////////////////////////////////////////////


module dram_driver(
    input  logic         clk				,
    input  logic         rst				,

    input  logic [17:0]  perip_addr			,
    input  logic [31:0]  perip_wdata		,
	input  logic [1:0]	 perip_mask			,
    input  logic         dram_wen           ,
    output logic [63:0]  perip_rdata
);
    logic [14:0] dram_addr;
    logic [63:0] dram_data, dram_rdata_raw, dout;
    reg [63:0] reg_dram_rdata_raw;

    reg [14:0] reg_addr;
    reg [1:0] reg_mask;
    reg [2:0] reg_offset;
    reg [31:0] reg_wdata;
    reg [63:0] reg_rdata_raw;
    reg reg_wen, reg_wen_delay;

    assign perip_rdata = dout;


    blk_mem_gen_0 Mem_blk_DRAM (
        .clka        (clk),
        .addra          (dram_addr),
        .douta        (dram_rdata_raw),
        .wea         (reg_wen),
        .dina          (dram_data)
    );

    /* 正常读：整行直通，只过一级寄存 */
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

    assign dram_addr = reg_wen ? reg_addr : perip_addr[17:3] ;

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
            reg_addr <= perip_addr[17:3];
            reg_mask <= perip_mask;
            reg_offset <= perip_addr[2:0];
            reg_wdata <= perip_wdata;

            reg_wen_delay <= 1;
        end
        else if (reg_wen_delay) begin
            reg_rdata_raw <= dram_rdata_raw;//整行读出（RMW 的旧值）

            reg_wen_delay <= 0;
            reg_wen <= 1;
        end
        else if (reg_wen) begin
            reg_wen <= 0;
        end
    end

    // RMW 合并（全部使用寄存过的信号：FF → 2~3 级 LUT → BRAM 的 D 脚，有整整一拍余量）
    //   ① 先按 reg_offset[2] 选出被写中的那个 32 位字
    //   ② 在字内按 mask + reg_offset[1:0] 做 sw/sh/sb 合并
    //   ③ 未被写中的那半行原样回写（BRAM 无 byte-enable，必须整行写）
    logic [31:0] old_word, new_word;

    assign old_word = reg_offset[2] ? reg_rdata_raw[63:32] : reg_rdata_raw[31:0];

    always_comb begin
        case (reg_mask)
            2'b10: new_word = reg_wdata;  // sw
            2'b01: begin           // sh
                case (reg_offset[1])
                    1'b0: new_word = {old_word[31:16], reg_wdata[15:0]};
                    1'b1: new_word = {reg_wdata[15:0], old_word[15:0]};
                endcase
            end
            2'b00: begin           // sb
                case (reg_offset[1:0])
                    2'b00: new_word = {old_word[31:8], reg_wdata[7:0]};
                    2'b01: new_word = {old_word[31:16], reg_wdata[7:0], old_word[7:0]};
                    2'b10: new_word = {old_word[31:24], reg_wdata[7:0], old_word[15:0]};
                    2'b11: new_word = {reg_wdata[7:0], old_word[23:0]};
                endcase
            end
            default: new_word = reg_wdata;
        endcase
    end

    assign dram_data = reg_offset[2] ? {new_word, reg_rdata_raw[31:0]}
                                     : {reg_rdata_raw[63:32], new_word};
endmodule
