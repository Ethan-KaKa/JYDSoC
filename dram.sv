// =============================================================================
// blk_mem_gen_0 —— DRAM BRAM 的仿真模型（32768 x 64bit = 256KB，单口，同步读+同步写）
//
// ⚠ 这个模块【不是参照物，它就是 Verilator 仿真里的 DRAM】：npc 的 Makefile 把
//   JYDSoC/*.sv 直接编进 Verilator。它与 Vivado 的 blk_mem_gen IP 的任何行为差异，
//   都会表现为「difftest 全绿、上板错数据」—— 539cb1a 修的就是这类 bug。
//   改 IP 配置时，这里必须同步改。
//
// 位宽约定（与 dcache 的 8 字节块 / dram_driver 的 64 位 RMW 同源）：
//   douta[31:0]  = 行基址处的字        （byte addr[2] == 0）
//   douta[63:32] = 行基址 + 4 处的字   （byte addr[2] == 1）
//   即整行就是该 8 字节的小端整数——与 IROM(irom.sv) 的 slot0/slot1 约定同构，
//   也与 coe32_to_coe64.py 的打包规则（高地址进 MSB）一致。
//
// 写：BRAM 未开 byte-write-enable（wea 只有 1 位）⇒ 一次写整行。sb/sh/sw 的
//   read-modify-write 全部在 dram_driver 里完成，本模型只负责把 64 位整行落盘。
//
// 读时序：Read First（写拍 douta 给出的是写【前】的旧值），与当前 IP 配置一致。
// =============================================================================
module blk_mem_gen_0(
    input         clka,
    input  [14:0] addra,
    output [63:0] douta,
    input         wea,
    input  [63:0] dina
);

import "DPI-C" function void dram_read(input int addr, output int data);
import "DPI-C" function void dram_write(input int addr, input int data);

// ---------------------------------------------------------------------------
// 读延迟标定（R1）：本模型 = BRAM 同步读 RD_LATENCY 拍。dram_driver 的
// reg_dram_rdata_raw 再加 1 拍 ⇒ dram_addr → dram_rdata 共 RD_LATENCY+1 拍。
// JYD_top.v 的 DRAM_RD_DELAY 必须满足：受理→resp = DRAM_RD_DELAY+2 拍。
//
//   RD_LATENCY = 1（当前）  ⇒ 读 2 拍  ⇒ DRAM_RD_DELAY = 0
//   RD_LATENCY = 2          ⇒ 读 3 拍  ⇒ DRAM_RD_DELAY = 1
//
// ⚠ 若 Vivado 的 blk_mem_gen 为了在 200MHz 收敛而勾上了 Core/Primitives Output
//   Register（2Mb 阵列 + 64 位输出 mux，很可能需要），读延迟就是 3 拍：
//   必须【同时】把这里改成 2、把 DRAM_RD_DELAY 改成 1。漏改任何一个都不会报错，
//   只会在板上读到错位的数据。
// ---------------------------------------------------------------------------
localparam RD_LATENCY = 1;

// 行基址 = 0x8010_0000 + addra*8   （12 + 2 + 15 + 3 = 32 位）
wire [31:0] base_addr = {12'h801, 2'b00, addra, 3'b000};

logic [31:0] temp_lo, temp_hi;
logic [63:0] rd_pipe [0:RD_LATENCY-1];

assign douta = rd_pipe[RD_LATENCY-1];

/* 组合读出整行（DPI 一次只给 32 位，所以取两次） */
always @(*) begin
    dram_read(base_addr,         temp_lo);
    dram_read(base_addr + 32'd4, temp_hi);
end

integer i;
always @(posedge clka) begin
    // Read First：rd_pipe[0] 的 RHS 在 dram_write 生效【前】取值，写拍读出的是旧行
    rd_pipe[0] <= {temp_hi, temp_lo};
    for (i = 1; i < RD_LATENCY; i = i + 1)
        rd_pipe[i] <= rd_pipe[i-1];

    if (wea) begin
        dram_write(base_addr,         dina[31:0]);
        dram_write(base_addr + 32'd4, dina[63:32]);
    end
end

endmodule
