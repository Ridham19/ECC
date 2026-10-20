`timescale 1ns / 1ps

module tb_parity_check;

    reg  [63:0] orig_data;
    reg         parity_type;    // 0 = Even, 1 = Odd
    reg  [6:0]  flip_bit_pos;   // 0..63: data bit flip, 64: parity bit flip, >64: no flip

    wire [63:0] rx_data;
    wire        generated_parity;
    wire        rx_parity;
    wire        error_detected;

    // Instantiate Top Module
    parity_check_top uut (
        .orig_data(orig_data),
        .parity_type(parity_type),
        .flip_bit_pos(flip_bit_pos),
        .rx_data(rx_data),
        .generated_parity(generated_parity),
        .rx_parity(rx_parity),
        .error_detected(error_detected)
    );

    integer file_in, file_out, r;

    initial begin
        file_in  = $fopen("input_vector.txt", "r");
        file_out = $fopen("output_vector.txt", "w");

        if (file_in == 0) begin
            $display("ERROR: Could not open input_vector.txt");
            $finish;
        end

        if (file_out == 0) begin
            $display("ERROR: Could not open output_vector.txt");
            $finish;
        end

        // Header for output file
        $fdisplay(file_out, "# Orig_Data Parity_Type Flip_Pos Gen_Parity RX_Parity Error_Detected");

        while (!$feof(file_in)) begin
            r = $fscanf(file_in, "%h %d %d\n", orig_data, parity_type, flip_bit_pos);
            if (r == 3) begin
                #10; // Wait for combinational logic propagation
                $fdisplay(file_out, "%016h %d %2d %b %b %b",
                    orig_data,
                    parity_type,
                    flip_bit_pos,
                    generated_parity,
                    rx_parity,
                    error_detected
                );
            end
        end

        $fclose(file_in);
        $fclose(file_out);
        $display("Simulation complete. Results written to output_vector.txt");
        $finish;
    end

endmodule
