`timescale 1ns / 1ps

// ============================================================================
// Module: hamming_encoder_64
// Description: Hamming SEC-DED (72, 64) Encoder.
//              Encodes 64-bit data message into a 72-bit codeword containing:
//              - 64 data bits
//              - 7 Hamming parity bits (p0..p6 at power-of-2 positions)
//              - 1 overall parity bit (p7)
// ============================================================================
module hamming_encoder_64 (
    input  wire [63:0] data_in,
    output wire [71:0] codeword
);
    reg [71:1] vec;
    reg [6:0] p_calc;
    reg p7_calc;

    integer i, k;

    always @(*) begin
        // Map 64 data bits to non-power-of-2 positions (1-indexed vector vec[71:1])
        vec[3]   = data_in[0];
        vec[5]   = data_in[1];  vec[6]   = data_in[2];  vec[7]   = data_in[3];
        vec[9]   = data_in[4];  vec[10]  = data_in[5];  vec[11]  = data_in[6];  vec[12]  = data_in[7];
        vec[13]  = data_in[8];  vec[14]  = data_in[9];  vec[15]  = data_in[10]; vec[17]  = data_in[11];
        vec[18]  = data_in[12]; vec[19]  = data_in[13]; vec[20]  = data_in[14]; vec[21]  = data_in[15];
        vec[22]  = data_in[16]; vec[23]  = data_in[17]; vec[24]  = data_in[18]; vec[25]  = data_in[19];
        vec[26]  = data_in[20]; vec[27]  = data_in[21]; vec[28]  = data_in[22]; vec[29]  = data_in[23];
        vec[30]  = data_in[24]; vec[31]  = data_in[25]; vec[33]  = data_in[26]; vec[34]  = data_in[27];
        vec[35]  = data_in[28]; vec[36]  = data_in[29]; vec[37]  = data_in[30]; vec[38]  = data_in[31];
        vec[39]  = data_in[32]; vec[40]  = data_in[33]; vec[41]  = data_in[34]; vec[42]  = data_in[35];
        vec[43]  = data_in[36]; vec[44]  = data_in[37]; vec[45]  = data_in[38]; vec[46]  = data_in[39];
        vec[47]  = data_in[40]; vec[48]  = data_in[41]; vec[49]  = data_in[42]; vec[50]  = data_in[43];
        vec[51]  = data_in[44]; vec[52]  = data_in[45]; vec[53]  = data_in[46]; vec[54]  = data_in[47];
        vec[55]  = data_in[48]; vec[56]  = data_in[49]; vec[57]  = data_in[50]; vec[58]  = data_in[51];
        vec[59]  = data_in[52]; vec[60]  = data_in[53]; vec[61]  = data_in[54]; vec[62]  = data_in[55];
        vec[63]  = data_in[56]; vec[65]  = data_in[57]; vec[66]  = data_in[58]; vec[67]  = data_in[59];
        vec[68]  = data_in[60]; vec[69]  = data_in[61]; vec[70]  = data_in[62]; vec[71]  = data_in[63];

        // Power-of-2 positions set to 0 initially for calculation
        vec[1]  = 1'b0; vec[2]  = 1'b0; vec[4]  = 1'b0; vec[8]  = 1'b0;
        vec[16] = 1'b0; vec[32] = 1'b0; vec[64] = 1'b0;

        // Calculate 7 Hamming parity bits p0..p6
        for (k = 0; k < 7; k = k + 1) begin
            p_calc[k] = 1'b0;
            for (i = 1; i <= 71; i = i + 1) begin
                if ((i & (1 << k)) != 0) begin
                    p_calc[k] = p_calc[k] ^ vec[i];
                end
            end
        end

        // Insert computed parity bits into vector
        vec[1]  = p_calc[0];
        vec[2]  = p_calc[1];
        vec[4]  = p_calc[2];
        vec[8]  = p_calc[3];
        vec[16] = p_calc[4];
        vec[32] = p_calc[5];
        vec[64] = p_calc[6];

        // Calculate overall parity bit p7
        p7_calc = 1'b0;
        for (i = 1; i <= 71; i = i + 1) begin
            p7_calc = p7_calc ^ vec[i];
        end
    end

    assign codeword = {p7_calc, vec[71:1]};
endmodule


// ============================================================================
// Module: hamming_decoder_64
// Description: Hamming SEC-DED (72, 64) Decoder and Error Corrector.
//              Computes syndrome S[6:0] and overall parity to locate and
//              correct single-bit errors, or flag double-bit errors.
// ============================================================================
module hamming_decoder_64 (
    input  wire [71:0] rx_codeword,
    output reg  [63:0] data_out,
    output reg         single_error_detected,
    output reg         double_error_detected,
    output reg         error_corrected
);
    reg [71:1] vec_in;
    reg [71:1] vec_corrected;
    reg [6:0]  syndrome;
    reg        overall_parity;
    reg        p7_in;
    integer    i, k;

    always @(*) begin
        vec_in = rx_codeword[70:0];
        p7_in  = rx_codeword[71];

        // 1. Calculate Syndrome S[6:0]
        for (k = 0; k < 7; k = k + 1) begin
            syndrome[k] = 1'b0;
            for (i = 1; i <= 71; i = i + 1) begin
                if ((i & (1 << k)) != 0) begin
                    syndrome[k] = syndrome[k] ^ vec_in[i];
                end
            end
        end

        // 2. Calculate overall parity (XOR over all 72 bits)
        overall_parity = p7_in;
        for (i = 1; i <= 71; i = i + 1) begin
            overall_parity = overall_parity ^ vec_in[i];
        end

        // 3. Error Detection & Correction
        vec_corrected         = vec_in;
        single_error_detected = 1'b0;
        double_error_detected = 1'b0;
        error_corrected       = 1'b0;

        if (syndrome != 7'b0 && overall_parity == 1'b1) begin
            // Single-bit error at position 'syndrome' (1 to 71)
            single_error_detected = 1'b1;
            if (syndrome >= 7'd1 && syndrome <= 7'd71) begin
                vec_corrected[syndrome] = ~vec_in[syndrome];
                error_corrected = 1'b1;
            end
        end else if (syndrome == 7'b0 && overall_parity == 1'b1) begin
            // Single-bit error in p7 parity bit itself
            single_error_detected = 1'b1;
            error_corrected = 1'b1; // Data bits are untouched
        end else if (syndrome != 7'b0 && overall_parity == 1'b0) begin
            // Double-bit error (uncorrectable)
            double_error_detected = 1'b1;
        end

        // 4. Extract data bits from vector
        data_out[0]  = vec_corrected[3];
        data_out[1]  = vec_corrected[5];  data_out[2]  = vec_corrected[6];  data_out[3]  = vec_corrected[7];
        data_out[4]  = vec_corrected[9];  data_out[5]  = vec_corrected[10]; data_out[6]  = vec_corrected[11]; data_out[7]  = vec_corrected[12];
        data_out[8]  = vec_corrected[13]; data_out[9]  = vec_corrected[14]; data_out[10] = vec_corrected[15]; data_out[11] = vec_corrected[17];
        data_out[12] = vec_corrected[18]; data_out[13] = vec_corrected[19]; data_out[14] = vec_corrected[20]; data_out[15] = vec_corrected[21];
        data_out[16] = vec_corrected[22]; data_out[17] = vec_corrected[23]; data_out[18] = vec_corrected[24]; data_out[19] = vec_corrected[25];
        data_out[20] = vec_corrected[26]; data_out[21] = vec_corrected[27]; data_out[22] = vec_corrected[28]; data_out[23] = vec_corrected[29];
        data_out[24] = vec_corrected[30]; data_out[25] = vec_corrected[31]; data_out[26] = vec_corrected[33]; data_out[27] = vec_corrected[34];
        data_out[28] = vec_corrected[35]; data_out[29] = vec_corrected[36]; data_out[30] = vec_corrected[37]; data_out[31] = vec_corrected[38];
        data_out[32] = vec_corrected[39]; data_out[33] = vec_corrected[40]; data_out[34] = vec_corrected[41]; data_out[35] = vec_corrected[42];
        data_out[36] = vec_corrected[43]; data_out[37] = vec_corrected[44]; data_out[38] = vec_corrected[45]; data_out[39] = vec_corrected[46];
        data_out[40] = vec_corrected[47]; data_out[41] = vec_corrected[48]; data_out[42] = vec_corrected[49]; data_out[43] = vec_corrected[50];
        data_out[44] = vec_corrected[51]; data_out[45] = vec_corrected[52]; data_out[46] = vec_corrected[53]; data_out[47] = vec_corrected[54];
        data_out[48] = vec_corrected[55]; data_out[49] = vec_corrected[56]; data_out[50] = vec_corrected[57]; data_out[51] = vec_corrected[58];
        data_out[52] = vec_corrected[59]; data_out[53] = vec_corrected[60]; data_out[54] = vec_corrected[61]; data_out[55] = vec_corrected[62];
        data_out[56] = vec_corrected[63]; data_out[57] = vec_corrected[65]; data_out[58] = vec_corrected[66]; data_out[59] = vec_corrected[67];
        data_out[60] = vec_corrected[68]; data_out[61] = vec_corrected[69]; data_out[62] = vec_corrected[70]; data_out[63] = vec_corrected[71];
    end
endmodule


// ============================================================================
// Module: hamming_code_top
// Description: Top-level module integrating Encoder, Error Injector, and Decoder.
// ============================================================================
module hamming_code_top (
    input  wire [63:0] orig_data,
    input  wire [7:0]  flip_pos1, // 0..71: bit flip index, >71: no flip
    input  wire [7:0]  flip_pos2, // Second bit flip index (>71: no flip)
    output wire [71:0] tx_codeword,
    output wire [71:0] rx_codeword,
    output wire [63:0] corrected_data,
    output wire        single_error_detected,
    output wire        double_error_detected,
    output wire        error_corrected
);
    wire [71:0] enc_codeword;
    reg  [71:0] channel_codeword;

    // 1. Encoder
    hamming_encoder_64 enc (
        .data_in(orig_data),
        .codeword(enc_codeword)
    );

    // 2. Channel Noise Simulation
    always @(*) begin
        channel_codeword = enc_codeword;
        if (flip_pos1 <= 8'd71) begin
            channel_codeword[flip_pos1] = ~enc_codeword[flip_pos1];
        end
        if (flip_pos2 <= 8'd71 && flip_pos2 != flip_pos1) begin
            channel_codeword[flip_pos2] = ~channel_codeword[flip_pos2];
        end
    end

    // 3. Decoder
    hamming_decoder_64 dec (
        .rx_codeword(channel_codeword),
        .data_out(corrected_data),
        .single_error_detected(single_error_detected),
        .double_error_detected(double_error_detected),
        .error_corrected(error_corrected)
    );

    assign tx_codeword = enc_codeword;
    assign rx_codeword = channel_codeword;

endmodule
