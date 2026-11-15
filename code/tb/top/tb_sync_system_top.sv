`timescale 1ns / 1ps

module tb_sync_system_top;

  localparam int MAX_VECS = 20000;
  logic [75:0] vec_mem [0:MAX_VECS-1];
  logic [3:0]  v_val, v_sob, v_exp_oval, v_exp_fsm, v_exp_lock;

  localparam int InSampleWidth = 12;
  localparam int OutSymWidth   = 16;
  localparam int CoarseWidth   = 24;
  localparam int PhaseWidth    = 32;

  logic                          clk = 1'b0;
  logic                          rst_n;
  logic signed [InSampleWidth-1:0] in_sample_i, in_sample_q;
  logic                          in_sample_valid;
  logic [1:0]                    mod_type;
  logic [7:0]                    loop_gain;
  logic [7:0]                    costas_loop_gain;
  logic [3:0]                    dft_sel;
  logic                          start_of_burst;
  logic                          force_w_en;
  logic [15:0]                   force_w;
  logic                          force_cfo_en;
  logic signed [CoarseWidth-1:0] force_cfo;
  logic                          force_freq_en;
  logic [PhaseWidth-1:0]         force_freq;

  logic signed [OutSymWidth-1:0] out_sym_i, out_sym_q;
  logic                          out_sym_valid;
  logic signed [CoarseWidth-1:0] coarse_cfo_est;
  logic signed [PhaseWidth-1:0]  fine_cfo_est;
  logic                          lock_detect;
  logic                          flush_active;
  logic [7:0]                    valid_during_flush;
  logic [31:0]                   dft_obs_data;

  // Expected golden signals
  logic                          exp_oval;
  logic signed [OutSymWidth-1:0] exp_oi, exp_oq;
  logic [2:0]                    exp_fsm;
  logic                          exp_lock;

  int num_vecs = 0;
  int num_matched = 0;
  int num_mismatched = 0;
  int err_count = 0;
  int diff_i, diff_q;
  int max_diff_i = 0, max_diff_q = 0;
  int rtl_payload_sym_cnt = 0;

  // Milestone tracking flags
  bit str_lock_seen    = 1'b0;
  bit coarse_done_seen = 1'b0;
  bit costas_lock_seen = 1'b0;
  bit track_state_seen = 1'b0;

  // Expected payload symbols queue
  logic signed [OutSymWidth-1:0] exp_payload_i_q[$];
  logic signed [OutSymWidth-1:0] exp_payload_q_q[$];
  logic signed [OutSymWidth-1:0] cur_exp_i, cur_exp_q;
  int total_exp_payload_syms = 0;

  always #4 clk = ~clk; // 125 MHz

  sync_system_top #(
    .InSampleWidth (InSampleWidth),
    .OutSymWidth   (OutSymWidth),
    .CoarseWidth   (CoarseWidth),
    .PhaseWidth    (PhaseWidth),
    .MuWidth       (10),
    .DftSelWidth   (4),
    .NA1           (70),
    .NA2           (40),
    .NPreamble     (190),
    .TedErrAlign   (2),
    .CostasErrAlign(0)
  ) dut (
    .clk               (clk),
    .rst_n             (rst_n),
    .in_sample_i       (in_sample_i),
    .in_sample_q       (in_sample_q),
    .in_sample_valid   (in_sample_valid),
    .mod_type          (mod_type),
    .loop_gain         (loop_gain),
    .costas_loop_gain  (costas_loop_gain),
    .dft_sel           (dft_sel),
    .start_of_burst    (start_of_burst),
    .force_w_en        (force_w_en),
    .force_w           (force_w),
    .force_cfo_en      (force_cfo_en),
    .force_cfo         (force_cfo),
    .force_freq_en     (force_freq_en),
    .force_freq        (force_freq),
    .out_sym_i         (out_sym_i),
    .out_sym_q         (out_sym_q),
    .out_sym_valid     (out_sym_valid),
    .coarse_cfo_est    (coarse_cfo_est),
    .fine_cfo_est      (fine_cfo_est),
    .lock_detect       (lock_detect),
    .flush_active      (flush_active),
    .valid_during_flush(valid_during_flush),
    .dft_obs_data      (dft_obs_data)
  );

  initial begin
    $display("==========================================================");
    $display("  TB: sync_system_top (Milestone & Payload 100%% Match)");
    $display("==========================================================");

    $readmemh("code/tb/vectors/tb_top_vec.hex", vec_mem);

    while (vec_mem[num_vecs] !== 76'hx && num_vecs < MAX_VECS) begin
      {v_val, in_sample_i, in_sample_q, v_sob,
       v_exp_oval, exp_oi, exp_oq, v_exp_fsm, v_exp_lock} = vec_mem[num_vecs];
      // Preload payload expected symbols (FSM state 5 = TRACK)
      if (v_exp_oval[0] && v_exp_fsm[2:0] == 3'd5) begin
        exp_payload_i_q.push_back(exp_oi);
        exp_payload_q_q.push_back(exp_oq);
      end
      num_vecs++;
    end
    total_exp_payload_syms = exp_payload_i_q.size();
    $display("Loaded %0d vectors (%0d expected payload symbols) from code/tb/vectors/tb_top_vec.hex",
             num_vecs, total_exp_payload_syms);

    if (num_vecs == 0) begin
      $display("ERROR: No vectors loaded!");
      $stop;
    end

    // Default ties
    mod_type         = 2'd1; // 16-QAM (matches golden model cfg.mod_type = 1)
    loop_gain        = 8'd0;
    costas_loop_gain = 8'd0;
    dft_sel          = 4'd0;
    force_w_en       = 1'b0;
    force_w          = 16'd0;
    force_cfo_en     = 1'b0;
    force_cfo        = '0;
    force_freq_en    = 1'b0;
    force_freq       = '0;

    // Reset sequence (Synchronous Reset)
    rst_n           = 1'b0;
    in_sample_valid = 1'b0;
    start_of_burst  = 1'b0;
    in_sample_i     = '0;
    in_sample_q     = '0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    for (int k = 0; k < num_vecs; k++) begin
      {v_val, in_sample_i, in_sample_q, v_sob,
       v_exp_oval, exp_oi, exp_oq, v_exp_fsm, v_exp_lock} = vec_mem[k];
      in_sample_valid = v_val[0];
      start_of_burst  = v_sob[0];
      exp_oval        = v_exp_oval[0];
      exp_fsm         = v_exp_fsm[2:0];
      exp_lock        = v_exp_lock[0];

      @(posedge clk);
      #1;

      // 1. Check Acquisition Milestones
      if (dut.str_lock && !str_lock_seen) begin
        str_lock_seen = 1'b1;
        $display("[MILESTONE 1][Cycle %0d] STR Lock Declared!", k);
      end
      if (dut.coarse_valid && !coarse_done_seen) begin
        coarse_done_seen = 1'b1;
        $display("[MILESTONE 2][Cycle %0d] Coarse CFO Done! cfo_est=%0d (hex %h)", k, coarse_cfo_est, coarse_cfo_est);
      end
      if (dut.costas_lock && !costas_lock_seen) begin
        costas_lock_seen = 1'b1;
        $display("[MILESTONE 3][Cycle %0d] Costas Carrier Lock Declared!", k);
      end

      if (dut.fsm_state == 3'd5 && !track_state_seen) begin
        track_state_seen = 1'b1;
        $display("[MILESTONE 4][Cycle %0d] Burst Controller Entered TRACK State!", k);
      end

      if (out_sym_valid) begin
        if (out_sym_i != exp_oi || out_sym_q != exp_oq) begin
          $display("[FIRST_DIFF][Cycle %0d][fsm=%0d] RTL=(%0d,%0d) Exp=(%0d,%0d) diff=(%0d,%0d) nco_w=%h",
                   k, dut.fsm_state, out_sym_i, out_sym_q, exp_oi, exp_oq,
                   (out_sym_i > exp_oi ? out_sym_i - exp_oi : exp_oi - out_sym_i),
                   (out_sym_q > exp_oq ? out_sym_q - exp_oq : exp_oq - out_sym_q),
                   dut.nco_freq_word);
        end
      end

      // 2. Compare Recovered Payload Symbols during Tracking
      if (dut.fsm_state == 3'd5 && out_sym_valid) begin
        rtl_payload_sym_cnt++;
        if (exp_payload_i_q.size() > 0) begin
          cur_exp_i = exp_payload_i_q.pop_front();
          cur_exp_q = exp_payload_q_q.pop_front();

          diff_i = (out_sym_i > cur_exp_i) ? (out_sym_i - cur_exp_i) : (cur_exp_i - out_sym_i);
          diff_q = (out_sym_q > cur_exp_q) ? (out_sym_q - cur_exp_q) : (cur_exp_q - out_sym_q);
          if (diff_i > max_diff_i) max_diff_i = diff_i;
          if (diff_q > max_diff_q) max_diff_q = diff_q;

          // Strict 100% bit-exact check down to the exact LSB
          if (diff_i == 0 && diff_q == 0) begin
            num_matched++;
          end else begin
            $display("[FAIL][Payload Sym %0d / Cycle %0d] Symbol mismatch: RTL=(%0d, %0d), Exp=(%0d, %0d), diff=(%0d, %0d)",
                     rtl_payload_sym_cnt, k, out_sym_i, out_sym_q, cur_exp_i, cur_exp_q, diff_i, diff_q);
            num_mismatched++;
            err_count++;
          end
        end else begin
          $display("[FAIL][Payload Sym %0d / Cycle %0d] Extra unexpected RTL payload symbol! (Exp FIFO empty)", rtl_payload_sym_cnt, k);
          err_count++;
        end
      end
    end

    repeat (20) @(posedge clk);

    // Verify all milestones were achieved
    if (!str_lock_seen) begin
      $display("[FAIL] Milestone 1: STR Lock was never asserted!");
      err_count++;
    end
    if (!coarse_done_seen) begin
      $display("[FAIL] Milestone 2: Coarse CFO was never completed!");
      err_count++;
    end
    if (!costas_lock_seen) begin
      $display("[FAIL] Milestone 3: Costas Lock was never asserted!");
      err_count++;
    end
    if (!track_state_seen) begin
      $display("[FAIL] Milestone 4: TRACK state was never entered!");
      err_count++;
    end

    if (exp_payload_i_q.size() > 0) begin
      $display("[FAIL] %0d expected payload symbols were not produced by RTL!", exp_payload_i_q.size());
      err_count += exp_payload_i_q.size();
    end

    $display("----------------------------------------------------------");
    $display("  TOP SYSTEM INTEGRATION SUMMARY");
    $display("----------------------------------------------------------");
    $display("  Simulated Cycles         : %0d", num_vecs);
    $display("  Expected Payload Symbols : %0d", total_exp_payload_syms);
    $display("  RTL Payload Symbols      : %0d", rtl_payload_sym_cnt);
    $display("  Symbols Matched (100%%)   : %0d", num_matched);
    $display("  Symbols Mismatched       : %0d", num_mismatched);
    $display("  Max Diff (I, Q)          : (%0d, %0d) LSBs", max_diff_i, max_diff_q);
    $display("  Total Errors             : %0d", err_count);
    if (err_count == 0 && num_matched == total_exp_payload_syms && total_exp_payload_syms > 0) begin
      $display("  STATUS: >>> PASSED (100%% Match to Golden Model) <<<");
    end else begin
      $display("  STATUS: >>> FAILED <<<");
    end
    $display("==========================================================");
    $stop;
  end

endmodule
