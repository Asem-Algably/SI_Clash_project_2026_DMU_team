`timescale 1ns / 1ps

module tb_str_top;

  localparam int MAX_VECS = 20000;
  logic [71:0] vec_mem [0:MAX_VECS-1];
  logic [3:0]  v_in_val, v_flush, v_exp_val, v_exp_lock;

  logic                clk = 1'b0;
  logic                rst_n;
  logic                in_valid;
  logic                flush_act;
  logic signed [11:0]  in_i, in_q;

  logic                out_valid;
  logic signed [15:0]  out_i, out_q;
  logic                lock_o;
  logic                ted_err_valid;
  logic signed [31:0]  ted_err_o;
  logic [9:0]          mu_o;
  logic [15:0]         w_o;

  logic                exp_valid;
  logic signed [15:0]  exp_i, exp_q;
  logic                exp_lock;

  int num_vecs = 0;
  int num_syms_matched = 0;
  int num_syms_mismatched = 0;
  int err_count = 0;
  int diff_i, diff_q;
  int rtl_strobe_cnt = 0;

  // Queue to hold expected symbols from the golden model
  logic signed [15:0] exp_queue_i[$];
  logic signed [15:0] exp_queue_q[$];
  logic signed [15:0] cur_exp_i, cur_exp_q;
  int total_exp_syms = 0;

  always #4 clk = ~clk; // 125 MHz clock

  str_top u_str (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .s_axis_valid_i   (in_valid),
    .flush_active_i   (flush_act),
    .s_axis_i_sample_i(in_i),
    .s_axis_q_sample_i(in_q),
    .loop_gain_i      (8'd0),
    .m_axis_valid_o   (out_valid),
    .m_axis_i_sym_o   (out_i),
    .m_axis_q_sym_o   (out_q),
    .lock_o           (lock_o),
    .ted_err_valid_o  (ted_err_valid),
    .ted_err_o        (ted_err_o),
    .mu_o             (mu_o),
    .w_o              (w_o),
    .force_w_en_i     (1'b0),
    .force_w_i        (16'd0)
  );

  initial begin
    $display("==========================================================");
    $display("  TB: str_top (Golden Model Verification)");
    $display("==========================================================");

    // Read vector file
    $readmemh("tb/vectors/tb_str_vec.hex", vec_mem);

    // Count actual vectors loaded and preload expected symbols
    while (vec_mem[num_vecs] !== 72'hx && num_vecs < MAX_VECS) begin
      {v_in_val, in_i, in_q, v_flush, v_exp_val, exp_i, exp_q, v_exp_lock} = vec_mem[num_vecs];
      if (v_exp_val[0]) begin
        exp_queue_i.push_back(exp_i);
        exp_queue_q.push_back(exp_q);
      end
      num_vecs++;
    end
    total_exp_syms = exp_queue_i.size();
    $display("Loaded %0d vectors (%0d expected strobed symbols) from tb/vectors/tb_str_vec.hex", num_vecs, total_exp_syms);

    if (num_vecs == 0) begin
      $display("ERROR: No vectors loaded! Check file path.");
      $stop;
    end

    // Reset sequence (Synchronous Reset)
    rst_n     = 1'b0;
    in_valid  = 1'b0;
    flush_act = 1'b0;
    in_i      = '0;
    in_q      = '0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // Clock-by-clock vector replay
    for (int k = 0; k < num_vecs; k++) begin
      {v_in_val, in_i, in_q, v_flush, v_exp_val, exp_i, exp_q, v_exp_lock} = vec_mem[k];
      in_valid  = v_in_val[0];
      flush_act = v_flush[0];


      @(posedge clk);
      #1; // Post-clock check


      if (out_valid) begin
        rtl_strobe_cnt++;
        if (rtl_strobe_cnt <= 10) begin
          $display("[STR_RTL] Strobe %0d at Cycle %0d: out=(%0d,%0d)", rtl_strobe_cnt, k, out_i, out_q);
        end
        if (exp_queue_i.size() > 0) begin
          cur_exp_i = exp_queue_i.pop_front();
          cur_exp_q = exp_queue_q.pop_front();

          diff_i = (out_i > cur_exp_i) ? (out_i - cur_exp_i) : (cur_exp_i - out_i);
          diff_q = (out_q > cur_exp_q) ? (out_q - cur_exp_q) : (cur_exp_q - out_q);

          if (diff_i != 0 || diff_q != 0) begin
            $display("[NONZERO_STR_DIFF][Strobe %0d / Cycle %0d] RTL=(%0d, %0d), Exp=(%0d, %0d) diff=(%0d, %0d)",
                     rtl_strobe_cnt, k, out_i, out_q, cur_exp_i, cur_exp_q, diff_i, diff_q);
          end
          if (diff_i == 0 && diff_q == 0) begin
            num_syms_matched++;
          end else begin
            $display("[FAIL][Strobe %0d / Cycle %0d] Symbol mismatch: RTL=(%0d, %0d), Exp=(%0d, %0d) diff=(%0d, %0d)",
                     rtl_strobe_cnt, k, out_i, out_q, cur_exp_i, cur_exp_q, diff_i, diff_q);
            num_syms_mismatched++;
            err_count++;
          end
        end else begin
          $display("[FAIL][Strobe %0d / Cycle %0d] Extra unexpected RTL strobe! (Expected FIFO empty)", rtl_strobe_cnt, k);
          err_count++;
        end
      end
    end

    repeat (10) @(posedge clk);

    if (exp_queue_i.size() > 0) begin
      $display("[FAIL] %0d expected symbols were not produced by RTL!", exp_queue_i.size());
      err_count += exp_queue_i.size();
    end

    $display("----------------------------------------------------------");
    $display("  STR VERIFICATION SUMMARY");
    $display("----------------------------------------------------------");
    $display("  Total Simulated Cycles : %0d", num_vecs);
    $display("  Expected Symbols       : %0d", total_exp_syms);
    $display("  RTL Strobes Produced   : %0d", rtl_strobe_cnt);
    $display("  Symbols Matched        : %0d", num_syms_matched);
    $display("  Symbols Mismatched     : %0d", num_syms_mismatched);
    $display("  Total Errors           : %0d", err_count);
    if (err_count == 0 && num_syms_matched == total_exp_syms && total_exp_syms > 0) begin
      $display("  STATUS: >>> PASSED (100%% Symbol Match to Golden Model) <<<");
    end else begin
      $display("  STATUS: >>> FAILED <<<");
    end
    $display("==========================================================");
    $stop;
  end

endmodule
