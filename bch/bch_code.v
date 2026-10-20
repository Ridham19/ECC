`timescale 1ns / 1ps

// ============================================================================
// Module: bch_encoder_64
// Description: Systematic Shortened BCH (78, 64, t=2) Encoder over GF(2^7).
//              Primitive polynomial: p(x) = x^7 + x^3 + 1 (0x89).
//              Generator polynomial: g(x) = x^14 + x^9 + x^8 + x^6 + x^5 + 
//                                           x^4 + x^2 + x + 1 (0x4377).
//              Encodes 64-bit data into a 78-bit codeword:
//              - data_in[63:0] mapped to bits [77:14]
//              - 14 BCH parity bits mapped to bits [13:0]
// ============================================================================
module bch_encoder_64 (
    input  wire [63:0] data_in,
    output wire [77:0] codeword
);
    reg [13:0] lfsr;
    reg        feedback;
    integer    i;

    always @(*) begin
        lfsr = 14'b0;
        for (i = 63; i >= 0; i = i - 1) begin
            feedback = data_in[i] ^ lfsr[13];
            lfsr = {lfsr[12:0], 1'b0} ^ (feedback ? 14'h0377 : 14'h0000);
        end
    end

    assign codeword = {data_in, lfsr};
endmodule


// ============================================================================
// Module: bch_decoder_64
// Description: Shortened BCH (78, 64, t=2) Decoder and Error Corrector.
//              - Calculates syndromes S1 and S3 over GF(2^7).
//              - Computes Error Locator Polynomial sigma(x) = 1 + s1*x + s2*x^2.
//              - Executes parallel Chien search to pinpoint 1 or 2 error positions.
//              - Flips corrupted bits and extracts 64-bit decoded data.
// ============================================================================
module bch_decoder_64 (
    input  wire [77:0] rx_codeword,
    output reg  [63:0] data_out,
    output reg         single_error_detected,
    output reg         double_error_detected,
    output reg         uncorrectable_error,
    output reg         error_corrected
);

    // GF(2^7) precomputed tables
    reg [6:0] alpha_full [0:127];
    reg [6:0] alpha_tbl  [0:77];
    reg [6:0] alpha3_tbl [0:77];
    reg [6:0] z1_tbl     [0:77];
    reg [6:0] z2_tbl     [0:77];
    reg [6:0] inv_tbl    [0:127];

    integer idx;
    reg [6:0] curr_pwr;

    initial begin
        // Generate GF(2^7) power sequence with primitive poly x^7 + x^3 + 1
        curr_pwr = 7'd1;
        for (idx = 0; idx < 127; idx = idx + 1) begin
            alpha_full[idx] = curr_pwr;
            if (curr_pwr[6])
                curr_pwr = ((curr_pwr << 1) ^ 7'h09) & 7'h7F;
            else
                curr_pwr = (curr_pwr << 1) & 7'h7F;
        end
        alpha_full[127] = 7'd0;

        // Populate lookup tables for syndrome & Chien search
        for (idx = 0; idx < 78; idx = idx + 1) begin
            alpha_tbl[idx]  = alpha_full[idx];
            alpha3_tbl[idx] = alpha_full[(3 * idx) % 127];
            z1_tbl[idx]     = alpha_full[(127 - idx) % 127];
            z2_tbl[idx]     = alpha_full[(2 * (127 - idx)) % 127];
        end

        // Multiplicative inverse table for GF(2^7)
        inv_tbl[0] = 7'd0;
        for (idx = 0; idx < 127; idx = idx + 1) begin
            inv_tbl[alpha_full[idx]] = alpha_full[(127 - idx) % 127];
        end
        inv_tbl[127] = 7'd0;
    end

    // GF(2^7) Galois Field Multiplier function
    function [6:0] gf_mult;
        input [6:0] a;
        input [6:0] b;
        reg   [6:0] acc;
        reg   [6:0] a_shift;
        integer j;
        begin
            acc = 7'd0;
            a_shift = a;
            for (j = 0; j < 7; j = j + 1) begin
                if (b[j])
                    acc = acc ^ a_shift;
                if (a_shift[6])
                    a_shift = ((a_shift << 1) ^ 7'h09) & 7'h7F;
                else
                    a_shift = (a_shift << 1) & 7'h7F;
            end
            gf_mult = acc;
        end
    endfunction

    reg [6:0] s1, s3;
    reg [6:0] s1_sq, s1_cb;
    reg [6:0] sigma1, sigma2;
    reg [77:0] corrected_cw;
    reg [6:0] term1, term2;
    reg [6:0] chien_val;
    reg [77:0] error_mask;
    integer   k, err_count, expected_errs;

    always @(*) begin
        // 1. Syndrome calculation: S1 and S3
        s1 = 7'd0;
        s3 = 7'd0;
        for (k = 0; k < 78; k = k + 1) begin
            if (rx_codeword[k]) begin
                s1 = s1 ^ alpha_tbl[k];
                s3 = s3 ^ alpha3_tbl[k];
            end
        end

        // Defaults
        corrected_cw          = rx_codeword;
        single_error_detected = 1'b0;
        double_error_detected = 1'b0;
        uncorrectable_error   = 1'b0;
        error_corrected       = 1'b0;
        error_mask            = 78'd0;
        err_count             = 0;
        expected_errs         = 0;

        if (s1 == 7'd0 && s3 == 7'd0) begin
            // No channel errors
            corrected_cw = rx_codeword;
        end else if (s1 == 7'd0 && s3 != 7'd0) begin
            // Uncorrectable error pattern
            uncorrectable_error = 1'b1;
        end else begin
            // 2. Compute error locator coefficients: sigma1 and sigma2
            s1_sq  = gf_mult(s1, s1);
            s1_cb  = gf_mult(s1_sq, s1);
            sigma1 = s1;

            if (s3 == s1_cb) begin
                // Single error case
                sigma2 = 7'd0;
                expected_errs = 1;
            end else begin
                // Double error case
                sigma2 = gf_mult(s3 ^ s1_cb, inv_tbl[s1]);
                expected_errs = 2;
            end

            // 3. Parallel Chien search over all 78 codeword bit positions
            for (k = 0; k < 78; k = k + 1) begin
                term1 = gf_mult(sigma1, z1_tbl[k]);
                term2 = (sigma2 != 7'd0) ? gf_mult(sigma2, z2_tbl[k]) : 7'd0;
                chien_val = 7'd1 ^ term1 ^ term2;
                if (chien_val == 7'd0) begin
                    error_mask[k] = 1'b1;
                    err_count = err_count + 1;
                end
            end

            // 4. Evaluate correction success
            if (err_count == expected_errs) begin
                corrected_cw    = rx_codeword ^ error_mask;
                error_corrected = 1'b1;
                if (expected_errs == 1)
                    single_error_detected = 1'b1;
                else
                    double_error_detected = 1'b1;
            end else begin
                uncorrectable_error = 1'b1;
            end
        end

        // 5. Extract decoded 64-bit data from bits [77:14]
        data_out = corrected_cw[77:14];
    end

endmodule


// ============================================================================
// Module: bch_code_top
// Description: Top-level module integrating BCH (78, 64) Encoder, Channel
//              Noise Simulation, and Hardware Decoder.
// ============================================================================
module bch_code_top (
    input  wire [63:0] orig_data,
    input  wire [7:0]  flip_pos1, // 0..77: flip index, >=78: no flip
    input  wire [7:0]  flip_pos2, // Second flip index (>=78: no flip)
    output wire [77:0] tx_codeword,
    output wire [77:0] rx_codeword,
    output wire [63:0] corrected_data,
    output wire        single_error_detected,
    output wire        double_error_detected,
    output wire        uncorrectable_error,
    output wire        error_corrected
);

    wire [77:0] enc_codeword;
    reg  [77:0] channel_codeword;

    // 1. Hardware BCH Encoder
    bch_encoder_64 enc (
        .data_in(orig_data),
        .codeword(enc_codeword)
    );

    // 2. Channel Noise Simulation
    always @(*) begin
        channel_codeword = enc_codeword;
        if (flip_pos1 <= 8'd77) begin
            channel_codeword[flip_pos1] = ~enc_codeword[flip_pos1];
        end
        if (flip_pos2 <= 8'd77 && flip_pos2 != flip_pos1) begin
            channel_codeword[flip_pos2] = ~channel_codeword[flip_pos2];
        end
    end

    // 3. Hardware BCH Decoder
    bch_decoder_64 dec (
        .rx_codeword(channel_codeword),
        .data_out(corrected_data),
        .single_error_detected(single_error_detected),
        .double_error_detected(double_error_detected),
        .uncorrectable_error(uncorrectable_error),
        .error_corrected(error_corrected)
    );

    assign tx_codeword = enc_codeword;
    assign rx_codeword = channel_codeword;

endmodule
