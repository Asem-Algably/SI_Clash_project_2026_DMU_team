// ============================================================================
// File Name   : bist_expected_rom.sv
// Module Name : bist_expected_rom
// Project     : SI-CLASH Real-Time Digital Synchronizer - ZCU106 BIST
// Description : Synchronous single-port BRAM ROM storing 1,199 lines of 32-bit
//               golden payload symbols:
//               {exp_sym_i[15:0] [31:16], exp_sym_q[15:0] [15:0]}
// ============================================================================

`timescale 1ns / 1ps

module bist_expected_rom #(
  parameter int unsigned ADDR_WIDTH = 11,
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned DEPTH      = 1199,
  parameter              INIT_FILE  = "bist_exp_vec.mem"
)(
  input  logic                            clk,
  input  logic                            en,
  input  logic [ADDR_WIDTH-1:0]           addr,
  output logic [DATA_WIDTH-1:0]           dout
);

  // Infer Block RAM primitive with registered output
  (* rom_style = "block" *) logic [DATA_WIDTH-1:0] rom [0:DEPTH-1];
  logic [DATA_WIDTH-1:0] dout_reg = '0;

  initial begin
    $readmemh(INIT_FILE, rom);
  end

  always_ff @(posedge clk) begin
    if (en) begin
      if (addr < DEPTH) begin
        dout_reg <= rom[addr];
      end else begin
        dout_reg <= '0;
      end
    end
  end

  assign dout = dout_reg;

endmodule
