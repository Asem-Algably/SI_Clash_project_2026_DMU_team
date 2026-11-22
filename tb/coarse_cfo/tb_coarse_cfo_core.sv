`timescale 1ns / 1ps

module tb_coarse_cfo_core;

  localparam int MAX_VECS = 20000;
  logic [67:0] vec_mem [0:MAX_VECS-1];
  logic [3:0]  v_val, v_start, v_exp_val;

  logic                clk = 1'b0;
  logic                rst_n;
  logic                start_i;
  logic                s_axis_valid_i;
  logic signed [15:0]  s_axis_i_sym_i, s_axis_q_sym_i;

  logic                m_axis_valid_o;
  logic signed [23:0]  m_axis_cfo_o;

  logic                exp_valid;
  logic signed [23:0]  exp_cfo;
  logic signed [23:0]  latched_exp_cfo, latched_rtl_cfo;
  logic                exp_seen, rtl_seen, compared;

  int num_vecs = 0;
  int err_count = 0;
  int cfo_matched = 0;
  int diff;

  always #4 clk = ~clk;

  coarse_cfo_core #(
    .DataWidth(16),
    .Lag      (4),
    .WinLen   (32),
    .AccWidth (40)
  ) u_coarse (
    .clk_i          (clk),
    .rst_ni         (rst_n),
    .start_i        (start_i),
    .s_axis_valid_i (s_axis_valid_i),
    .s_axis_i_sym_i (s_axis_i_sym_i),
    .s_axis_q_sym_i (s_axis_q_sym_i),
    .m_axis_valid_o (m_axis_valid_o),
    .m_axis_cfo_o   (m_axis_cfo_o),
    .force_cfo_en_i (1'b0),
    .force_cfo_i    (24'd0)
  );

  initial begin
    $display("==========================================================");
    $display("  TB: coarse_cfo_core (Golden Model Bit-Accurate Verification)");
    $display("==========================================================");

    $readmemh("tb/vectors/tb_coarse_vec.hex", vec_mem);

    while (vec_mem[num_vecs] !== 68'hx && num_vecs < MAX_VECS) begin
      num_vecs++;
    end
    $display("Loaded %0d vectors from tb/vectors/tb_coarse_vec.hex", num_vecs);

    if (num_vecs == 0) begin
      $display("ERROR: No vectors loaded!");
      $stop;
    end

    // Reset sequence
    rst_n           = 1'b0;
    start_i         = 1'b0;
    s_axis_valid_i  = 1'b0;
    s_axis_i_sym_i  = '0;
    s_axis_q_sym_i  = '0;
    latched_exp_cfo = '0;
    latched_rtl_cfo = '0;
    exp_seen        = 1'b0;
    rtl_seen        = 1'b0;
    compared        = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    for (int k = 0; k < num_vecs; k++) begin
      {v_val, s_axis_i_sym_i, s_axis_q_sym_i, v_start, v_exp_val, exp_cfo} = vec_mem[k];
      s_axis_valid_i = v_val[0];
      start_i        = v_start[0];
      exp_valid      = v_exp_val[0];

      @(posedge clk);
      #1;

      if (s_axis_valid_i && k <= 240) begin
        $display("[STANDALONE_COARSE_IN][k=%0d] start=%0d count=%0d active=%0d",
                 k, start_i,
                 u_coarse.u_accumulator.count_q,
                 u_coarse.u_accumulator.active_q);
      end

      if (u_coarse.u_accumulator.valid_o) begin
        $display("[Cycle %0d] ACCUMULATOR valid_o fired", k);
      end
      if (u_coarse.u_cordic_angle.valid_o) begin
        $display("[Cycle %0d] CORDIC valid_o fired", k);
      end
      if (m_axis_valid_o) begin
        $display("[Cycle %0d] RTL coarse_valid fired: cfo=%0d (hex %h)", k, m_axis_cfo_o, m_axis_cfo_o);
        latched_rtl_cfo = m_axis_cfo_o;
        rtl_seen        = 1'b1;
      end
      if (exp_valid) begin
        $display("[Cycle %0d] EXP coarse_valid fired: cfo=%0d (hex %h)", k, exp_cfo, exp_cfo);
        latched_exp_cfo = exp_cfo;
        exp_seen        = 1'b1;
      end

      if ((exp_seen && rtl_seen) && !compared) begin
        compared = 1'b1;
        diff = (latched_rtl_cfo > latched_exp_cfo) ? (latched_rtl_cfo - latched_exp_cfo) : (latched_exp_cfo - latched_rtl_cfo);
        $display("[Cycle %0d] Coarse CFO comparison: RTL=%0d, Exp=%0d, diff=%0d", k, latched_rtl_cfo, latched_exp_cfo, diff);
        if (diff == 0) begin
          cfo_matched++;
        end else begin
          $display("[FAIL][Cycle %0d] CFO estimate mismatch: RTL=%0d, Exp=%0d, diff=%0d", k, latched_rtl_cfo, latched_exp_cfo, diff);
          err_count++;
        end
      end
    end

    repeat (10) @(posedge clk);

    $display("----------------------------------------------------------");
    $display("  COARSE CFO VERIFICATION SUMMARY");
    $display("----------------------------------------------------------");
    $display("  Simulated Cycles : %0d", num_vecs);
    $display("  CFO Matches      : %0d", cfo_matched);
    $display("  Errors           : %0d", err_count);
    if (err_count == 0 && cfo_matched > 0) begin
      $display("  STATUS: >>> PASSED <<<");
    end else begin
      $display("  STATUS: >>> FAILED <<<");
    end
    $display("==========================================================");
    $stop;
  end

endmodule
