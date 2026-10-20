`timescale 1ns / 1ps

module tb_hamming_code;

    reg  [63:0] orig_data;
    reg  [7:0]  flip_pos1;
    reg  [7:0]  flip_pos2;

    wire [71:0] tx_codeword;
    wire [71:0] rx_codeword;
    wire [63:0] corrected_data;
    wire        single_error_detected;
    wire        double_error_detected;
    wire        error_corrected;

    // Instantiate Top Module
    hamming_code_top uut (
        .orig_data(orig_data),
        .flip_pos1(flip_pos1),
        .flip_pos2(flip_pos2),
        .tx_codeword(tx_codeword),
        .rx_codeword(rx_codeword),
        .corrected_data(corrected_data),
        .single_error_detected(single_error_detected),
        .double_error_detected(double_error_detected),
        .error_corrected(error_corrected)
    );

    integer file_in, file_out, r;

    initial begin
        file_in  = $fopen("hamming_input_vector.txt", "r");
        file_out = $fopen("hamming_output_vector.txt", "w");

        if (file_in == 0) begin
            $display("ERROR: Could not open hamming_input_vector.txt");
            $finish;
        end

        if (file_out == 0) begin
            $display("ERROR: Could not open hamming_output_vector.txt");
            $finish;
        end

        $fdisplay(file_out, "# Orig_Data Flip1 Flip2 Codeword Corrected_Data Single_Err Double_Err Corrected_Flag");

        while (!$feof(file_in)) begin
            r = $fscanf(file_in, "%h %d %d\n", orig_data, flip_pos1, flip_pos2);
            if (r == 3) begin
                #10; // Wait for combinational propagation
                $fdisplay(file_out, "%016h %3d %3d %018h %016h %b %b %b",
                    orig_data,
                    flip_pos1,
                    flip_pos2,
                    rx_codeword,
                    corrected_data,
                    single_error_detected,
                    double_error_detected,
                    error_corrected
                );
            end
        end

        $fclose(file_in);
        $fclose(file_out);
        $display("Simulation complete. Results written to hamming_output_vector.txt");
        $finish;
    end

endmodule
