// ============================================================================
// File Name   : tb_fpga_bist_top.sv
// Module Name : tb_fpga_bist_top
// Project     : SI-CLASH Real-Time Digital Synchronizer - ZCU106 BIST
// Description : Full QuestaSim verification testbench for fpga_bist_top.
//               Validates:
//               1. Power-on reset sequence & autonomous vector streaming.
//               2. STR acquisition, Costas acquisition, and TRACK entry.
//               3. Bit-exact comparison of all 1,199 payload symbols.
//               4. GPIO LED states: ALL_PASSED=1, ERROR=0, STR_LOCK=1, COSTAS_LOCK=1.
//               5. 7-segment display status: status_code=0xAA, count=0xAF ("AA AF").
//               6. Pushbutton SW14 restart capability.
// ============================================================================

`timescale 1ns / 1ps

module tb_fpga_bist_top;

  localparam time CLK_PERIOD = 5.0ns; // 200.00 MHz
  localparam int  FAST_PRESCALER = 50;

  logic       clk_125_p = 1'b0;
  logic       clk_125_n;
  logic       btn_sw14  = 1'b0;

  logic [7:0] gpio_led;
  logic [6:0] pmod_seg_o;
  logic       pmod_dp_o;
  logic [3:0] pmod_an_o;

  // 200 MHz differential clock generation
  always #(CLK_PERIOD / 2.0) clk_125_p = ~clk_125_p;
  assign clk_125_n = ~clk_125_p;

  // Device Under Test
  fpga_bist_top #(
    .SIM_BYPASS_MMCM   (1'b1),
    .CLK_GEN_PRIMITIVE (0),
    .CATHODE_ACTIVE_LOW(1'b1),
    .ANODE_ACTIVE_LOW  (1'b1),
    .PRESCALER_LIMIT   (FAST_PRESCALER),
    .INPUT_ROM_FILE    ("bist_input_vec.mem"),
    .EXP_ROM_FILE      ("bist_exp_vec.mem"),
    .ENABLE_DEBUG_CORES(1'b0)
  ) dut_top (
    .clk_125_p  (clk_125_p),
    .clk_125_n  (clk_125_n),
    .btn_sw14   (btn_sw14),
    .gpio_led   (gpio_led),
    .pmod_seg_o (pmod_seg_o),
    .pmod_dp_o  (pmod_dp_o),
    .pmod_an_o  (pmod_an_o)
  );

  // ==========================================================================
  // Probed DUT Internal Signals for Easy Waveform Inspection (Hierarchical Dot Operator)
  // ==========================================================================
  // 1. 7-Segment Pre-Decoded Display Word & Status Codes
  logic [15:0] display_word;       // Raw 16-bit word driving 7-seg display (Hex: 0xAAAF)
  logic [7:0]  status_code;        // Upper byte: 0x00=RST, 0x01=STR, 0x02=Costas, 0x05=Track, 0xAA=PASS, 0xEE=ERR
  logic [7:0]  display_lower_byte; // Lower byte: Pass count LSB or failing address on error
  logic [3:0]  bist_fsm_state;     // Current BIST state (0=RESET, 1=FEED, 2=DRAIN, 10=DONE)
  logic [15:0] pass_count;         // Total symbols verified bit-accurately (counts to 1199)
  logic [15:0] error_count;        // Mismatch error count (remains 0 on pass)
  logic        all_passed;         // Overall PASS register (1 = passed)
  logic        error_latch;        // Mismatch sticky error latch (0 = no error)

  assign display_word       = dut_top.display_word;
  assign status_code        = dut_top.status_code;
  assign display_lower_byte = dut_top.display_lower_byte;
  assign bist_fsm_state     = dut_top.bist_state_q;
  assign pass_count         = dut_top.pass_count_q;
  assign error_count        = dut_top.err_count_q;
  assign all_passed         = dut_top.all_passed_q;
  assign error_latch        = dut_top.error_latch_q;

  // 2. ASCII representation of the 4 Display Digits for direct reading in Waveform
  function automatic [7:0] hex_to_ascii(input [3:0] nibble);
    return (nibble < 4'hA) ? (8'h30 + {4'h0, nibble}) : (8'h41 + {4'h0, nibble - 4'hA});
  endfunction

  logic [31:0] display_ascii; // [31:24]=Digit 3, [23:16]=Digit 2, [15:8]=Digit 1, [7:0]=Digit 0
  assign display_ascii = {
    hex_to_ascii(dut_top.display_word[15:12]),
    hex_to_ascii(dut_top.display_word[11:8]),
    hex_to_ascii(dut_top.display_word[7:4]),
    hex_to_ascii(dut_top.display_word[3:0])
  };

  // 3. Receiver Input IQ & Synchronization Milestones
  logic               dut_in_valid;
  logic signed [11:0] dut_in_i;
  logic signed [11:0] dut_in_q;
  logic               str_locked;
  logic               costas_locked;
  logic [2:0]         receiver_fsm_state;

  assign dut_in_valid       = dut_top.dut_in_valid;
  assign dut_in_i           = dut_top.dut_in_i;
  assign dut_in_q           = dut_top.dut_in_q;
  assign str_locked         = dut_top.str_locked_raw;
  assign costas_locked      = dut_top.costas_locked_raw;
  assign receiver_fsm_state = dut_top.dut_fsm_state_reg;

  // 4. Demodulated Symbol vs Golden Reference & Bit-Exact Comparator
  logic               sym_valid;
  logic signed [15:0] sym_out_i;
  logic signed [15:0] sym_out_q;
  logic signed [15:0] sym_exp_i;
  logic signed [15:0] sym_exp_q;
  logic               sym_match;
  logic               sym_mismatch;

  assign sym_valid          = dut_top.dut_out_sym_valid;
  assign sym_out_i          = dut_top.dut_out_sym_i;
  assign sym_out_q          = dut_top.dut_out_sym_q;
  assign sym_exp_i          = dut_top.exp_sym_i;
  assign sym_exp_q          = dut_top.exp_sym_q;
  assign sym_match          = dut_top.sym_match;
  assign sym_mismatch       = dut_top.sym_mismatch;

  int sim_cycles = 0;
  bit str_locked_seen    = 1'b0;
  bit costas_locked_seen = 1'b0;
  bit track_state_seen   = 1'b0;
  bit digit0_seen        = 1'b0;
  bit digit1_seen        = 1'b0;
  bit digit2_seen        = 1'b0;
  bit digit3_seen        = 1'b0;
  int last_pass_cnt      = 0;
  int tb_errors          = 0;

  initial begin
    $display("==================================================================");
    $display("  STARTING FPGA BIST HARDWARE TESTBENCH (AMD ZCU106 WRAPPER)");
    $display("==================================================================");

    // Initial state: SW14 not pressed, power applied
    btn_sw14 = 1'b0;

    // Wait for power-on reset sequencer (16 clock cycles) to release reset
    @(posedge dut_top.rst_n_sync);
    $display("[CYCLE %0d] Power-on reset released! Synchronous rst_n asserted.", sim_cycles);

    // Monitor execution progress
    while (dut_top.bist_state_q != 4'b1010 && sim_cycles < 20000) begin
      @(posedge clk_125_p);
      sim_cycles++;

      if (dut_top.str_locked_raw && !str_locked_seen) begin
        str_locked_seen = 1'b1;
        $display("[CYCLE %0d] Milestone 1: STR Lock declared (LED[2] = 1, status_code = 0x%02X)",
                 sim_cycles, dut_top.status_code);
      end

      if (dut_top.costas_locked_raw && !costas_locked_seen) begin
        costas_locked_seen = 1'b1;
        $display("[CYCLE %0d] Milestone 2: Costas Carrier Lock declared (LED[3] = 1, status_code = 0x%02X)",
                 sim_cycles, dut_top.status_code);
      end

      if (dut_top.dut_fsm_state_reg == 3'd5 && !track_state_seen) begin
        track_state_seen = 1'b1;
        $display("[CYCLE %0d] Milestone 3: Entered TRACK state (status_code = 0x%02X)",
                 sim_cycles, dut_top.status_code);
      end

      if (dut_top.pass_count_q != last_pass_cnt) begin
        last_pass_cnt = dut_top.pass_count_q;
        if (last_pass_cnt % 200 == 0 || last_pass_cnt == 1199) begin
          $display("[CYCLE %0d] BIST Progress: %0d / 1199 payload symbols verified bit-exact (display: %02X %02X)",
                   sim_cycles, last_pass_cnt, dut_top.status_code, dut_top.pass_count_q[7:0]);
        end
      end



      if (dut_top.error_latch_q) begin
        $display("[FAIL][CYCLE %0d] BIST detected error latch asserted! Status=%02X, PassCount=%0d",
                 sim_cycles, dut_top.status_code, dut_top.pass_count_q);
        tb_errors++;
        break;
      end
    end

    // Wait extra cycles in ST_DONE to observe stable outputs & verify 7-seg multiplexing on PMOD pins
    digit0_seen = 1'b0;
    digit1_seen = 1'b0;
    digit2_seen = 1'b0;
    digit3_seen = 1'b0;

    repeat (250) begin
      @(posedge clk_125_p);
      sim_cycles++;

      // Check physical PMOD 7-segment multiplexing (Active-low anodes and cathodes)
      case (pmod_an_o)
        4'b1110: begin // Digit 0: Lower count nibble = 0xF -> segments ~7'b1110001 = 7'b0001110
          digit0_seen = 1'b1;
          if (pmod_seg_o != 7'b0001110) begin
            $display("[ERROR] Digit 0 PMOD segment mismatch! Expected 7'b0001110 ('F'), got 7'b%07b", pmod_seg_o);
            tb_errors++;
          end
        end
        4'b1101: begin // Digit 1: Upper count nibble = 0xA -> segments ~7'b1110111 = 7'b0001000
          digit1_seen = 1'b1;
          if (pmod_seg_o != 7'b0001000) begin
            $display("[ERROR] Digit 1 PMOD segment mismatch! Expected 7'b0001000 ('A'), got 7'b%07b", pmod_seg_o);
            tb_errors++;
          end
        end
        4'b1011: begin // Digit 2: Lower status nibble = 0xA -> segments ~7'b1110111 = 7'b0001000
          digit2_seen = 1'b1;
          if (pmod_seg_o != 7'b0001000) begin
            $display("[ERROR] Digit 2 PMOD segment mismatch! Expected 7'b0001000 ('A'), got 7'b%07b", pmod_seg_o);
            tb_errors++;
          end
        end
        4'b0111: begin // Digit 3: Upper status nibble = 0xA -> segments ~7'b1110111 = 7'b0001000
          digit3_seen = 1'b1;
          if (pmod_seg_o != 7'b0001000) begin
            $display("[ERROR] Digit 3 PMOD segment mismatch! Expected 7'b0001000 ('A'), got 7'b%07b", pmod_seg_o);
            tb_errors++;
          end
        end
        default: ;
      endcase
    end

    if (!(digit0_seen && digit1_seen && digit2_seen && digit3_seen)) begin
      $display("[ERROR] Not all PMOD 7-segment digits were active during refresh cycle! (d0=%0b, d1=%0b, d2=%0b, d3=%0b)",
               digit0_seen, digit1_seen, digit2_seen, digit3_seen);
      tb_errors++;
    end else begin
      $display("[PMOD VERIFIED] All 4 display digits verified bit-accurately on PMOD pins: [ A A A F ]");
    end

    $display("------------------------------------------------------------------");
    $display("  BIST HARDWARE EXECUTION SUMMARY");
    $display("------------------------------------------------------------------");
    $display("  Total Simulated Cycles     : %0d", sim_cycles);
    $display("  Final BIST FSM State       : 4'b%04b (Expected: 4'b1010 / DONE)", dut_top.bist_state_q);
    $display("  Pass Count                 : %0d (Expected: 1199)", dut_top.pass_count_q);
    $display("  Error Count                : %0d (Expected: 0)", dut_top.err_count_q);
    $display("  Error Latch                : %0b (Expected: 0)", dut_top.error_latch_q);
    $display("  All Passed Register        : %0b (Expected: 1)", dut_top.all_passed_q);
    $display("  On-board GPIO LEDs (0..7)  : 8'b%08b", gpio_led);
    $display("    - LED[0] (ALL_PASSED)    : %0b", gpio_led[0]);
    $display("    - LED[1] (ERROR)         : %0b", gpio_led[1]);
    $display("    - LED[2] (STR_LOCKED)    : %0b", gpio_led[2]);
    $display("    - LED[3] (COSTAS_LOCKED) : %0b", gpio_led[3]);
    $display("    - LED[7:4] (FSM_STATE)   : 4'b%04b", gpio_led[7:4]);
    $display("  7-Segment Display Word     : 0x%04X (Expected: 0xAAAF -> 'AA AF')", dut_top.display_word);
    $display("    - Status Code (Upper)    : 0x%02X (Expected: 0xAA / PASS)", dut_top.status_code);
    $display("    - Pass Count Hex (Lower) : 0x%02X (Expected: 0xAF = 1199 & 0xFF)", dut_top.pass_count_q[7:0]);
    $display("------------------------------------------------------------------");

    // Assertions / Verifications
    if (dut_top.pass_count_q != 1199) begin
      $display("[ERROR] pass_count != 1199! (Got: %0d)", dut_top.pass_count_q);
      tb_errors++;
    end
    if (dut_top.err_count_q != 0 || dut_top.error_latch_q != 1'b0) begin
      $display("[ERROR] Errors detected during execution!");
      tb_errors++;
    end
    if (gpio_led[0] != 1'b1) begin
      $display("[ERROR] GPIO_LED[0] (ALL_PASSED) was not asserted!");
      tb_errors++;
    end
    if (gpio_led[1] != 1'b0) begin
      $display("[ERROR] GPIO_LED[1] (ERROR) was asserted!");
      tb_errors++;
    end
    if (gpio_led[2] != 1'b1) begin
      $display("[ERROR] GPIO_LED[2] (STR_LOCKED) was not asserted!");
      tb_errors++;
    end
    if (gpio_led[3] != 1'b1) begin
      $display("[ERROR] GPIO_LED[3] (COSTAS_LOCKED) was not asserted!");
      tb_errors++;
    end
    if (dut_top.display_word != 16'hAAAF) begin
      $display("[ERROR] 7-segment display word is not 0xAAAF! (Got: 0x%04X)", dut_top.display_word);
      tb_errors++;
    end

    // ------------------------------------------------------------------------
    // Step 2: Pushbutton SW14 Restart Test
    // ------------------------------------------------------------------------
    $display("\n==================================================================");
    $display("  TESTING USER PUSHBUTTON SW14 RESTART");
    $display("==================================================================");
    @(posedge clk_125_p);
    btn_sw14 = 1'b1; // Press SW14
    $display("[CYCLE %0d] SW14 pressed. Waiting 10 cycles in reset...", sim_cycles);
    repeat (10) @(posedge clk_125_p);
    sim_cycles += 10;

    if (dut_top.rst_n_sync != 1'b0) begin
      $display("[ERROR] rst_n_sync did not assert during SW14 press!");
      tb_errors++;
    end
    if (dut_top.bist_state_q != 4'b0000) begin
      $display("[ERROR] BIST FSM did not return to ST_RESET on SW14!");
      tb_errors++;
    end

    btn_sw14 = 1'b0; // Release SW14
    $display("[CYCLE %0d] SW14 released. Verifying clean restart sequencer...", sim_cycles);
    @(posedge dut_top.rst_n_sync);
    $display("[CYCLE %0d] Synchronous reset successfully released after 16 cycles!", sim_cycles);

    repeat (50) @(posedge clk_125_p);
    sim_cycles += 50;

    if (dut_top.bist_state_q == 4'b0001) begin
      $display("[SUCCESS] BIST successfully transitioned back to ST_FEED on restart!");
    end else begin
      $display("[ERROR] BIST failed to re-enter ST_FEED! State=4'b%04b", dut_top.bist_state_q);
      tb_errors++;
    end

    // ------------------------------------------------------------------------
    // Step 3: Error Injection & Mismatch Freeze Verification
    // ------------------------------------------------------------------------
    $display("\n==================================================================");
    $display("  TESTING ERROR INJECTION & MISMATCH FREEZE SPECIFICATION");
    $display("==================================================================");

    // Wait until Dutch enters TRACK state in the restarted run
    while (dut_top.dut_fsm_state_reg != 3'd5 && sim_cycles < 30000) begin
      @(posedge clk_125_p);
      sim_cycles++;
    end

    // Wait until 10 payload symbols have been received
    while (dut_top.exp_addr_q < 11'd10 && sim_cycles < 35000) begin
      @(posedge clk_125_p);
      sim_cycles++;
    end

    $display("[CYCLE %0d] Injecting artificial payload mismatch at expected addr = %0d (0x%02X)...",
             sim_cycles, dut_top.exp_addr_q, dut_top.exp_addr_q[7:0]);
    // Inject corruption on expected symbol data (force whole 32-bit register for xsim compliance)
    force dut_top.exp_rom_dout = {dut_top.exp_rom_dout[31:16], 16'hDEAD};
    @(posedge clk_125_p);
    sim_cycles++;
    // Wait until dut_out_sym_valid triggers comparator with corrupted data
    while (!dut_top.dut_out_sym_valid && sim_cycles < 40000) begin
      @(posedge clk_125_p);
      sim_cycles++;
    end
    @(posedge clk_125_p); // Latch comparator output
    sim_cycles++;
    release dut_top.exp_rom_dout;

    $display("[CYCLE %0d] Error Injected. Checking error latch and display freezing...", sim_cycles);
    $display("  - error_latch_q       : %0b (Expected: 1)", dut_top.error_latch_q);
    $display("  - err_addr_q          : %0d (0x%02X)", dut_top.err_addr_q, dut_top.err_addr_q[7:0]);
    $display("  - status_code         : 0x%02X (Expected: 0xEE)", dut_top.status_code);
    $display("  - display_word        : 0x%04X (Expected: 0xEE%02X)", dut_top.display_word, dut_top.err_addr_q[7:0]);
    $display("  - GPIO_LED[1] (ERROR) : %0b (Expected: 1)", gpio_led[1]);
    $display("  - GPIO_LED[0] (PASS)  : %0b (Expected: 0)", gpio_led[0]);

    if (dut_top.error_latch_q != 1'b1) begin
      $display("[ERROR] error_latch_q failed to assert on mismatch!");
      tb_errors++;
    end
    if (dut_top.status_code != 8'hEE) begin
      $display("[ERROR] status_code is not 0xEE on error! Got: 0x%02X", dut_top.status_code);
      tb_errors++;
    end
    if (dut_top.display_word[15:8] != 8'hEE || dut_top.display_word[7:0] != dut_top.err_addr_q[7:0]) begin
      $display("[ERROR] display_word did not freeze at EE <err_addr>! Got: 0x%04X", dut_top.display_word);
      tb_errors++;
    end
    if (gpio_led[1] != 1'b1) begin
      $display("[ERROR] GPIO_LED[1] (ERROR) was not asserted!");
      tb_errors++;
    end
    if (gpio_led[0] != 1'b0) begin
      $display("[ERROR] GPIO_LED[0] (ALL_PASSED) was asserted during error state!");
      tb_errors++;
    end

    // Run for another 100 cycles to verify display and error status remain frozen
    repeat (100) @(posedge clk_125_p);
    sim_cycles += 100;
    if (dut_top.status_code != 8'hEE || dut_top.display_word[15:8] != 8'hEE) begin
      $display("[ERROR] Error status did not remain frozen!");
      tb_errors++;
    end else begin
      $display("[SUCCESS] Error handling and frozen display verified bit-accurately: [ EE %02X ]", dut_top.err_addr_q[7:0]);
    end

    // Finally, verify recovery via SW14 pushbutton
    btn_sw14 = 1'b1;
    repeat (10) @(posedge clk_125_p);
    sim_cycles += 10;
    btn_sw14 = 1'b0;
    @(posedge dut_top.rst_n_sync);
    if (dut_top.error_latch_q != 1'b0) begin
      $display("[ERROR] error_latch_q was not cleared after SW14 reset!");
      tb_errors++;
    end else begin
      $display("[SUCCESS] SW14 reset successfully cleared error state and returned to autonomous operation.");
    end

    $display("==================================================================");
    if (tb_errors == 0) begin
      $display("  ALL VERIFICATION CHECKS PASSED: 100%% BIT-EXACT HARDWARE BIST!");
      $display("  7-Segment Display: [ AA AF ] | LED[0] (ALL_PASSED) = 1");
      $display("==================================================================");
    end else begin
      $display("  VERIFICATION FAILED WITH %0d ERRORS!", tb_errors);
      $display("==================================================================");
    end

    $stop;
  end

endmodule
