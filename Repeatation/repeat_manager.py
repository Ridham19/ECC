#!/usr/bin/env python3
"""
(3,1) Repetition Code Manager & Performance Evaluator
======================================================
Python Manager Script:
1. Generates 64-bit input test vectors and error flip specifications -> 'repeat_input_vector.txt'.
2. Reads Verilog testbench simulation results -> 'repeat_output_vector.txt'.
3. Compares original data vs Verilog hardware decoded data and reports correction statistics.

Note: Encoding, decoding, majority voting, and error detection logic are implemented
EXCLUSIVELY in Verilog hardware modules (repeat.v).
"""

import os
import random
import argparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_INPUT_FILE = os.path.join(SCRIPT_DIR, "repeat_input_vector.txt")
DEFAULT_OUTPUT_FILE = os.path.join(SCRIPT_DIR, "repeat_output_vector.txt")

def generate_test_vectors(filename=DEFAULT_INPUT_FILE, num_cases=30):
    """Generates 64-bit test messages and bit flip specifications for Verilog testbench."""
    os.makedirs(os.path.dirname(os.path.abspath(filename)), exist_ok=True)
    test_cases = []

    # Standard known patterns
    known_patterns = [
        0x0000000000000000,
        0xFFFFFFFFFFFFFFFF,
        0xAAAAAAAAAAAAAAAA,
        0x5555555555555555,
        0x123456789ABCDEF0,
        0xDEADBEEFCAFEFA00
    ]

    for data in known_patterns:
        # Clean case (no flips: 255)
        test_cases.append((data, 255, 255))
        # Single bit flip in codeword (0..191)
        test_cases.append((data, random.randint(0, 191), 255))
        # Double bit flips in codeword (0..191)
        test_cases.append((data, random.randint(0, 191), random.randint(0, 191)))

    while len(test_cases) < num_cases:
        data = random.getrandbits(64)
        flip1 = random.choice([255, random.randint(0, 191)])
        flip2 = random.choice([255, random.randint(0, 191)])
        test_cases.append((data, flip1, flip2))

    with open(filename, "w") as f:
        for orig_data, flip1, flip2 in test_cases:
            f.write(f"{orig_data:016X} {flip1:3d} {flip2:3d}\n")

    print("=" * 75)
    print(f"[+] Generated {len(test_cases)} test vectors in '{filename}'")
    print("=" * 75)

def evaluate_verilog_results(out_filename=DEFAULT_OUTPUT_FILE):
    """Parses repeat_output_vector.txt written by Verilog testbench and evaluates hardware correction performance."""
    if not os.path.exists(out_filename):
        print(f"[-] Verilog output file '{out_filename}' not found!")
        print(f"[-] Please run Verilog testbench 'tb_repeat.v' to generate '{out_filename}'.")
        return False

    total = 0
    passed = 0
    failed = 0
    total_data_bits = 0
    residual_bit_errors = 0

    print("\n" + "=" * 90)
    print("         VERILOG (3,1) REPETITION CODE EVALUATION REPORT")
    print("=" * 90)
    print(f"{'CASE':<5} | {'ORIGINAL DATA':<18} | {'FLIP 1':<6} | {'FLIP 2':<6} | {'DECODED DATA':<18} | {'ERR DET':<7} | {'STATUS':<12}")
    print("-" * 90)

    with open(out_filename, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            parts = line.split()
            if len(parts) < 5:
                continue

            total += 1
            orig_data_hex = parts[0]
            orig_data = int(orig_data_hex, 16)
            flip1 = int(parts[1])
            flip2 = int(parts[2])
            decoded_hex = parts[3]
            decoded_data = int(decoded_hex, 16)
            err_detected = int(parts[4])

            # Calculate bit-by-bit mismatch between original data and Verilog decoded data
            bit_diff = orig_data ^ decoded_data
            diff_count = bin(bit_diff).count('1')
            residual_bit_errors += diff_count
            total_data_bits += 64

            if diff_count == 0:
                passed += 1
                status = "CORRECTED [OK]"
            else:
                failed += 1
                status = f"FAILED ({diff_count}b)"

            flip1_str = f"{flip1}" if flip1 < 192 else "NONE"
            flip2_str = f"{flip2}" if flip2 < 192 else "NONE"

            print(f"{total:<5} | 0x{orig_data_hex:<16} | {flip1_str:<6} | {flip2_str:<6} | 0x{decoded_hex:<16} | {err_detected:<7} | {status:<12}")

    print("=" * 90)
    print("             VERILOG CORRECTION EFFICIENCY SUMMARY STATISTICS")
    print("=" * 90)
    print(f" Total Messages Processed          : {total}")
    print(f" Total Data Bits Tested            : {total_data_bits} bits")
    print(f" Messages Successfully Restored    : {passed} / {total} ({passed/total*100:.2f}%)")
    print(f" Messages Uncorrected / Corrupted  : {failed} / {total} ({failed/total*100:.2f}%)")
    print(f" Total Residual Data Bit Errors    : {residual_bit_errors} bits")
    print(f" Post-Correction Bit Error Rate   : {(residual_bit_errors / total_data_bits)*100:.4f}%")
    print("=" * 90)
    return failed == 0

def main():
    parser = argparse.ArgumentParser(description="(3,1) Repetition Code Manager & Evaluator")
    parser.add_argument("--gen", action="store_true", help="Generate input vectors for Verilog testbench")
    parser.add_argument("--evaluate", action="store_true", help="Evaluate output vectors generated by Verilog testbench")
    parser.add_argument("--count", type=int, default=30, help="Number of test cases to generate")

    args = parser.parse_args()

    if args.gen:
        generate_test_vectors(num_cases=args.count)
    elif args.evaluate:
        evaluate_verilog_results()
    else:
        generate_test_vectors(num_cases=args.count)
        if os.path.exists(DEFAULT_OUTPUT_FILE):
            evaluate_verilog_results()

if __name__ == "__main__":
    main()
