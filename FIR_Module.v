module fir #(
    parameter TAPS = 8,
    parameter DATA_WIDTH = 16,      // input sample width (signed)
    parameter COEFF_WIDTH = 16,     // coefficient width (signed)
    parameter OUT_WIDTH = 32        // accumulator/output width (must be large enough)
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire signed [DATA_WIDTH-1:0]  in_sample,
    input  wire                          in_valid,
    output reg  signed [OUT_WIDTH-1:0]   out_sample,
    output reg                           out_valid
);

    reg signed [DATA_WIDTH-1:0] taps_reg [0:TAPS-1];
    integer i;
  
    localparam signed [COEFF_WIDTH-1:0] coeffs [0:TAPS-1] = {
        16'sd1638,  // 0.05 * 32768 ≈ 1638
        16'sd3277,  // 0.10
        16'sd4915,  // 0.15
        16'sd6553,  // 0.20
        16'sd6553,  // 0.20
        16'sd4915,  // 0.15
        16'sd3277,  // 0.10
        16'sd1638   // 0.05
    };

    // Accumulator width should fit DATA_WIDTH + COEFF_WIDTH + log2(TAPS)
    reg signed [OUT_WIDTH-1:0] acc;
    reg [31:0] sample_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<TAPS; i=i+1) taps_reg[i] <= 0;
            acc <= 0;
            out_sample <= 0;
            out_valid <= 0;
            sample_count <= 0;
        end else begin
            out_valid <= 0;
            if (in_valid) begin
                // shift
                for (i=TAPS-1; i>0; i=i-1) taps_reg[i] <= taps_reg[i-1];
                taps_reg[0] <= in_sample;

                // MAC
                acc <= 0;
                // compute accumulation in wider signed arithmetic
                // multiply sample (Q1.(DATA_WIDTH-1)) * coeff (Q1.(COEFF_WIDTH-1))
                // product has Q2.(DATA_WIDTH+COEFF_WIDTH-2) so adjust later
                for (i=0; i<TAPS; i=i+1) begin
                    // sign-extend before multiply
                    acc <= acc + ( $signed(taps_reg[i]) * $signed(coeffs[i]) );
                end

                // output: note scaling — product is scaled by 2^(DATA_WIDTH-1 + COEFF_WIDTH-1)
                // If DATA_WIDTH=16 and COEFF_WIDTH=16 and we treat coeffs as Q1.15 and data as Q1.15,
                // then to get back to Q1.15 we need to >> (COEFF_FRACTION_BITS)
                // Here we perform a right shift by COEFF_FRAC (COEFF_WIDTH-1)
                out_sample <= acc >>> (COEFF_WIDTH-1);
                out_valid <= 1'b1;
                sample_count <= sample_count + 1;
            end
        end
    end

endmodule
