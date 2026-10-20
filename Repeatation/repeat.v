`timescale 1ns/1ps

// ============================================================================
// Module: repeater_coder_64b
// Description: (3,1) Repetition Code Encoder for 64-bit input data.
//              Each input bit is repeated 3 times to form a 192-bit codeword.
// ============================================================================
module repeater_coder_64b(
    input  wire [63:0]  data_in,
    output reg  [191:0] data_out
);
    integer i;

    always @(*) begin
        for (i = 0; i < 64; i = i + 1) begin
            data_out[i*3]     = data_in[i];
            data_out[i*3 + 1] = data_in[i];
            data_out[i*3 + 2] = data_in[i];
        end
    end

endmodule


// ============================================================================
// Module: repeater_decoder_64b
// Description: (3,1) Repetition Code Decoder for 192-bit encoded codeword.
//              Performs 3-bit majority voting to recover 64-bit original data.
//              Detects bit mismatch errors within any triplet.
// ============================================================================
module repeater_decoder_64b(
    input  wire [191:0] data_in,
    output reg  [63:0]  data_out,
    output reg          error
);
    reg mid_error; 
    integer i;

    always @(*) begin
        // Initialize global error flag to 0 at the start of evaluation
        error = 1'b0; 
        
        for (i = 0; i < 64; i = i + 1) begin
            // 1. Majority voting logic: (A & B) | (B & C) | (A & C)
            data_out[i] = (data_in[i*3]     & data_in[i*3 + 1]) | 
                          (data_in[i*3 + 1] & data_in[i*3 + 2]) | 
                          (data_in[i*3]     & data_in[i*3 + 2]);

            // 2. mid_error checks if the 3 bits in the triplet are not all equal
            mid_error = (data_in[i*3] ^ data_in[i*3 + 1]) | 
                        (data_in[i*3 + 1] ^ data_in[i*3 + 2]);
            
            // 3. Accumulate global error flag (1 if any triplet has a mismatch)
            error = error || mid_error;
        end
    end

endmodule


// ============================================================================
// Module: repeater_top_64b
// Description: Top-level wrapper integrating (3,1) Repetition Encoder, Error
//              Injector (Channel Simulation), and Decoder.
// ============================================================================
module repeater_top_64b (
    input  wire [63:0]  orig_data,
    input  wire [7:0]   flip_pos1, // 0..191: flip codeword bit 1, >191: no flip
    input  wire [7:0]   flip_pos2, // 0..191: flip codeword bit 2, >191: no flip
    output wire [191:0] tx_codeword,
    output wire [191:0] rx_codeword,
    output wire [63:0]  decoded_data,
    output wire         error_detected
);
    wire [191:0] enc_codeword;
    reg  [191:0] corrupted_codeword;

    // 1. Encoder
    repeater_coder_64b enc (
        .data_in(orig_data),
        .data_out(enc_codeword)
    );

    // 2. Channel Noise Simulation
    always @(*) begin
        corrupted_codeword = enc_codeword;
        if (flip_pos1 < 8'd192) begin
            corrupted_codeword[flip_pos1] = ~enc_codeword[flip_pos1];
        end
        if (flip_pos2 < 8'd192 && flip_pos2 != flip_pos1) begin
            corrupted_codeword[flip_pos2] = ~corrupted_codeword[flip_pos2];
        end
    end

    // 3. Decoder
    repeater_decoder_64b dec (
        .data_in(corrupted_codeword),
        .data_out(decoded_data),
        .error(error_detected)
    );

    assign tx_codeword = enc_codeword;
    assign rx_codeword = corrupted_codeword;

endmodule
