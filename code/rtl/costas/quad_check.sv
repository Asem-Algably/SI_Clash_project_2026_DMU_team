// ============================================================================
// File Name   : quad_check.sv
// Module Name : quad_check
// Author      : Arwa Kantoush
// Description : Quadrant resolution module for 90-degree phase ambiguity resolution.
//               Accumulates sign stats to calculate initial phase adjustment.
// ============================================================================
module quad_check #(
    parameter int PW = 32
)(
    input logic clk_i,
    input logic rst_ni,
    input logic [1:0]mode_i,
    input logic valid_i,
    input logic sgn_i_pos_i,
    input logic sgn_q_pos_i,
    input logic lock_i,
    input logic preamble_end_i,
    output logic phase_adj_valid_o,
    output logic [PW-1:0]phase_adj_o,
    output logic quad_unresolved_o,
    output logic done_o
);
    localparam logic [1:0]MODE_HOLD = 2'b00;
    localparam logic signed [4:0]CNT_MAX = 5'sd15;  // Saturation max limit
    localparam logic signed [4:0]CNT_MIN = -5'sd16; // Saturation min limit

    logic signed [4:0]cnt_i_q, cnt_q_q;             // 5-bit sign counters
    logic signed [4:0]cnt_i_next, cnt_q_next;
    logic full_any, evt, unknown;
    logic neg_i, neg_q;                             // Sign bits

    always_comb begin
        cnt_i_next = cnt_i_q;
        cnt_q_next = cnt_q_q;

        if (valid_i && lock_i && !done_o) begin
            if (sgn_i_pos_i) begin
                if (cnt_i_q != CNT_MAX) begin
                    cnt_i_next = cnt_i_q + 5'sd1;   // Count up I
                end
            end else begin
                if (cnt_i_q != CNT_MIN) begin
                    cnt_i_next = cnt_i_q - 5'sd1;   // Count down I
                end
            end

            if (sgn_q_pos_i) begin
                if (cnt_q_q != CNT_MAX) begin
                    cnt_q_next = cnt_q_q + 5'sd1;   // Count up Q
                end
            end else begin
                if (cnt_q_q != CNT_MIN) begin
                    cnt_q_next = cnt_q_q - 5'sd1;   // Count down Q
                end
            end
        end

        full_any = (cnt_i_next == CNT_MAX) || (cnt_i_next == CNT_MIN) || (cnt_q_next == CNT_MAX) || (cnt_q_next == CNT_MIN); // Counter full flag
        evt = !done_o && (full_any || preamble_end_i); // Trigger evaluation
        unknown = ((cnt_i_next == 5'sd0) || (cnt_q_next == 5'sd0)); // Zero sign ambiguity
        neg_i = cnt_i_next[4];                       // Extract sign I
        neg_q = cnt_q_next[4];                       // Extract sign Q
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cnt_i_q <= '0;
            cnt_q_q <= '0;
            done_o <= 1'b0;
            phase_adj_valid_o <= 1'b0;
            phase_adj_o <= '0;
            quad_unresolved_o <= 1'b0;
        end
        else if (mode_i == MODE_HOLD) begin
            cnt_i_q <= '0;
            cnt_q_q <= '0;
            done_o <= 1'b0;
            phase_adj_valid_o <= 1'b0;
            phase_adj_o <= '0;
            quad_unresolved_o <= 1'b0;
        end
        else begin
            phase_adj_valid_o <= 1'b0;

            if (!done_o) begin
                if (!lock_i) begin
                    cnt_i_q <= '0;                   // Reset if lock lost
                    cnt_q_q <= '0;
                end
                else if (valid_i) begin
                    cnt_i_q <= cnt_i_next;
                    cnt_q_q <= cnt_q_next;
                end

                if (evt) begin
                    done_o <= 1'b1;                  // Set done flag
                    if (unknown) begin
                        quad_unresolved_o <= 1'b1;   // Set unresolved flag
                    end
                    else begin
                        phase_adj_valid_o <= 1'b1;   // Pulse valid
                        phase_adj_o <= {neg_q, neg_q ^ neg_i, {(PW-2){1'b0}}}; // Phase correction (k * pi/2)
                    end
                end
            end
        end
    end

endmodule
