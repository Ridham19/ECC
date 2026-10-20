`timescale 1ns / 1ps

module tb_product_code;

    reg  [63:0] orig_data;
    reg  [6:0]  flip_pos1;
    reg  [6:0]  flip_pos2;

    wire [7:0]  tx_row_parity;
    wire [7:0]  tx_col_parity;
    wire [63:0] rx_data;
    wire [63:0] corrected_data;
    wire        single_error_detected;
    wire        error_corrected;
    wire        multiple_errors;

    // Instantiate Top Module
    product_code_top uut (
        .orig_data(orig_data),
        .flip_pos1(flip_pos1),
        .flip_pos2(flip_pos2),
        .tx_row_parity(tx_row_parity),
        .tx_col_parity(tx_col_parity),
        .rx_data(rx_data),
        .corrected_data(corrected_data),
        .single_error_detected(single_error_detected),
        .error_corrected(error_corrected),
        .multiple_errors(multiple_errors)
    );

    integer file_in, file_out, r;

    initial begin
        file_in  = $fopen("product_input_vector.txt", "r");
        file_out = $fopen("product_output_vector.txt", "w");

        if (file_in == 0) begin
            $display("ERROR: Could not open product_input_vector.txt");
            $finish;
        end

        if (file_out == 0) begin
            $display("ERROR: Could not open product_output_vector.txt");
            $finish;
        end

        $fdisplay(file_out, "# Orig_Data Flip1 Flip2 Row_Parity Col_Parity Corrected_Data Single_Err Corrected_Flag Multi_Err");

        while (!$feof(file_in)) begin
            r = $fscanf(file_in, "%h %d %d\n", orig_data, flip_pos1, flip_pos2);
            if (r == 3) begin
                #10; // Wait for combinational logic
                $fdisplay(file_out, "%016h %2d %2d %02h %02h %016h %b %b %b",
                    orig_data,
                    flip_pos1,
                    flip_pos2,
                    tx_row_parity,
                    tx_col_parity,
                    corrected_data,
                    single_error_detected,
                    error_corrected,
                    multiple_errors
                );
            end
        end

        $fclose(file_in);
        $fclose(file_out);
        $display("Simulation complete. Results written to product_output_vector.txt");
        $finish;
    end

endmodule
