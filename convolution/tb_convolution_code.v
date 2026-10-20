`timescale 1ns / 1ps

module tb_convolution_code;

    reg  [63:0]  orig_data;
    reg  [7:0]   flip_pos1;
    reg  [7:0]   flip_pos2;

    wire [131:0] tx_codeword;
    wire [131:0] rx_codeword;
    wire [63:0]  corrected_data;
    wire         error_detected;
    wire         error_corrected;

    // Instantiate Top Module
    convolution_code_top uut (
        .orig_data(orig_data),
        .flip_pos1(flip_pos1),
        .flip_pos2(flip_pos2),
        .tx_codeword(tx_codeword),
        .rx_codeword(rx_codeword),
        .corrected_data(corrected_data),
        .error_detected(error_detected),
        .error_corrected(error_corrected)
    );

    integer file_in, file_out, r;

    initial begin
        file_in  = $fopen("convolution_input_vector.txt", "r");
        file_out = $fopen("convolution_output_vector.txt", "w");

        if (file_in == 0) begin
            $display("ERROR: Could not open convolution_input_vector.txt");
            $finish;
        end

        if (file_out == 0) begin
            $display("ERROR: Could not open convolution_output_vector.txt");
            $finish;
        end

        $fdisplay(file_out, "# Orig_Data Flip1 Flip2 Codeword Corrected_Data Err_Detected Err_Corrected");

        while (!$feof(file_in)) begin
            r = $fscanf(file_in, "%h %d %d\n", orig_data, flip_pos1, flip_pos2);
            if (r == 3) begin
                #10; // Wait for combinational propagation
                $fdisplay(file_out, "%016h %3d %3d %033h %016h %b %b",
                    orig_data,
                    flip_pos1,
                    flip_pos2,
                    rx_codeword,
                    corrected_data,
                    error_detected,
                    error_corrected
                );
            end
        end

        $fclose(file_in);
        $fclose(file_out);
        $display("Simulation complete. Results written to convolution_output_vector.txt");
        $finish;
    end

endmodule
