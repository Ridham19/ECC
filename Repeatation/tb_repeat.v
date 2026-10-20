`timescale 1ns / 1ps

// ============================================================================
// Module: tb_repeat
// Description: Testbench for (3,1) Repetition Code Module (64-bit).
//              Reads input test vectors from 'repeat_input_vector.txt',
//              runs simulation through hardware top wrapper repeater_top_64b,
//              and writes the resulting output vectors to 'repeat_output_vector.txt'.
// ============================================================================
module tb_repeat;

    reg  [63:0] orig_data;
    reg  [7:0]  flip_pos1;
    reg  [7:0]  flip_pos2;

    wire [191:0] tx_codeword;
    wire [191:0] rx_codeword;
    wire [63:0]  decoded_data;
    wire         error_detected;

    // Instantiate Top Module (Hardware Encoder + Channel Noise + Decoder)
    repeater_top_64b uut (
        .orig_data(orig_data),
        .flip_pos1(flip_pos1),
        .flip_pos2(flip_pos2),
        .tx_codeword(tx_codeword),
        .rx_codeword(rx_codeword),
        .decoded_data(decoded_data),
        .error_detected(error_detected)
    );

    integer file_in, file_out, r;

    initial begin
        file_in  = $fopen("repeat_input_vector.txt", "r");
        file_out = $fopen("repeat_output_vector.txt", "w");

        if (file_in == 0) begin
            $display("ERROR: Could not open repeat_input_vector.txt");
            $finish;
        end

        if (file_out == 0) begin
            $display("ERROR: Could not open repeat_output_vector.txt");
            $finish;
        end

        // Write header for output vector file
        $fdisplay(file_out, "# Orig_Data Flip1 Flip2 Decoded_Data Error_Detected");

        while (!$feof(file_in)) begin
            r = $fscanf(file_in, "%h %d %d\n", orig_data, flip_pos1, flip_pos2);
            if (r == 3) begin
                #10; // Wait for combinational logic propagation
                $fdisplay(file_out, "%016h %3d %3d %016h %b",
                    orig_data,
                    flip_pos1,
                    flip_pos2,
                    decoded_data,
                    error_detected
                );
            end
        end

        $fclose(file_in);
        $fclose(file_out);
        $display("Simulation complete. Results written to repeat_output_vector.txt");
        $finish;
    end

endmodule
