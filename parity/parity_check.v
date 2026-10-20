`timescale 1ns / 1ps

// ============================================================================
// Module: parity_generator_64
// Description: Generates Even and Odd Parity bits for a 64-bit input message.
// ============================================================================
module parity_generator_64 (
    input  wire [63:0] data_in,
    output wire        even_parity,
    output wire        odd_parity
);
    // Even Parity: XOR reduction of all 64 data bits.
    // Resulting total number of 1s (data + even_parity) is always EVEN.
    assign even_parity = ^data_in;

    // Odd Parity: Inverted XOR reduction (XNOR) of all 64 data bits.
    // Resulting total number of 1s (data + odd_parity) is always ODD.
    assign odd_parity  = ~^data_in;

endmodule


// ============================================================================
// Module: parity_checker_64
// Description: Checks a 64-bit message against a received parity bit.
//              parity_type: 0 for Even Parity Check, 1 for Odd Parity Check.
//              error_detected: High (1) if parity check fails (error present).
// ============================================================================
module parity_checker_64 (
    input  wire [63:0] data_in,
    input  wire        parity_in,      // Received parity bit
    input  wire        parity_type,    // 0 = Even Parity, 1 = Odd Parity
    output wire        expected_parity,
    output wire        error_detected
);
    wire computed_even;
    wire computed_odd;

    assign computed_even = ^data_in;
    assign computed_odd  = ~^data_in;

    // Select expected parity bit based on mode selection
    assign expected_parity = (parity_type == 1'b0) ? computed_even : computed_odd;

    // Parity error occurs if received parity doesn't match expected parity
    assign error_detected  = (parity_in != expected_parity);

endmodule


// ============================================================================
// Module: parity_check_top
// Description: Top-level wrapper module that connects Generator and Checker.
//              Allows injecting a bit flip into data or parity bit for testing.
// ============================================================================
module parity_check_top (
    input  wire [63:0] orig_data,
    input  wire        parity_type,    // 0 = Even Parity, 1 = Odd Parity
    input  wire [6:0]  flip_bit_pos,   // 0..63 = flip data bit, 64 = flip parity, >64 = no flip
    output wire [63:0] rx_data,
    output wire        generated_parity,
    output wire        rx_parity,
    output wire        error_detected
);
    wire even_p, odd_p;
    reg [63:0] corrupted_data;
    reg        corrupted_parity;

    // 1. Generate Parity
    parity_generator_64 gen_inst (
        .data_in(orig_data),
        .even_parity(even_p),
        .odd_parity(odd_p)
    );

    assign generated_parity = (parity_type == 1'b0) ? even_p : odd_p;

    // 2. Channel Simulation (Inject error if flip_bit_pos <= 64)
    always @(*) begin
        corrupted_data   = orig_data;
        corrupted_parity = generated_parity;

        if (flip_bit_pos < 7'd64) begin
            corrupted_data[flip_bit_pos] = ~orig_data[flip_bit_pos];
        end else if (flip_bit_pos == 7'd64) begin
            corrupted_parity = ~generated_parity;
        end
    end

    // 3. Parity Checker
    parity_checker_64 chk_inst (
        .data_in(corrupted_data),
        .parity_in(corrupted_parity),
        .parity_type(parity_type),
        .expected_parity(),
        .error_detected(error_detected)
    );

    assign rx_data   = corrupted_data;
    assign rx_parity = corrupted_parity;

endmodule
