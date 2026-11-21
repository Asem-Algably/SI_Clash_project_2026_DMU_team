`timescale 1ns / 1ps
import costas_pkg::*;

module tb_costas_top;

  localparam int MAX_VECS = 20000;
  logic [123:0] vec_mem [0:MAX_VECS-1];
  logic [3:0]   v_val, v_mode, v_pe, v_mod, v_exp_fval, v_exp_pval, v_exp_lock;

  logic                clk = 1'b0;
  logic                rst_n;
  logic                s_axis_valid_i;
  logic signed [15:0]  s_axis_i_sym_i, s_axis_q_sym_i;
  logic [1:0]          mode_i;
  logic                preamble_end_i;
  logic [1:0]          mod_type_i;

  logic                freq_adj_valid_o;
  logic signed [31:0]  freq_adj_o;
  logic                phase_adj_valid_o;
  logic        [31:0]  phase_adj_o;
  logic                lock_o;

  logic                exp_freq_valid;
  logic signed [31:0]  exp_freq_adj;
  logic                exp_phase_valid;
  logic        [31:0]  exp_phase_adj;
  logic                exp_lock;

  int num_vecs = 0;
  int err_count = 0;
  int checks_passed = 0;
  int diff;

  costas_transaction tr;

  always #4 clk = ~clk;

  logic                preamble_seen;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      preamble_seen <= 1'b0;
    end else if (preamble_end_i) begin
      preamble_seen <= 1'b1;
    end
  end

  costas_top u_costas (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .s_axis_valid_i   (s_axis_valid_i),
    .s_axis_i_sym_i   (s_axis_i_sym_i),
    .s_axis_q_sym_i   (s_axis_q_sym_i),
    .mod_type_i       (mod_type_i),
    .costas_gain_i    (8'd0),
    .mode_i           (mode_i),
    .slicer_qpsk_i    (mode_i != 2'b10), // 2'b10 is MODE_TRACK (16-QAM in payload)
    .preamble_end_i   (preamble_end_i),
    .freq_adj_valid_o (freq_adj_valid_o),
    .freq_adj_o       (freq_adj_o),
    .int_o            (),
    .phase_adj_valid_o(phase_adj_valid_o),
    .phase_adj_o      (phase_adj_o),
    .quad_unresolved_o(),
    .lock_o           (lock_o),
    .dbg_e_o          (),
    .dbg_e_valid_o    (),
    .dbg_lock_int_o   (),
    .dbg_quad_done_o  ()
  );

  initial begin
    tr = new();

    $display("==========================================================");
    $display("  TB: costas_top (Golden Model Bit-Accurate Verification)");
    $display("==========================================================");

    $readmemh("code/tb/vectors/tb_costas_vec.hex", vec_mem);

    while (vec_mem[num_vecs] !== 124'hx && num_vecs < MAX_VECS) begin
      num_vecs++;
    end
    $display("Loaded %0d vectors from code/tb/vectors/tb_costas_vec.hex", num_vecs);

    if (num_vecs == 0) begin
      $display("ERROR: No vectors loaded!");
      $stop;
    end

    // Reset sequence
    rst_n          = 1'b0;
    s_axis_valid_i = 1'b0;
    s_axis_i_sym_i = '0;
    s_axis_q_sym_i = '0;
    mode_i         = '0;
    preamble_end_i = 1'b0;
    mod_type_i     = '0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    for (int k = 0; k < num_vecs; k++) begin
      {v_val, s_axis_i_sym_i, s_axis_q_sym_i,
       v_mode, v_pe, v_mod,
       v_exp_fval, exp_freq_adj,
       v_exp_pval, exp_phase_adj,
       v_exp_lock} = vec_mem[k];
      s_axis_valid_i  = v_val[0];
      mode_i          = v_mode[1:0];
      preamble_end_i  = v_pe[0];
      mod_type_i      = v_mod[1:0];
      exp_freq_valid  = v_exp_fval[0];
      exp_phase_valid = v_exp_pval[0];
      exp_lock        = v_exp_lock[0];

      if (mode_i != 2'b11) begin
        tr.mode         = mode_e'(mode_i);
        tr.mod_type     = (mod_type_i == 2'b01) ? QAM16 : QPSK;
        tr.valid        = s_axis_valid_i;
        tr.i_sym        = s_axis_i_sym_i;
        tr.q_sym        = s_axis_q_sym_i;
        tr.preamble_end = preamble_end_i;
        tr.slicer_qpsk  = (mode_i != 2'b10);
        tr.sample_in();
      end

      @(posedge clk);
      #1;

      tr.e               = u_costas.e;
      tr.e_valid         = u_costas.e_valid;
      tr.freq_adj        = freq_adj_o;
      tr.freq_adj_valid  = freq_adj_valid_o;
      tr.int_val         = u_costas.int_o;
      tr.phase_adj       = phase_adj_o;
      tr.phase_adj_valid = phase_adj_valid_o;
      tr.lock            = lock_o;
      tr.lock_int        = u_costas.lock_int;
      tr.quad_done       = u_costas.done;
      tr.quad_unres      = u_costas.quad_unres;
      tr.kp              = u_costas.kp;
      tr.sample_out();

      // Check frequency adjustment (Strict 100% bit-exact check)
      if (exp_freq_valid && freq_adj_valid_o) begin
        diff = (freq_adj_o > exp_freq_adj) ? (freq_adj_o - exp_freq_adj) : (exp_freq_adj - freq_adj_o);
        if (diff == 0) begin
          checks_passed++;
        end else begin
          $display("[FAIL][Cycle %0d] Freq adj mismatch: RTL=%0d, Exp=%0d, diff=%0d",
                   k, freq_adj_o, exp_freq_adj, diff);
          err_count++;
        end
      end

      // Check phase adjustment pulse
      if (exp_phase_valid && phase_adj_valid_o) begin
        if (phase_adj_o == exp_phase_adj) begin
          checks_passed++;
        end else begin
          $display("[FAIL][Cycle %0d] Phase adj mismatch: RTL=%h, Exp=%h",
                   k, phase_adj_o, exp_phase_adj);
          err_count++;
        end
      end
    end

    repeat (10) @(posedge clk);

    $display("----------------------------------------------------------");
    $display("  COSTAS LOOP VERIFICATION SUMMARY");
    $display("----------------------------------------------------------");
    $display("  Simulated Cycles : %0d", num_vecs);
    $display("  Checks Passed    : %0d", checks_passed);
    $display("  Errors           : %0d", err_count);
    if (err_count == 0 && checks_passed > 0) begin
      $display("  STATUS: >>> PASSED <<<");
    end else begin
      $display("  STATUS: >>> FAILED <<<");
    end
    tr.report();
    $display("==========================================================");
    $stop;
  end

endmodule
