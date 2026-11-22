# ==========================================================================
# Status Commands 
# Version 2021.1 4558100 win64 28-Jan-2021
# Timestamp     : 2026-11-21 03:11:46
# Description   : Provides list of commands associated with the status(s) that are exported from GUI.
# Design        : costas_top
# Database      : D:/qformal/Projects/Siclash_dmu/costas/lint.db
# ==========================================================================


lint report item  -arg parameter=MOD_QAM16  -arg count=2  -arg module1=costas_top  -arg module2=slicer  -arg file1=costas_top.sv  -arg file2=slicer.sv  -check {parameter_name_duplicate} -owner {DMU_team} -status {waived}
lint report item  -arg parameter=Qam_Level  -arg count=2  -arg module1=costas_top  -arg module2=slicer  -arg file1=costas_top.sv  -arg file2=slicer.sv  -check {parameter_name_duplicate} -owner {DMU_team} -status {waived}
lint report item  -arg parameter=Data_Width  -arg count=3  -arg module1=costas_top  -arg module2=phase_error  -arg file1=costas_top.sv  -arg file2=phase_error.sv  -check {parameter_name_duplicate} -owner {DMU_team} -status {waived}
lint report item  -arg parameter=Max_Pi_Output  -arg count=2  -arg module1=costas_top  -arg module2=pi_filter  -arg file1=costas_top.sv  -arg file2=pi_filter.sv  -check {parameter_name_duplicate} -owner {DMU_team} -status {waived}
lint report item  -arg count=6  -arg limit=5  -arg module=lock_detector  -arg file=lock_detector.sv  -check {always_signal_assign_large} -owner {DMU_team} -status {waived}
lint report item  -arg count=8  -arg limit=5  -arg module=pi_filter  -arg file=pi_filter.sv  -check {always_signal_assign_large} -owner {DMU_team} -status {waived}
lint report item  -arg count=7  -arg limit=5  -arg module=quad_check  -arg file=quad_check.sv  -check {always_signal_assign_large} -owner {DMU_team} -status {waived}
lint report item  -arg lhs_width=40  -arg rhs_width=41  -arg module=pi_filter  -arg lhs_expression=p_prop_r  -arg file=pi_filter.sv  -check {assign_width_overflow} -owner {DMU_team} -rtl_id {859e2de2_00200} -status {waived}
lint report item  -arg lhs_width=40  -arg rhs_width=41  -arg module=pi_filter  -arg lhs_expression=p_int_r  -arg file=pi_filter.sv  -check {assign_width_overflow} -owner {DMU_team} -rtl_id {da5bceef_00200} -status {waived}
lint report item  -arg expression=e_valid&&!done  -arg module=costas_top  -arg file=costas_top.sv  -check {port_conn_is_expression} -owner {DMU_team} -rtl_id {e66ad2b7_00200} -status {waived}
lint report item  -arg module=phase_error  -arg file=phase_error.sv  -check {multi_ports_in_single_line} -owner {DMU_team} -status {waived}
lint report item  -arg parameter=Gain_Frac_Bits  -arg count=2  -arg module1=costas_top  -arg module2=pi_filter  -arg file1=costas_top.sv  -arg file2=pi_filter.sv  -check {parameter_name_duplicate} -owner {DMU_team} -status {waived}
lint report item  -arg count=6  -arg limit=5  -arg module=costas_top  -arg file=costas_top.sv  -check {always_signal_assign_large} -owner {DMU_team} -status {waived}
lint report item  -arg parameter=Phase_Width  -arg count=3  -arg module1=costas_top  -arg module2=pi_filter  -arg file1=costas_top.sv  -arg file2=pi_filter.sv  -check {parameter_name_duplicate} -owner {DMU_team} -status {waived}
lint report item  -arg parameter=Gain_Width  -arg count=2  -arg module1=costas_top  -arg module2=pi_filter  -arg file1=costas_top.sv  -arg file2=pi_filter.sv  -check {parameter_name_duplicate} -owner {DMU_team} -status {waived}
lint report item  -arg parameter=MODE_HOLD  -arg count=4  -arg module1=costas_top  -arg module2=phase_error  -arg file1=costas_top.sv  -arg file2=phase_error.sv  -check {parameter_name_duplicate} -owner {DMU_team} -status {waived}
lint report item  -arg count=6  -arg limit=5  -arg module=quad_check  -arg file=quad_check.sv  -check {always_signal_assign_large} -owner {DMU_team} -status {waived}
lint report item  -arg parameter=Data_Frac_Bits  -arg count=2  -arg module1=costas_top  -arg module2=phase_error  -arg file1=costas_top.sv  -arg file2=phase_error.sv  -check {parameter_name_duplicate} -owner {DMU_team} -status {waived}
lint report item  -arg expression=m_acc+e_abs-(m_acc>>4)  -arg count=2  -arg module=lock_detector  -arg file=lock_detector.sv  -check {assign_with_multi_arith_operations} -owner {DMU_team} -rtl_id {6c411a7b_00200} -status {waived}
lint report item  -arg parameter=Error_Width  -arg count=4  -arg module1=costas_top  -arg module2=lock_detector  -arg file1=costas_top.sv  -arg file2=lock_detector.sv  -check {parameter_name_duplicate} -owner {DMU_team} -status {waived}
lint report item  -arg expression=mode_i==0  -arg module=costas_top  -arg file=costas_top.sv  -check {port_conn_is_expression} -owner {DMU_team} -rtl_id {e66ad2b7_00200} -status {waived}
lint report item  -arg expression=mode_i==0||!done||quad_unres  -arg module=costas_top  -arg file=costas_top.sv  -check {port_conn_is_expression} -owner {DMU_team} -rtl_id {e66ad2b7_00200} -status {waived}
lint report item  -arg parameter=Qpsk_Level  -arg count=2  -arg module1=costas_top  -arg module2=slicer  -arg file1=costas_top.sv  -arg file2=slicer.sv  -check {parameter_name_duplicate} -owner {DMU_team} -status {waived}

# Completed writing status commands 
# ==========================================================================

