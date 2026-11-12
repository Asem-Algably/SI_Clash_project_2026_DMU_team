// ============================================================================
// File Name   : slicer.sv
// Module Name : slicer
// Author      : Arwa Kantoush
// Description : Decision-directed constellation slicer for QPSK and 16-QAM.
//               Generates constellation decisions and sign flags for I/Q.
// ============================================================================
module slicer #(
    parameter int                           Data_Width = 16,
    parameter logic signed [Data_Width-1:0] Qpsk_Level = 16'sd16384, // QPSK (+-0.5 in Q1.15)
    parameter logic signed [Data_Width-1:0] Qam_Level  = 16'sd5461   // 16-QAM (+-0.5/3 in Q1.15)
)(
    input  logic signed [Data_Width-1:0] yi_i,
    input  logic signed [Data_Width-1:0] yq_i,
    input  logic        [1:0]            mod_type_i,              // 2'b00=QPSK, 2'b01=16-QAM
    input  logic                         slicer_qpsk_i,           // Force QPSK (Preamble)

    output logic signed [Data_Width-1:0] ai_o,
    output logic signed [Data_Width-1:0] aq_o,
    output logic                         sgn_i_pos_o,           // Sign I (1=pos)
    output logic                         sgn_q_pos_o            // Sign Q (1=pos)
);
    localparam logic [1:0] MOD_QAM16 = 2'b01;
    localparam logic signed [Data_Width-1:0] D3 = 3 * Qam_Level;     // 3d
    localparam logic signed [Data_Width-1:0] T2 = 2 * Qam_Level;     // 2d boundary

    logic use_qam;

    always_comb begin
        use_qam = (mod_type_i == MOD_QAM16) && !slicer_qpsk_i;

        // I axis. Same tie rule as qam_slicer.m: +T2 -> outer, -T2 -> inner, 0 -> +d
        if (use_qam) begin
            if (yi_i >= 0) begin
                ai_o = (yi_i >= T2) ?  D3 : Qam_Level;
            end
            else begin
                ai_o = (yi_i <  -T2) ? -D3 : -Qam_Level;
            end
        end
        else begin
            ai_o = (yi_i[Data_Width-1]) ? -Qpsk_Level : Qpsk_Level;
        end

        // Q axis
        if (use_qam) begin
            if (yq_i >= 0) begin
                aq_o = (yq_i >=  T2) ?  D3 : Qam_Level;
            end
            else begin
                aq_o = (yq_i <  -T2) ? -D3 : -Qam_Level;
            end
        end
        else begin
            aq_o = yq_i[Data_Width-1] ? -Qpsk_Level : Qpsk_Level;
        end

        sgn_i_pos_o = ~yi_i[Data_Width-1];
        sgn_q_pos_o = ~yq_i[Data_Width-1];
    end
endmodule
