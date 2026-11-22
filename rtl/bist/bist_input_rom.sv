// ============================================================================
// File Name   : bist_input_rom.sv
// Module Name : bist_input_rom
// Project     : SI-CLASH Real-Time Digital Synchronizer - ZCU106 BIST
// Description : Synchronous single-port BRAM ROM storing 5,624 lines of 26-bit
//               packed input vectors:
//               {in_sample_valid [25], start_of_burst [24],
//                in_sample_i[11:0] [23:12], in_sample_q[11:0] [11:0]}
// ============================================================================

`timescale 1ns / 1ps

module bist_input_rom #(
  parameter int unsigned ADDR_WIDTH = 13,
  parameter int unsigned DATA_WIDTH = 26,
  parameter int unsigned DEPTH      = 5624,
  parameter              INIT_FILE  = "bist_input_vec.mem"
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
