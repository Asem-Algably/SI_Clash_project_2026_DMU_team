interface coarse_cfo_core_inter (input bit clk);
    logic                rst_ni;
    logic                start_i;
    logic                s_axis_valid_i;
    logic signed [15:0]  s_axis_i_sym_i;
    logic signed [15:0]  s_axis_q_sym_i;
    logic                m_axis_valid_o;
    logic signed [23:0]  m_axis_cfo_o;
    logic                force_cfo_en_i;
    logic [23:0]         force_cfo_i;

    task force_rst_low();
        force rst_ni = 1'b0;
    endtask

    task force_rst_high();
        force rst_ni = 1'b1;
    endtask

    task release_rst_ni();
        release rst_ni;
    endtask
endinterface