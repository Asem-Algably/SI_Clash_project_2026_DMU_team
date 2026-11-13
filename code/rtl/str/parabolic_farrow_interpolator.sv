////////////////////////////////////////////////////////////////////////////////
// Author: Abd El-Rhman Khalifa
// Design: Parabolic Farrow Interpolator module.
// Date: 11-11-2026
// Description: Calculates the interpolated sample using a parabolic Farrow structure.
//              Handles fixed-point arithmetic (Q1.11 to Q1.15) with pipeline stages
//              and valid signal synchronization for initial conditions.
////////////////////////////////////////////////////////////////////////////////

module parabolic_farrow_interpolator 
    #( 
    // parameter definitions

    // signed fixed point representation Q1.11 for the input of the parabolic farrow interpolator
    parameter integer DATA_IN_INTEGER_WIDTH = 1, 
    parameter integer DATA_IN_FRACTIONAL_WIDTH = 11,

    // signed fixed point representation Q1.15 for the output of the parabolic farrow interpolator
    parameter integer DATA_OUT_INTEGER_WIDTH = 1,
    parameter integer DATA_OUT_FRACTIONAL_WIDTH = 15,
   
    // form the specs ( i have picked 10 bits for mu according to simulation results) 
    parameter integer MU_WIDTH = 10 
    )
    (
    // ------------ control signals ------------
    input logic clk_i,
    input logic rst_n_i, // asynchronous reset signal
    input logic valid_sample_i,

    // ------------ inputs to the parabolic farrow interpolator ------------
    input logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] x_i, // input sample to be interpolated
    input logic [MU_WIDTH-1:0] mu_i, // fractional delay value to be used for interpolation

    // ------------ outputs of the parabolic farrow interpolator ------------
    output logic signed [DATA_OUT_INTEGER_WIDTH-1:-DATA_OUT_FRACTIONAL_WIDTH] y_o, // output of the parabolic farrow interpolator
    output logic valid_sample_o // valid sample signal
    );

    // ------------ capture the input sample in a register to be used for interpolation ------------ 
    logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] x_i_reg; // i added this register to avoid timing issues if their are any routing or other combinational logic between the input sample and the parabolic farrow interpolator
    logic valid_sample_i_reg; // i added this register to avoid timing issues if their are any routing or other combinational logic between the input sample and the parabolic farrow interpolator

    // ------------ the delayed input samples (half branch) ------------ 
    // i did not reduce the number of bits for the half branch by 1 bit less than the full branch because i need to keep the sign to mantain Q1.11 format
    logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] x0_half;
    logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] x1_half;
    logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] x2_half;
    logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] x3_half;

    // ------------ the delayed input samples (not half branch) ------------
    logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] x0;
    logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] x1;
    logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] x2;
    
    // ------------ variables of the equations of the parabolic farrow interpolator ------------
    // for v1 i have added 2 bits to the integer part of the variables to avoid overflow in the calculations
    // since the max value of the variables can be 3 times the max value of the input samples which is for v1 by taking the modulus of all its terms in its equation
    // knowing that the max value of the input samples is nearly 1 and -1 for min value
    // The same xplanation applies for v2 but with 2 bit added to the integer part of the variable since the max value of v2 is 2 times the max value of the input samples
    // for v0 i did not add any extra bits to the integer part of the variable since the max value of v0 is equal to the max value of the input samples (it is only a delayed version of the input sample) 
    logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] v0;
    logic signed [DATA_IN_INTEGER_WIDTH-1 +2:-DATA_IN_FRACTIONAL_WIDTH] v1;
    logic signed [DATA_IN_INTEGER_WIDTH-1 +2:-DATA_IN_FRACTIONAL_WIDTH] v2;

    // i made a register for mu_i and mu_i_squared to avoid the timing issues of the multiplication and to make sure that the multiplication is done with the correct values of mu_i and mu_i_squared
    logic signed [0:-MU_WIDTH] mu_i_reg; // i have added 1 bit for the sign to make it in the format of Q1.N to meet the requiremets of multiplication
    logic signed [0:-DATA_OUT_FRACTIONAL_WIDTH] mu_i_squared_reg; 
    logic [(2*MU_WIDTH)-1:0] mu_i_squared; // i have added this signal to make sure that the multiplication result is 20 bits and not 10 bits (the width of mu_i) to avoid losing the fractional part of the multiplication result

    // ------------ terms of the equations of the parabolic farrow interpolator ------------
    // the final terms must be QM.15 to meet the requirements of the output of the parabolic farrow interpolator
    // i added two bits for the integer part of term2 and term3 to avoid overflow in the calculations since the max value of term2 and term3 can be 3 times and 2 times the max value of the input samples respectively

    localparam integer TERM2_BEFORE_TRANCATION_INTEGER_WIDTH = (1) + (DATA_IN_INTEGER_WIDTH-1 +2 +1); //term2_before_trancation =  mu_i_reg * v1;
    localparam integer TERM2_BEFORE_TRANCATION_FRACTIONAL_WIDTH = ((MU_WIDTH) + (DATA_IN_FRACTIONAL_WIDTH) ); //term2_before_trancation =  mu_i_reg * v1;
    
    localparam integer TERM3_BEFORE_TRANCATION_INTEGER_WIDTH = (1) + (DATA_IN_INTEGER_WIDTH-1 +2 +1); //term3_before_trancation = mu_i_squared_reg * v2;
    localparam integer TERM3_BEFORE_TRANCATION_FRACTIONAL_WIDTH = ((DATA_OUT_FRACTIONAL_WIDTH) + (DATA_IN_FRACTIONAL_WIDTH) ); //term3_before_trancation = mu_i_squared_reg * v2;

    logic signed [DATA_OUT_INTEGER_WIDTH-1 +2:-DATA_OUT_FRACTIONAL_WIDTH] term1 , term2 , term3;
    logic signed [TERM2_BEFORE_TRANCATION_INTEGER_WIDTH-1:-TERM2_BEFORE_TRANCATION_FRACTIONAL_WIDTH] term2_before_trancation ;
    logic signed [TERM3_BEFORE_TRANCATION_INTEGER_WIDTH-1:-TERM3_BEFORE_TRANCATION_FRACTIONAL_WIDTH] term3_before_trancation;


    // ------------ valid_sample_o of the parabolic farrow interpolator ------------
    logic [1:0] valid_sample_o_counter; // to count the number of valid samples to make sure that the registers till x2_half are filled with valid samples before starting the normal operation of the parabolic farrow interpolator
    logic valid_sample_o_counter_flag; // to indicate that the registers till x2_half are filled with valid samples and the normal operation of the parabolic farrow interpolator can start

    logic valid_sample_i_reg1 ,valid_sample_i_reg2 ,valid_sample_i_reg3 ; // to delay the valid_sample_i signal by 4 clock cycles to match the delay of the output of the parabolic farrow interpolator


    // ------------------------------------------------------------
    // ------------ the actual code -------------------------------
    // ------------------------------------------------------------


    // ------------ capture the input sample in a register to be used for interpolation ------------ 
    always @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            x_i_reg <= '0;
            valid_sample_i_reg <= '0;
        end else begin
            x_i_reg <= x_i ;
            valid_sample_i_reg <= valid_sample_i ;
        end
    end


    // ------------ the delayed input samples (half branch) ------------ 
    always @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            x0_half <= '0;
            x1_half <= '0;
            x2_half <= '0;
            x3_half <= '0;
        end else if (valid_sample_i_reg) begin // no need to delay the input sample if it is not valid
            x0_half <= (x_i_reg) >>> 1 ; // it is must to use the arithmetic right shift operator >>> instead of the logical right shift operator >> to avoid losing the sign of the input sample 
            x1_half <= x0_half;
            x2_half <= x1_half;
            x3_half <= x2_half;
        end
    end

    // ------------ the delayed input samples (not half branch) ------------
    always @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            x0 <= '0;
            x1 <= '0;
            x2 <= '0;
        end else if (valid_sample_i_reg) begin // no need to delay the input sample if it is not valid
            x0 <= x_i_reg;
            x1 <= x0;
            x2 <= x1;
        end
    end


    // ------------ variables of the equations of the parabolic farrow interpolator ------------
    always @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            v0 <= '0;
            v1 <= '0;
            v2 <= '0;
        end else begin  // no need to add if statement here since the samplese regesters are forsen when valid_sample_i is not active 
                        // so the values of the variables will be the same as the previous values when valid_sample_i is not active
                        // also this makes the routing more better
            v0 <=  x1;
            v1 <= -x3_half + x2_half + x2 - x1_half - x0_half ;
            v2 <= +x3_half - x2_half - x1_half + x0_half ;
        end
    end


    always @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            mu_i_reg <= '0;
            mu_i_squared_reg <= '0;
        end else begin 
            mu_i_reg <= {1'b0 , mu_i}; // i have added 1 bit for the sign to make it in the format of Q1.N to meet the requiremets of multiplication
                                     // the sign bit is 0 since mu_i is always positive
            mu_i_squared_reg <= {1'b0 , mu_i_squared[DATA_OUT_FRACTIONAL_WIDTH-1:0]};
        end
    end

    assign mu_i_squared = mu_i * mu_i; // i have added this signal to make sure that the multiplication result is 20 bits and not 10 bits (the width of mu_i) to avoid losing the fractional part of the multiplication result

    // ------------ terms of the equations of the parabolic farrow interpolator ------------
    always @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            term1 <= '0;
            term2 <= '0;
            term3 <= '0;
        end else begin
            term1 <= {v0[DATA_OUT_INTEGER_WIDTH-1 +2],v0[DATA_OUT_INTEGER_WIDTH-1 +2],v0, 4'b0000}; // the first two bits are the sign bit and the integer bit of the variable v0 and the last 4 bits are 0s to make it in the format of Q1.15 for addition requirements
            term2 <= term2_before_trancation [DATA_OUT_INTEGER_WIDTH-1 +2:-DATA_OUT_FRACTIONAL_WIDTH];
            term3 <= term3_before_trancation [DATA_OUT_INTEGER_WIDTH-1 +2:-DATA_OUT_FRACTIONAL_WIDTH];
        end     
    end

    assign term2_before_trancation =  mu_i_reg * v1;
    assign term3_before_trancation = mu_i_squared_reg * v2;

    // ------------ output of the parabolic farrow interpolator ------------
    always @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            y_o <= '0;
        end else if (valid_sample_i_reg3 & valid_sample_o_counter_flag) begin // no need to update the output if it is not valid (this makes the design more power efficient)
            y_o <= term1 + term2 + term3;
        end     
    end
    
    
    // ------------ valid_sample_o of the parabolic farrow interpolator ------------
    // 1. handling initial conditions
    // at the start of the system, there will be a counter to count 3 valid_sample_i signals to make sure thet 
    // the registers till x2_half are filled with valid samples 
    // then it will assign a flag for the rest of the operation until reset of the system
    
    // 2. handling the normarl operation
    // the update of the x_3_half takes one clocy cycle 
    // then the output comes out after 3 clock cycles
    
    // so the valid_sample_o will be assigned to valid_sample_i_reg delayed by (1+3) clock cycles
       

    // 1. handling initial conditions
    always @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            valid_sample_o_counter <= '0;
        end else if (valid_sample_i_reg && !valid_sample_o_counter_flag) begin // no need to count the valid_sample_i if it is not valid
                valid_sample_o_counter <= valid_sample_o_counter + 1'b1; 
        end 
    end

    assign valid_sample_o_counter_flag = valid_sample_o_counter[1]&valid_sample_o_counter[0]; // when the counter reaches 3, the flag will be set to 1


    // 2. handling the normarl operation
    always @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            valid_sample_i_reg1 <= '0;
            valid_sample_i_reg2 <= '0;
            valid_sample_i_reg3 <= '0;
            valid_sample_o <= '0;
        end else begin
            valid_sample_i_reg1 <= valid_sample_i_reg;
            valid_sample_i_reg2 <= valid_sample_i_reg1;
            valid_sample_i_reg3 <= valid_sample_i_reg2;
            valid_sample_o <= valid_sample_i_reg3 & valid_sample_o_counter_flag; // the output will be valid only if the counter flag is set to 1 and the valid_sample_i_reg3 is 1
        end     
    end


endmodule
