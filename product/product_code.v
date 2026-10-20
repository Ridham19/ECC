`timescale 1ns / 1ps

// ============================================================================
// Module: product_code_encoder_64
// Description: 2D Product Code (Matrix Parity) Encoder for 64-bit data.
//              Arranges 64 data bits as an 8x8 matrix (8 rows x 8 columns).
//              Generates 8 Row Parity bits and 8 Column Parity bits (Even Parity).
// ============================================================================
module product_code_encoder_64 (
    input  wire [63:0] data_in,
    output reg  [7:0]  row_parity,
    output reg  [7:0]  col_parity
);
    integer r, c;

    always @(*) begin
        // Compute Row Parity (XOR of 8 bits in each row)
        for (r = 0; r < 8; r = r + 1) begin
            row_parity[r] = ^data_in[r*8 +: 8];
        end

        // Compute Column Parity (XOR of 8 bits in each column)
        for (c = 0; c < 8; c = c + 1) begin
            col_parity[c] = 1'b0;
            for (r = 0; r < 8; r = r + 1) begin
                col_parity[c] = col_parity[c] ^ data_in[r*8 + c];
            end
        end
    end
endmodule


// ============================================================================
// Module: product_code_decoder_64
// Description: 2D Product Code (Matrix Parity) Decoder and Error Corrector.
//              Detects row and column parity errors.
//              If exactly 1 Row error and 1 Column error occur, corrects the
//              corrupted bit at position (row_err, col_err).
// ============================================================================
module product_code_decoder_64 (
    input  wire [63:0] rx_data,
    input  wire [7:0]  rx_row_parity,
    input  wire [7:0]  rx_col_parity,
    output reg  [63:0] corrected_data,
    output reg         single_error_detected,
    output reg         error_corrected,
    output reg         multiple_errors
);
    reg [7:0] row_syndrome;
    reg [7:0] col_syndrome;

    integer r, c;
    integer row_err_count, col_err_count;
    integer err_row, err_col;

    always @(*) begin
        // 1. Calculate Row Syndromes (1 if row parity fails)
        for (r = 0; r < 8; r = r + 1) begin
            row_syndrome[r] = (^rx_data[r*8 +: 8]) ^ rx_row_parity[r];
        end

        // 2. Calculate Column Syndromes (1 if column parity fails)
        for (c = 0; c < 8; c = c + 1) begin
            col_syndrome[c] = 1'b0;
            for (r = 0; r < 8; r = r + 1) begin
                col_syndrome[c] = col_syndrome[c] ^ rx_data[r*8 + c];
            end
            col_syndrome[c] = col_syndrome[c] ^ rx_col_parity[c];
        end

        // 3. Count parity errors in rows and columns
        row_err_count = 0;
        err_row       = 0;
        for (r = 0; r < 8; r = r + 1) begin
            if (row_syndrome[r] == 1'b1) begin
                row_err_count = row_err_count + 1;
                err_row       = r;
            end
        end

        col_err_count = 0;
        err_col       = 0;
        for (c = 0; c < 8; c = c + 1) begin
            if (col_syndrome[c] == 1'b1) begin
                col_err_count = col_err_count + 1;
                err_col       = c;
            end
        end

        // 4. Decision and Correction Logic
        corrected_data        = rx_data;
        single_error_detected = 1'b0;
        error_corrected       = 1'b0;
        multiple_errors       = 1'b0;

        if (row_err_count == 1 && col_err_count == 1) begin
            // Single bit error at (err_row, err_col) inside 8x8 data matrix
            single_error_detected = 1'b1;
            corrected_data[err_row*8 + err_col] = ~rx_data[err_row*8 + err_col];
            error_corrected = 1'b1;
        end else if (row_err_count == 1 && col_err_count == 0) begin
            // Single error in row parity bit itself
            single_error_detected = 1'b1;
            error_corrected = 1'b1;
        end else if (row_err_count == 0 && col_err_count == 1) begin
            // Single error in col parity bit itself
            single_error_detected = 1'b1;
            error_corrected = 1'b1;
        end else if (row_err_count > 0 || col_err_count > 0) begin
            // Multiple errors detected (uncorrectable by simple 2D parity)
            multiple_errors = 1'b1;
        end
    end
endmodule


// ============================================================================
// Module: product_code_top
// Description: Top-level wrapper integrating 2D Product Code Encoder, Error
//              Injector, and Decoder.
// ============================================================================
module product_code_top (
    input  wire [63:0] orig_data,
    input  wire [6:0]  flip_pos1, // 0..63: data bit flip, >63: no flip
    input  wire [6:0]  flip_pos2, // Second flip bit index (>63: no second flip)
    output wire [7:0]  tx_row_parity,
    output wire [7:0]  tx_col_parity,
    output wire [63:0] rx_data,
    output wire [63:0] corrected_data,
    output wire        single_error_detected,
    output wire        error_corrected,
    output wire        multiple_errors
);
    wire [7:0] enc_row_p, enc_col_p;
    reg  [63:0] corrupted_data;

    // 1. Encoder
    product_code_encoder_64 enc (
        .data_in(orig_data),
        .row_parity(enc_row_p),
        .col_parity(enc_col_p)
    );

    // 2. Channel Noise Simulation
    always @(*) begin
        corrupted_data = orig_data;
        if (flip_pos1 < 7'd64) begin
            corrupted_data[flip_pos1] = ~orig_data[flip_pos1];
        end
        if (flip_pos2 < 7'd64 && flip_pos2 != flip_pos1) begin
            corrupted_data[flip_pos2] = ~corrupted_data[flip_pos2];
        end
    end

    // 3. Decoder
    product_code_decoder_64 dec (
        .rx_data(corrupted_data),
        .rx_row_parity(enc_row_p),
        .rx_col_parity(enc_col_p),
        .corrected_data(corrected_data),
        .single_error_detected(single_error_detected),
        .error_corrected(error_corrected),
        .multiple_errors(multiple_errors)
    );

    assign tx_row_parity = enc_row_p;
    assign tx_col_parity = enc_col_p;
    assign rx_data       = corrupted_data;

endmodule
