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

    // [NEW] Pipeline valid signal to align with arithmetic latency (4 stages)
    logic [4:0] valid_pipe_q;

    // ------------ capture the input sample in a register to be used for interpolation ------------ 
    logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] x_i_reg;

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
    // knowing that the max value of the input samples is nearly 1 
    // The same xplanation applies for v2 but with 1 bit added to the integer part of the variable since the max value of v2 is 2 times the max value of the input samples
    // for v0 i did not add any extra bits to the integer part of the variable since the max value of v0 is equal to the max value of the input samples (it is only a delayed version of the input sample) 
    logic signed [DATA_IN_INTEGER_WIDTH-1:-DATA_IN_FRACTIONAL_WIDTH] v0;
    logic signed [DATA_IN_INTEGER_WIDTH-1 +2:-DATA_IN_FRACTIONAL_WIDTH] v1;
    // [FIX] v2 max value is 2.0, so it needs 1 extra bit for integer part (Q2.11)
    logic signed [DATA_IN_INTEGER_WIDTH-1 +1:-DATA_IN_FRACTIONAL_WIDTH] v2;

    // i made a register for mu_i and mu_i_squared to avoid the timing issues of the multiplication and to make sure that the multiplication is done with the correct values of mu_i and mu_i_squared
    logic signed [0:-MU_WIDTH] mu_i_reg; // i have added 1 bit for the sign to make it in the format of Q1.N to meet the requiremets of multiplication
    logic signed [0:-MU_WIDTH * 2 ] mu_i_squared_reg; // the multiplication duples the number of bits in the fractional part of the result


    // ------------ terms of the equations of the parabolic farrow interpolator ------------
    // the final terms must be Q1.15 to meet the requirements of the output of the parabolic farrow interpolator
    // i did not accout for overflow (did not add an extra bit)in the terms because the max value of the terms is less than 1 and the max value of the output is also less than 1
    // according to the normalized input samples and the normalized output of the parabolic farrow interpolator
    // [FIX] Widened the terms to prevent overflow during intermediate calculations before truncation
    logic signed [DATA_OUT_INTEGER_WIDTH+2:-DATA_OUT_FRACTIONAL_WIDTH] term1 , term2 , term3;

    
    // ------------------------------------------------------------
    // ------------ the actual code -------------------------------
    // ------------------------------------------------------------

    // [NEW] Valid Pipeline delay
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            valid_pipe_q <= '0;
        end else begin
            valid_pipe_q <= {valid_pipe_q[3:0], valid_sample_i};
        end
    end
    assign valid_sample_o = valid_pipe_q[4];

    // ------------ capture the input sample in a register to be used for interpolation ------------ 
    // [FIX] Removed duplicate declaration of x_i_reg. Changed clk to clk_i and always to always_ff
    always_ff @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            x_i_reg <= '0;
        end else if (valid_sample_i) begin // no need to capture the input sample in a register if it is not valid
            x_i_reg <= x_i ;
        end
    end


    // ------------ the delayed input samples (half branch) ------------ 
    always_ff @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            x0_half <= '0;
            x1_half <= '0;
            x2_half <= '0;
            x3_half <= '0;
        end else if (valid_sample_i) begin // no need to delay the input sample if it is not valid
            x0_half <= (-x_i_reg) >>> 1 ; // it is must to use the arithmetic right shift operator >>> instead of the logical right shift operator >> to avoid losing the sign of the input sample 
                                          // it is best practice to include the sign in a parenthesis
            x1_half <= x0_half;
            x2_half <= x1_half;
            x3_half <= x2_half;
        end
    end

    // ------------ the delayed input samples (not half branch) ------------
    always_ff @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            x0 <= '0;
            x1 <= '0;
            x2 <= '0;
        end else if (valid_sample_i) begin // no need to delay the input sample if it is not valid
            x0 <= x_i_reg;
            x1 <= x0;
            x2 <= x1;
        end
    end


    // ------------ variables of the equations of the parabolic farrow interpolator ------------
    // [FIX] Corrected the mathematical equations based on the Farrow structure
    always_ff @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            v0 <= '0;
            v1 <= '0;
            v2 <= '0;
        end else begin  // no need to add if statement here since the samplese regesters are forsen when valid_sample_i is not active 
                        // so the values of the variables will be the same as the previous values when valid_sample_i is not active
                        // also this makes the routing more better
            
            // v0 = x(m-2) -> which is x2 in the delay line
            v0 <= x2; 
            
            // v1 = -0.5x(m) + 1.5x(m-1) - 0.5x(m-2) - 0.5x(m-3)
            // We can rewrite 1.5x(m-1) as x(m-1) - (-0.5x(m-1)) which is x1 - x1_half
            v1 <= x0_half + x1 - x1_half + x2_half + x3_half;
            
            // v2 = 0.5x(m) - 0.5x(m-1) - 0.5x(m-2) + 0.5x(m-3)
            // -x0_half = +0.5x(m)
            v2 <= -x0_half + x1_half + x2_half - x3_half;
        end
    end


    always_ff @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            mu_i_reg <= '0;
            mu_i_squared_reg <= '0;
        end else begin 
            mu_i_reg <= {1'b0 , mu_i}; // i have added 1 bit for the sign to make it in the format of Q1.N to meet the requiremets of multiplication
                                     // the sign bit is 0 since mu_i is always positive
            mu_i_squared_reg <= {1'b0 , mu_i * mu_i};
        end
    end


    // ------------ terms of the equations of the parabolic farrow interpolator ------------
    // [FIX] Added proper right shifts (>>>) to align the decimal points to Q1.15
    always_ff @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            term1 <= '0;
            term2 <= '0;
            term3 <= '0;
        end else begin
            // term1 is Q1.11, to make it Q1.15 we shift left by 4
            term1 <= v0 <<< 4;
            
            // v1 is Q3.11, mu_i_reg is Q1.10. Product is Q4.21. Shift right by 6 to get Q4.15.
            term2 <= (mu_i_reg * v1) >>> 6;
            
            // v2 is Q2.11, mu_i_squared_reg is Q1.20. Product is Q3.31. Shift right by 16 to get Q3.15.
            term3 <= (mu_i_squared_reg * v2) >>> 16;
        end     
    end


    // ------------ output of the parabolic farrow interpolator ------------
    // [FIX] Added valid_pipe_q[3] condition to ensure output is only updated when data is valid
    always_ff @(posedge clk_i or negedge rst_n_i ) begin
        if (!rst_n_i) begin
            y_o <= '0;
        end else if (valid_pipe_q[3]) begin
            y_o <= term1 + term2 + term3;
        end     
    end
    
    
endmodule