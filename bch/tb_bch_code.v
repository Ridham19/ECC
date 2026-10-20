`timescale 1ns / 1ps

module tb_bch_code;

    reg  [63:0] orig_data;
    reg  [7:0]  flip_pos1;
    reg  [7:0]  flip_pos2;

    wire [77:0] tx_codeword;
    wire [77:0] rx_codeword;
    wire [63:0] corrected_data;
    wire        single_error_detected;
    wire        double_error_detected;
    wire        uncorrectable_error;
    wire        error_corrected;

    // Instantiate Top Module
    bch_code_top uut (
        .orig_data(orig_data),
        .flip_pos1(flip_pos1),
        .flip_pos2(flip_pos2),
        .tx_codeword(tx_codeword),
        .rx_codeword(rx_codeword),
        .corrected_data(corrected_data),
        .single_error_detected(single_error_detected),
        .double_error_detected(double_error_detected),
        .uncorrectable_error(uncorrectable_error),
        .error_corrected(error_corrected)
    );

    integer file_in, file_out, r;

    initial begin
        file_in  = $fopen("bch_input_vector.txt", "r");
        file_out = $fopen("bch_output_vector.txt", "w");

        if (file_in == 0) begin
            $display("ERROR: Could not open bch_input_vector.txt");
            $finish;
        end

        if (file_out == 0) begin
            $display("ERROR: Could not open bch_output_vector.txt");
            $finish;
        end

        $fdisplay(file_out, "# Orig_Data Flip1 Flip2 Codeword Corrected_Data Single_Err Double_Err Uncorrectable Corrected_Flag");

        while (!$feof(file_in)) begin
            r = $fscanf(file_in, "%h %d %d\n", orig_data, flip_pos1, flip_pos2);
            if (r == 3) begin
                #10; // Wait for combinational propagation
                $fdisplay(file_out, "%016h %3d %3d %020h %016h %b %b %b %b",
                    orig_data,
                    flip_pos1,
                    flip_pos2,
                    rx_codeword,
                    corrected_data,
                    single_error_detected,
                    double_error_detected,
                    uncorrectable_error,
                    error_corrected
                );
            end
        end

        $fclose(file_in);
        $fclose(file_out);
        $display("Simulation complete. Results written to bch_output_vector.txt");
        $finish;
    end

endmodule
