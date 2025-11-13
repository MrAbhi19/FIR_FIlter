`timescale 1ns/1ps
module tb_fir;
    parameter TAPS = 8;
    parameter DATA_WIDTH = 16;
    parameter COEFF_WIDTH = 16;
    parameter OUT_WIDTH = 40;
    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz clock (10 ns)

    reg rst_n;
    reg signed [DATA_WIDTH-1:0] in_sample;
    reg in_valid;
    wire signed [OUT_WIDTH-1:0] out_sample;
    wire out_valid;

    integer outfile;
    integer i;
    integer N = 1024;

    fir #(
        .TAPS(TAPS),
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_sample(in_sample),
        .in_valid(in_valid),
        .out_sample(out_sample),
        .out_valid(out_valid)
    );

    // Generate stimulus: sine wave + noise
    real pi = 3.141592653589793;
    real freq = 1000.0; // 1kHz
    real fs = 48000.0;  // sample rate
    real t;
    real noise;
    initial begin
        outfile = $fopen("fir_output.csv","w");
        $fdisplay(outfile, "sample_index,in,filtered");
        rst_n = 0;
        in_valid = 0;
        in_sample = 0;
        #50;
        rst_n = 1;
        #50;
        for (i=0; i<N; i=i+1) begin
            t = i / fs;
            // sine amplitude scaled to Q1.15
            in_sample = $rtoi( (0.7) * 32767.0 * $sin(2.0*pi*freq*t) );
            // add tiny noise occasionally
            if (i % 50 == 0) in_sample = in_sample + $rtoi( (0.05*32767.0) * ($random % 100) / 100.0 );
            in_valid = 1;
            @(posedge clk);
            // on output valid, write to file
            if (out_valid) begin
                // out_sample currently scaled Q1.15 (after shift)
                $fdisplay(outfile, "%0d,%0d,%0d", i, in_sample, out_sample);
            end else begin
                $fdisplay(outfile, "%0d,%0d,%0d", i, in_sample, out_sample);
            end
        end
        $fclose(outfile);
        #200;
        $stop;
    end

endmodule
