`timescale 1ns / 1ps

// ============================================================================
// Module: convolution_encoder_64
// Description: Rate 1/2, Constraint Length K=3 Convolutional Encoder for 64-bit data.
//              Generator polynomials:
//                G0 = 7 (octal) = 111 (binary) -> v0 = u[t] ^ u[t-1] ^ u[t-2]
//                G1 = 5 (octal) = 101 (binary) -> v1 = u[t] ^ u[t-2]
//              Includes 2 zero flush/tail bits to drive encoder back to state 00.
//              Codeword width: (64 + 2) * 2 = 132 bits.
// ============================================================================
module convolution_encoder_64 (
    input  wire [63:0]  data_in,
    output reg  [131:0] codeword
);
    reg [65:0] u_stream;
    reg [1:0]  state;
    reg        u_bit;
    reg        v0, v1;
    integer    t;

    always @(*) begin
        // 64 message bits followed by 2 zero tail bits
        u_stream = {2'b00, data_in};
        state    = 2'b00;

        for (t = 0; t < 66; t = t + 1) begin
            u_bit = u_stream[t];
            v0 = u_bit ^ state[1] ^ state[0];
            v1 = u_bit ^ state[0];

            codeword[2*t]     = v0;
            codeword[2*t + 1] = v1;

            // Shift encoder state: new bit enters at MSB
            state = {u_bit, state[1]};
        end
    end
endmodule


// ============================================================================
// Module: convolution_decoder_64
// Description: Hardware Viterbi Decoder (Rate 1/2, K=3) using Register Exchange.
//              - Evaluates trellis across all 66 time steps.
//              - Add-Compare-Select (ACS) unit updates 4 path metrics.
//              - Survivor registers track decoded data history for each state.
//              - Zero tail bits guarantee termination in State 00.
// ============================================================================
module convolution_decoder_64 (
    input  wire [131:0] rx_codeword,
    output reg  [63:0]  data_out,
    output reg          error_detected,
    output reg          error_corrected
);

    reg [7:0]  pm [0:3];
    reg [7:0]  next_pm [0:3];
    reg [63:0] hist [0:3];
    reg [63:0] next_hist [0:3];

    reg r0, r1;
    reg u, s1;
    integer t, ns, p0, p1;
    integer bm0, bm1, c0, c1;

    always @(*) begin
        // Initialize state path metrics (State 0 is known start state)
        pm[0] = 8'd0;
        pm[1] = 8'd100;
        pm[2] = 8'd100;
        pm[3] = 8'd100;

        hist[0] = 64'd0;
        hist[1] = 64'd0;
        hist[2] = 64'd0;
        hist[3] = 64'd0;

        // Trellis traversal across 66 time steps
        for (t = 0; t < 66; t = t + 1) begin
            r0 = rx_codeword[2*t];
            r1 = rx_codeword[2*t + 1];

            // Evaluate next states ns = 0..3: ns = {u, s1}
            for (ns = 0; ns < 4; ns = ns + 1) begin
                u  = (ns >> 1) & 1;
                s1 = ns & 1;

                p0 = (s1 << 1) | 0; // Predecessor with s0 = 0
                p1 = (s1 << 1) | 1; // Predecessor with s0 = 1

                // Branch metric for p0: v0 = u ^ s1 ^ 0, v1 = u ^ 0
                bm0 = (r0 ^ u ^ s1 ^ 0) + (r1 ^ u ^ 0);
                // Branch metric for p1: v0 = u ^ s1 ^ 1, v1 = u ^ 1
                bm1 = (r0 ^ u ^ s1 ^ 1) + (r1 ^ u ^ 1);

                c0 = pm[p0] + bm0;
                c1 = pm[p1] + bm1;

                // Add-Compare-Select and Register Exchange
                if (c0 <= c1) begin
                    next_pm[ns] = c0;
                    if (t < 64)
                        next_hist[ns] = hist[p0] | ({63'd0, u} << t);
                    else
                        next_hist[ns] = hist[p0];
                end else begin
                    next_pm[ns] = c1;
                    if (t < 64)
                        next_hist[ns] = hist[p1] | ({63'd0, u} << t);
                    else
                        next_hist[ns] = hist[p1];
                end
            end

            // Update state metrics and path histories
            pm[0] = next_pm[0];
            pm[1] = next_pm[1];
            pm[2] = next_pm[2];
            pm[3] = next_pm[3];

            hist[0] = next_hist[0];
            hist[1] = next_hist[1];
            hist[2] = next_hist[2];
            hist[3] = next_hist[3];
        end

        // Decoded data corresponds to state 00 survivor at step 66
        data_out = hist[0];

        // Channel error flags based on accumulated survivor metric
        if (pm[0] > 8'd0) begin
            error_detected  = 1'b1;
            error_corrected = 1'b1;
        end else begin
            error_detected  = 1'b0;
            error_corrected = 1'b0;
        end
    end

endmodule


// ============================================================================
// Module: convolution_code_top
// Description: Top-level module integrating Convolutional Encoder, Channel Noise
//              Injector, and Hardware Viterbi Decoder.
// ============================================================================
module convolution_code_top (
    input  wire [63:0]  orig_data,
    input  wire [7:0]   flip_pos1, // 0..131: bit flip position, >=132: no flip
    input  wire [7:0]   flip_pos2, // Second bit flip position (>=132: no flip)
    output wire [131:0] tx_codeword,
    output wire [131:0] rx_codeword,
    output wire [63:0]  corrected_data,
    output wire         error_detected,
    output wire         error_corrected
);

    wire [131:0] enc_codeword;
    reg  [131:0] channel_codeword;

    // 1. Hardware Convolutional Encoder
    convolution_encoder_64 enc (
        .data_in(orig_data),
        .codeword(enc_codeword)
    );

    // 2. Channel Noise Simulation
    always @(*) begin
        channel_codeword = enc_codeword;
        if (flip_pos1 <= 8'd131) begin
            channel_codeword[flip_pos1] = ~enc_codeword[flip_pos1];
        end
        if (flip_pos2 <= 8'd131 && flip_pos2 != flip_pos1) begin
            channel_codeword[flip_pos2] = ~channel_codeword[flip_pos2];
        end
    end

    // 3. Hardware Viterbi Decoder
    convolution_decoder_64 dec (
        .rx_codeword(channel_codeword),
        .data_out(corrected_data),
        .error_detected(error_detected),
        .error_corrected(error_corrected)
    );

    assign tx_codeword = enc_codeword;
    assign rx_codeword = channel_codeword;

endmodule
