`timescale 1ns / 1ps

module tb_derotator;

  import derotator_pkg::*;

  localparam int MAX_VECS = 20000;
  logic [171:0] vec_mem [0:MAX_VECS-1];
  logic [3:0]   v_val, v_cval, v_fval, v_pval, v_exp_val;

  logic                clk = 1'b0;
  logic                rst_n;
  logic                s_axis_valid_i;
  logic signed [15:0]  s_axis_i_sym_i, s_axis_q_sym_i;
  logic                coarse_valid_i;
  logic signed [23:0]  coarse_word_i;
  logic                freq_adj_valid_i;
  logic signed [31:0]  freq_adj_i;
  logic                force_freq_en_i;
  logic        [31:0]  force_freq_i;
  logic                phase_adj_valid_i;
  logic        [31:0]  phase_adj_i;

  logic                m_axis_valid_o;
  logic signed [15:0]  m_axis_i_sym_o, m_axis_q_sym_o;
  logic [31:0]         phase_o, freq_word_o;

  logic                exp_valid;
  logic signed [15:0]  exp_i, exp_q;

  int num_vecs = 0;
  int num_matched = 0;
  int err_count = 0;
  logic signed [15:0] exp_q_i [$];
  logic signed [15:0] exp_q_q [$];
  logic signed [15:0] cur_ei, cur_eq;
  int diff_i, diff_q;

  derotator_transaction cov;

  always #4 clk = ~clk;

  derotator #(
    .Width       (32),
    .Phase_Bits  (12),
    .DataWidth   (16),
    .Frac        (15),
    .Coarse_W    (24),
    .Coarse_Shift(8)
  ) u_derot (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .s_axis_valid_i   (s_axis_valid_i),
    .s_axis_i_sym_i   (s_axis_i_sym_i),
    .s_axis_q_sym_i   (s_axis_q_sym_i),
    .coarse_valid_i   (coarse_valid_i),
    .coarse_word_i    (coarse_word_i),
    .freq_adj_valid_i (freq_adj_valid_i),
    .freq_adj_i       (freq_adj_i),
    .force_freq_en_i  (force_freq_en_i),
    .force_freq_i     (force_freq_i),
    .phase_adj_valid_i(phase_adj_valid_i),
    .phase_adj_i      (phase_adj_i),
    .m_axis_valid_o   (m_axis_valid_o),
    .m_axis_i_sym_o   (m_axis_i_sym_o),
    .m_axis_q_sym_o   (m_axis_q_sym_o),
    .phase_o          (phase_o),
    .freq_word_o      (freq_word_o)
  );

  initial begin
    cov = new();

    $display("==========================================================");
    $display("  TB: derotator (Golden Model Bit-Accurate Verification)");
    $display("==========================================================");

    $readmemh("code/tb/vectors/tb_derot_vec.hex", vec_mem);

    // Check array bounds before indexing vec_mem
    while (num_vecs < MAX_VECS && vec_mem[num_vecs] !== 172'hx) begin
      {v_val, s_axis_i_sym_i, s_axis_q_sym_i,
       v_cval, coarse_word_i,
       v_fval, freq_adj_i,
       v_pval, phase_adj_i,
       v_exp_val, exp_i, exp_q} = vec_mem[num_vecs];
      if (v_exp_val[0]) begin
        exp_q_i.push_back(exp_i);
        exp_q_q.push_back(exp_q);
      end
      num_vecs++;
    end
    $display("Loaded %0d vectors (%0d expected derotated symbols) from code/tb/vectors/tb_derot_vec.hex", num_vecs, exp_q_i.size());

    if (num_vecs == 0) begin
      $display("ERROR: No vectors loaded!");
      $stop;
    end

    // Reset sequence
    rst_n             = 1'b0;
    s_axis_valid_i    = 1'b0;
    s_axis_i_sym_i    = '0;
    s_axis_q_sym_i    = '0;
    coarse_valid_i    = 1'b0;
    coarse_word_i     = '0;
    freq_adj_valid_i  = 1'b0;
    freq_adj_i        = '0;
    force_freq_en_i   = 1'b0;
    force_freq_i      = 32'd0;
    phase_adj_valid_i = 1'b0;
    phase_adj_i       = '0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    for (int k = 0; k < num_vecs; k++) begin
      {v_val, s_axis_i_sym_i, s_axis_q_sym_i,
       v_cval, coarse_word_i,
       v_fval, freq_adj_i,
       v_pval, phase_adj_i,
       v_exp_val, exp_i, exp_q} = vec_mem[k];
      s_axis_valid_i    = v_val[0];
      coarse_valid_i    = v_cval[0];
      freq_adj_valid_i  = v_fval[0];
      phase_adj_valid_i = v_pval[0];
      exp_valid         = v_exp_val[0];

      // Sample inputs & current state before active clock edge
      cov.s_valid         = s_axis_valid_i;
      cov.i_sym           = s_axis_i_sym_i;
      cov.q_sym           = s_axis_q_sym_i;
      cov.coarse_valid    = coarse_valid_i;
      cov.coarse_word     = coarse_word_i;
      cov.freq_adj_valid  = freq_adj_valid_i;
      cov.freq_adj        = freq_adj_i;
      cov.phase_adj_valid = phase_adj_valid_i;
      cov.phase_adj       = phase_adj_i;
      cov.force_en        = force_freq_en_i;
      cov.set_phase(phase_o);
      cov.freq_word       = freq_word_o;
      cov.sample_in();

      @(posedge clk);
      #1;

      // Sample outputs after clock edge
      cov.m_valid = m_axis_valid_o;
      cov.m_i     = m_axis_i_sym_o;
      cov.m_q     = m_axis_q_sym_o;
      cov.sample_out();

      if (exp_valid && num_matched < 5) begin
        $display("[DEROT_EXP] exp_valid at cycle %0d", k);
      end

      if (m_axis_valid_o) begin
        if (num_matched < 5) begin
          $display("[DEROT_RTL] m_axis_valid_o at cycle %0d", k);
        end
        if (exp_q_i.size() > 0) begin
          cur_ei = exp_q_i.pop_front();
          cur_eq = exp_q_q.pop_front();
          diff_i = (m_axis_i_sym_o > cur_ei) ? (m_axis_i_sym_o - cur_ei) : (cur_ei - m_axis_i_sym_o);
          diff_q = (m_axis_q_sym_o > cur_eq) ? (m_axis_q_sym_o - cur_eq) : (cur_eq - m_axis_q_sym_o);
          if (diff_i == 0 && diff_q == 0) begin
            num_matched++;
          end else begin
            $display("[FAIL][Cycle %0d] Symbol mismatch: RTL=(%0d, %0d), Exp=(%0d, %0d), diff=(%0d, %0d)",
                     k, m_axis_i_sym_o, m_axis_q_sym_o, cur_ei, cur_eq, diff_i, diff_q);
            err_count++;
          end
        end else if (k < 1270) begin
          $display("[FAIL][Cycle %0d] Unexpected extra RTL symbol!", k);
          err_count++;
        end
      end
    end

    repeat (10) @(posedge clk);

    // Ensure all expected symbols were produced by the DUT
    if (exp_q_i.size() != 0) begin
      $display("[FAIL] %0d expected symbols never produced", exp_q_i.size());
      err_count++;
    end

    cov.report();

    $display("----------------------------------------------------------");
    $display("  DEROTATOR VERIFICATION SUMMARY");
    $display("----------------------------------------------------------");
    $display("  Simulated Cycles : %0d", num_vecs);
    $display("  Symbols Matched  : %0d", num_matched);
    $display("  Errors           : %0d", err_count);
    if (err_count == 0 && num_matched > 0) begin
      $display("  STATUS: >>> PASSED <<<");
    end else begin
      $display("  STATUS: >>> FAILED <<<");
    end
    $display("==========================================================");
    $stop;
  end

endmodule
