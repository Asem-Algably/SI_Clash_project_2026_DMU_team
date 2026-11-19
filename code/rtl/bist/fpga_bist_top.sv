// ============================================================================
// File Name   : fpga_bist_top.sv
// Module Name : fpga_bist_top
// Project     : SI-CLASH Real-Time Digital Synchronizer - ZCU106 BIST
// Target Dev  : AMD Xilinx ZCU106 Evaluation Kit (XCZU7EV-2FFVC1156-2-E)
// Description : Master standalone Hardware Self-Test (BIST) top-level wrapper.
//               Integrates sync_system_top (DUT), input ROM, expected ROM,
//               bit-exact symbol comparator, autonomous BIST FSM, 7-segment
//               display controller, GPIO LED status, and optional VIO/ILA debug.
// ============================================================================

`timescale 1ns / 1ps

module fpga_bist_top #(
  parameter bit          SIM_BYPASS_MMCM    = 1'b0,
  parameter int          CLK_GEN_PRIMITIVE  = 1,             // 0 = NONE/BYPASS, 1 = MMCME4_BASE (ZCU106), 2 = MMCME2_BASE (7-Series)
  parameter bit          CATHODE_ACTIVE_LOW = 1'b1,
  parameter bit          ANODE_ACTIVE_LOW   = 1'b1,
  parameter int unsigned PRESCALER_LIMIT    = 200_000,       // 200 MHz / 200,000 = 1 kHz refresh
  parameter              INPUT_ROM_FILE     = "bist_input_vec.mem",
  parameter              EXP_ROM_FILE       = "bist_exp_vec.mem",
  parameter bit          ENABLE_DEBUG_CORES = 1'b0
)(
  // Primary differential clock input: 125.00 MHz on PL Bank 28 (Pins H9/G9)
  input  logic       clk_125_p,
  input  logic       clk_125_n,

  // User Pushbutton SW14 (Pin AL10, active-high, pressed = 1'b1)
  input  logic       btn_sw14,

  // On-board GPIO LEDs (Pins AL11, AL13, AK13, AE15, AM8, AM9, AM10, AM11)
  // [0] = ALL_PASSED, [1] = ERROR, [2] = STR_LOCKED, [3] = COSTAS_LOCKED, [7:4] = State
  output logic [7:0] gpio_led,

  // PMOD 7-Segment Display (J55 Segments, J87 Anodes)
  output logic [6:0] pmod_seg_o,
  output logic       pmod_dp_o,
  output logic [3:0] pmod_an_o
);

  // --------------------------------------------------------------------------
  // 1. Clock Generation (125 MHz In -> 200.00 MHz clk_200 Out)
  // --------------------------------------------------------------------------
  logic clk_200;
  logic mmcm_locked;

  generate
    if (SIM_BYPASS_MMCM || CLK_GEN_PRIMITIVE == 0) begin : gen_sim_clk
      assign clk_200     = clk_125_p;
      assign mmcm_locked = 1'b1;
    end else if (CLK_GEN_PRIMITIVE == 1) begin : gen_usplus_mmcm
      logic clk_125_ibuf;
      logic clk_200_unbuf;
      logic clk_fb_unbuf, clk_fb_buf;

      IBUFDS u_ibufds (
        .I  (clk_125_p),
        .IB (clk_125_n),
        .O  (clk_125_ibuf)
      );

      MMCME4_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (8.000),      // VCO = 125.0 * 8 = 1000.0 MHz
        .CLKFBOUT_PHASE     (0.000),
        .CLKIN1_PERIOD      (8.000),      // 125.000 MHz (period = 8.000 ns)
        .CLKOUT0_DIVIDE_F   (5.000),      // 1000.0 / 5 = 200.00 MHz
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000),
        .DIVCLK_DIVIDE      (1),
        .STARTUP_WAIT       ("FALSE")
      ) u_mmcm4 (
        .CLKIN1   (clk_125_ibuf),
        .CLKFBIN  (clk_fb_buf),
        .CLKOUT0  (clk_200_unbuf),
        .CLKOUT0B (),
        .CLKOUT1  (),
        .CLKOUT1B (),
        .CLKOUT2  (),
        .CLKOUT2B (),
        .CLKOUT3  (),
        .CLKOUT3B (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .CLKOUT6  (),
        .CLKFBOUT (clk_fb_unbuf),
        .CLKFBOUTB(),
        .LOCKED   (mmcm_locked),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
      );

      BUFG u_bufg_clk (
        .I (clk_200_unbuf),
        .O (clk_200)
      );

      BUFG u_bufg_fb (
        .I (clk_fb_unbuf),
        .O (clk_fb_buf)
      );
    end else begin : gen_7series_mmcm
      logic clk_125_ibuf;
      logic clk_200_unbuf;
      logic clk_fb_unbuf, clk_fb_buf;

      IBUFDS u_ibufds (
        .I  (clk_125_p),
        .IB (clk_125_n),
        .O  (clk_125_ibuf)
      );

      MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (8.000),      // VCO = 125.0 * 8 = 1000.0 MHz
        .CLKFBOUT_PHASE     (0.000),
        .CLKIN1_PERIOD      (8.000),      // 125.000 MHz (period = 8.000 ns)
        .CLKOUT0_DIVIDE_F   (5.000),      // 1000.0 / 5 = 200.00 MHz
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000),
        .DIVCLK_DIVIDE      (1),
        .STARTUP_WAIT       ("FALSE")
      ) u_mmcm2 (
        .CLKIN1   (clk_125_ibuf),
        .CLKFBIN  (clk_fb_buf),
        .CLKOUT0  (clk_200_unbuf),
        .CLKOUT0B (),
        .CLKOUT1  (),
        .CLKOUT1B (),
        .CLKOUT2  (),
        .CLKOUT2B (),
        .CLKOUT3  (),
        .CLKOUT3B (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .CLKOUT6  (),
        .CLKFBOUT (clk_fb_unbuf),
        .CLKFBOUTB(),
        .LOCKED   (mmcm_locked),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
      );

      BUFG u_bufg_clk (
        .I (clk_200_unbuf),
        .O (clk_200)
      );

      BUFG u_bufg_fb (
        .I (clk_fb_unbuf),
        .O (clk_fb_buf)
      );
    end
  endgenerate

  // --------------------------------------------------------------------------
  // 2. Power-On Reset Sequencer & Re-run Logic
  // --------------------------------------------------------------------------
  logic vio_restart_btn;
  logic rst_async;
  logic [15:0] rst_shift_reg = 16'h0000;
  logic rst_n_sync;

  assign rst_async = (!mmcm_locked) | btn_sw14 | vio_restart_btn;

  always_ff @(posedge clk_200 or posedge rst_async) begin
    if (rst_async) begin
      rst_shift_reg <= 16'h0000;
      rst_n_sync    <= 1'b0;
    end else begin
      rst_shift_reg <= {rst_shift_reg[14:0], 1'b1};
      rst_n_sync    <= rst_shift_reg[15];
    end
  end

  // --------------------------------------------------------------------------
  // 3. BIST Controller FSM & ROM Address Generation
  // --------------------------------------------------------------------------
  localparam logic [3:0] ST_RESET = 4'b0000;
  localparam logic [3:0] ST_FEED  = 4'b0001;
  localparam logic [3:0] ST_DRAIN = 4'b0010;
  localparam logic [3:0] ST_DONE  = 4'b1010;

  logic [3:0]  bist_state_q, bist_state_d;
  logic [12:0] sample_addr_q, sample_addr_d;
  logic [10:0] exp_addr_q, exp_addr_d;
  logic [10:0] err_addr_q, err_addr_d;
  logic [15:0] pass_count_q, pass_count_d;
  logic [15:0] err_count_q, err_count_d;
  logic        error_latch_q, error_latch_d;
  logic        all_passed_q, all_passed_d;
  logic [15:0] drain_timeout_cnt_q, drain_timeout_cnt_d;

  // ROM interfaces
  logic [25:0] in_rom_dout;
  logic [31:0] exp_rom_dout;

  bist_input_rom #(
    .ADDR_WIDTH(13),
    .DATA_WIDTH(26),
    .DEPTH     (5624),
    .INIT_FILE (INPUT_ROM_FILE)
  ) u_input_rom (
    .clk (clk_200),
    .en  (1'b1),
    .addr(sample_addr_q),
    .dout(in_rom_dout)
  );

  bist_expected_rom #(
    .ADDR_WIDTH(11),
    .DATA_WIDTH(32),
    .DEPTH     (1199),
    .INIT_FILE (EXP_ROM_FILE)
  ) u_expected_rom (
    .clk (clk_200),
    .en  (1'b1),
    .addr(exp_addr_q),
    .dout(exp_rom_dout)
  );

  // --------------------------------------------------------------------------
  // 4. DUT: sync_system_top Integration
  // --------------------------------------------------------------------------
  logic signed [11:0] dut_in_i, dut_in_q;
  logic               dut_in_valid;
  logic               dut_sob;

  // Registered stimulus driving DUT
  always_comb begin
    if (bist_state_q == ST_FEED || bist_state_q == ST_DRAIN) begin
      dut_in_valid = in_rom_dout[25];
      dut_sob      = in_rom_dout[24];
      dut_in_i     = in_rom_dout[23:12];
      dut_in_q     = in_rom_dout[11:0];
    end else begin
      dut_in_valid = 1'b0;
      dut_sob      = 1'b0;
      dut_in_i     = '0;
      dut_in_q     = '0;
    end
  end

  logic signed [15:0] dut_out_sym_i, dut_out_sym_q;
  logic               dut_out_sym_valid;
  logic signed [23:0] dut_coarse_cfo_est;
  logic signed [31:0] dut_fine_cfo_est;
  logic               dut_lock_detect;
  logic               dut_flush_active;
  logic [7:0]         dut_valid_during_flush;
  logic [31:0]        dut_dft_obs_data;
  logic               str_locked_raw;
  logic               costas_locked_raw;
  logic               str_locked_sticky;
  logic               costas_locked_sticky;
  logic [2:0]         dut_fsm_state_reg;

  always_ff @(posedge clk_200) begin
    if (!rst_n_sync) begin
      str_locked_sticky    <= 1'b0;
      costas_locked_sticky <= 1'b0;
    end else begin
      if (str_locked_raw)    str_locked_sticky    <= 1'b1;
      if (costas_locked_raw) costas_locked_sticky <= 1'b1;
    end
  end

  sync_system_top #(
    .InSampleWidth (12),
    .OutSymWidth   (16),
    .CoarseWidth   (24),
    .PhaseWidth    (32),
    .MuWidth       (10),
    .DftSelWidth   (4),
    .NA1           (70),
    .NA2           (40),
    .NPreamble     (190),
    .TedErrAlign   (2),
    .CostasErrAlign(0)
  ) u_dut (
    .clk               (clk_200),
    .rst_n             (rst_n_sync),
    .in_sample_i       (dut_in_i),
    .in_sample_q       (dut_in_q),
    .in_sample_valid   (dut_in_valid),
    .mod_type          (2'd1),      // 16-QAM
    .loop_gain         (8'd0),
    .costas_loop_gain  (8'd0),
    .dft_sel           (4'd0),
    .start_of_burst    (dut_sob),
    .force_w_en        (1'b0),
    .force_w           (16'd0),
    .force_cfo_en      (1'b0),
    .force_cfo         ('0),
    .force_freq_en     (1'b0),
    .force_freq        ('0),
    .out_sym_i         (dut_out_sym_i),
    .out_sym_q         (dut_out_sym_q),
    .out_sym_valid     (dut_out_sym_valid),
    .coarse_cfo_est    (dut_coarse_cfo_est),
    .fine_cfo_est      (dut_fine_cfo_est),
    .lock_detect       (dut_lock_detect),
    .flush_active      (dut_flush_active),
    .valid_during_flush(dut_valid_during_flush),
    .dft_obs_data      (dut_dft_obs_data),
    .str_lock_o        (str_locked_raw),
    .costas_lock_o     (costas_locked_raw),
    .fsm_state_o       (dut_fsm_state_reg)
  );

  // --------------------------------------------------------------------------
  // 6. Bit-Exact Payload Comparator & Pass/Error Accumulator
  // --------------------------------------------------------------------------
  logic signed [15:0] exp_sym_i, exp_sym_q;
  assign exp_sym_i = exp_rom_dout[31:16];
  assign exp_sym_q = exp_rom_dout[15:0];

  logic sym_match, sym_mismatch;
  assign sym_match    = (dut_out_sym_i == exp_sym_i) && (dut_out_sym_q == exp_sym_q);
  assign sym_mismatch = !sym_match;

  // Autonomous BIST Control Logic
  always_comb begin
    bist_state_d         = bist_state_q;
    sample_addr_d        = sample_addr_q;
    exp_addr_d           = exp_addr_q;
    err_addr_d           = err_addr_q;
    pass_count_d         = pass_count_q;
    err_count_d          = err_count_q;
    error_latch_d        = error_latch_q;
    all_passed_d         = all_passed_q;
    drain_timeout_cnt_d  = drain_timeout_cnt_q;

    // Symbol comparator action (active during TRACK state)
    if (dut_fsm_state_reg == 3'd5 && dut_out_sym_valid) begin
      if (exp_addr_q < 1199) begin
        if (sym_match) begin
          pass_count_d = pass_count_q + 16'd1;
          exp_addr_d   = exp_addr_q + 11'd1;
        end else begin
          error_latch_d = 1'b1;
          err_count_d   = err_count_q + 16'd1;
          if (!error_latch_q) begin
            err_addr_d  = exp_addr_q;
          end
          exp_addr_d    = exp_addr_q + 11'd1;
        end
      end else begin
        // Extra unexpected symbol past 1,199
        error_latch_d = 1'b1;
        err_count_d   = err_count_q + 16'd1;
        if (!error_latch_q) begin
          err_addr_d  = exp_addr_q;
        end
      end
    end

    // FSM Transitions
    case (bist_state_q)
      ST_RESET: begin
        sample_addr_d       = '0;
        exp_addr_d          = '0;
        err_addr_d          = '0;
        pass_count_d        = '0;
        err_count_d         = '0;
        error_latch_d       = 1'b0;
        all_passed_d        = 1'b0;
        drain_timeout_cnt_d = '0;
        if (rst_n_sync) begin
          bist_state_d  = ST_FEED;
          sample_addr_d = 13'd1;
        end
      end

      ST_FEED: begin
        if (sample_addr_q < 5624) begin
          sample_addr_d = sample_addr_q + 13'd1;
        end else begin
          bist_state_d = ST_DRAIN;
        end
      end

      ST_DRAIN: begin
        drain_timeout_cnt_d = drain_timeout_cnt_q + 16'd1;
        if (pass_count_q == 16'd1199 || drain_timeout_cnt_q > 16'd1000) begin
          bist_state_d = ST_DONE;
        end
      end

      ST_DONE: begin
        if (pass_count_q == 16'd1199 && !error_latch_q) begin
          all_passed_d = 1'b1;
        end
      end

      default: bist_state_d = ST_RESET;
    endcase
  end

  always_ff @(posedge clk_200) begin
    if (!rst_n_sync) begin
      bist_state_q        <= ST_RESET;
      sample_addr_q       <= '0;
      exp_addr_q          <= '0;
      err_addr_q          <= '0;
      pass_count_q        <= '0;
      err_count_q         <= '0;
      error_latch_q       <= 1'b0;
      all_passed_q        <= 1'b0;
      drain_timeout_cnt_q <= '0;
    end else begin
      bist_state_q        <= bist_state_d;
      sample_addr_q       <= sample_addr_d;
      exp_addr_q          <= exp_addr_d;
      err_addr_q          <= err_addr_d;
      pass_count_q        <= pass_count_d;
      err_count_q         <= err_count_d;
      error_latch_q       <= error_latch_d;
      all_passed_q        <= all_passed_d;
      drain_timeout_cnt_q <= drain_timeout_cnt_d;
    end
  end

  // --------------------------------------------------------------------------
  // 7. Status Code Generation & 7-Segment Controller
  // --------------------------------------------------------------------------
  // Upper 2 digits: Status Code
  // 00 = Reset, 01 = STR Acq, 02 = Costas Acq, 05 = Track, AA = Pass, EE = Error
  logic [7:0] status_code;
  always_comb begin
    if (!rst_n_sync) begin
      status_code = 8'h00;
    end else if (error_latch_q) begin
      status_code = 8'hEE;
    end else if (all_passed_q) begin
      status_code = 8'hAA;
    end else if (dut_fsm_state_reg == 3'd5) begin
      status_code = 8'h05;
    end else if (dut_fsm_state_reg >= 3'd2) begin
      status_code = 8'h02;
    end else if (dut_fsm_state_reg == 3'd1) begin
      status_code = 8'h01;
    end else begin
      status_code = 8'h00;
    end
  end

  // Display Format: [Upper 2 Digits: status_code | Lower 2 Digits: pass_count or error_addr]
  // On Mismatch Error (status_code == 0xEE): lower 2 digits display err_addr_q[7:0] (frozen at failing address)
  // Otherwise: lower 2 digits display pass_count_q[7:0]
  logic [7:0]  display_lower_byte;
  assign display_lower_byte = error_latch_q ? err_addr_q[7:0] : pass_count_q[7:0];

  logic [15:0] display_word;
  assign display_word = {status_code, display_lower_byte};

  seven_seg_controller #(
    .CATHODE_ACTIVE_LOW(CATHODE_ACTIVE_LOW),
    .ANODE_ACTIVE_LOW  (ANODE_ACTIVE_LOW),
    .PRESCALER_LIMIT   (PRESCALER_LIMIT)
  ) u_seven_seg (
    .clk         (clk_200),
    .rst_n       (rst_n_sync),
    .display_data(display_word),
    .dp_in       (4'b0000),
    .seg_o       (pmod_seg_o),
    .dp_o        (pmod_dp_o),
    .an_o        (pmod_an_o),
    .cur_digit_o (),
    .pulse_1khz_o()
  );

  // --------------------------------------------------------------------------
  // 8. On-Board GPIO LED Assignment
  // --------------------------------------------------------------------------
  assign gpio_led[0]   = all_passed_q;
  assign gpio_led[1]   = error_latch_q;
  assign gpio_led[2]   = str_locked_sticky;
  assign gpio_led[3]   = costas_locked_sticky;
  assign gpio_led[7:4] = bist_state_q;

  // --------------------------------------------------------------------------
  // 9. Vivado In-Chip Debug Cores (VIO & ILA)
  // --------------------------------------------------------------------------
  generate
    if (ENABLE_DEBUG_CORES) begin : gen_debug_cores
      // VIO Virtual Dashboard Core
      vio_0 u_vio (
        .clk       (clk_200),
        .probe_in0 (pass_count_q),         // [15:0]
        .probe_in1 (status_code),          // [7:0]
        .probe_in2 (all_passed_q),         // [0:0]
        .probe_in3 (error_latch_q),        // [0:0]
        .probe_in4 (str_locked_sticky),    // [0:0]
        .probe_in5 (costas_locked_sticky), // [0:0]
        .probe_out0(vio_restart_btn)       // [0:0]
      );

      // ILA Real-Time Waveform Analyzer Core
      ila_0 u_ila (
        .clk   (clk_200),
        .probe0(dut_out_sym_valid),       // [0:0]
        .probe1(dut_out_sym_i),           // [15:0]
        .probe2(dut_out_sym_q),           // [15:0]
        .probe3(exp_sym_i),               // [15:0]
        .probe4(exp_sym_q),               // [15:0]
        .probe5(sym_match),               // [0:0]
        .probe6(sym_mismatch),            // [0:0]
        .probe7(bist_state_q)             // [3:0]
      );
    end else begin : gen_no_debug
      assign vio_restart_btn = 1'b0;
    end
  endgenerate

endmodule
