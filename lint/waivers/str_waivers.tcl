# ==========================================================================
# Status Commands 
# Version 2021.1 4558100 win64 28-Jan-2021
# Timestamp     : 2026-11-21 19:28:19
# Description   : Provides list of commands associated with the status(s) that are exported from GUI.
# Design        : str_top
# Database      : C:/QFT_2021.1/QFT_2021.1/QFT/V2021.1/win64/bin/lint.db
# ==========================================================================


lint report item  -arg expression=(c12<<1)+c12-d12-b12-a12  -arg count=4  -arg module=parabolic_farrow_interpolator  -arg file=K:/Digital_IC/kareem_waseem_course/Digital_Design_Diploma/questa_lint_files/parabolic_farrow_interpolator.sv  -check {assign_with_multi_arith_operations} -message {it is ok to have it} -owner {DMU_team} -rtl_id {a66bd226_00200} -status {waived}
lint report item  -arg expression=m_acc+e_abs_r-(m_acc>>4)  -arg count=2  -arg module=lock_detector  -arg file=K:/Digital_IC/kareem_waseem_course/Digital_Design_Diploma/questa_lint_files/lock_detector.sv  -check {assign_with_multi_arith_operations} -message {it is ok to have it} -owner {DMU_team} -rtl_id {a87bc705_00200} -status {waived}
lint report item  -arg expression=d12-c12-b12+a12  -arg count=3  -arg module=parabolic_farrow_interpolator  -arg file=K:/Digital_IC/kareem_waseem_course/Digital_Design_Diploma/questa_lint_files/parabolic_farrow_interpolator.sv  -check {assign_with_multi_arith_operations} -message {it is ok to have it} -owner {DMU_team} -rtl_id {89159688_00200} -status {waived}
lint report item  -arg width=16  -arg master_module=lock_detector  -arg argument_width=23  -arg module=str_top  -arg name=Init_Error  -arg master_file=K:/Digital_IC/kareem_waseem_course/Digital_Design_Diploma/questa_lint_files/lock_detector.sv  -arg file=K:/Digital_IC/kareem_waseem_course/Digital_Design_Diploma/questa_lint_files/str_top.sv  -check {inst_param_width_overflow} -message {the values is ok} -owner {DMU_team} -rtl_id {c095d0a9_00200} -status {waived}

# Completed writing status commands 
# ==========================================================================

