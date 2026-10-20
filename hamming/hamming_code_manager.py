#!/usr/bin/env python3
"""
Hamming SEC-DED (72, 64) Code Manager & Performance Evaluator
==============================================================
Python Manager Script:
1. Generates 64-bit input test vectors and bit flip specifications -> 'hamming_input_vector.txt'.
2. Reads Verilog testbench simulation results -> 'hamming_output_vector.txt'.
3. Compares original data vs Verilog hardware corrected data and evaluates performance.

Note: Hamming encoding (72, 64), syndrome calculation, SEC (Single Error Correction), 
and DED (Double Error Detection) algorithms are executed EXCLUSIVELY in Verilog 
hardware modules (hamming_code.v).
"""

import os
import random
import argparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_INPUT_FILE = os.path.join(SCRIPT_DIR, "hamming_input_vector.txt")
DEFAULT_OUTPUT_FILE = os.path.join(SCRIPT_DIR, "hamming_output_vector.txt")

def generate_test_vectors(filename=DEFAULT_INPUT_FILE, num_cases=25):
    """Generates test input vectors for Verilog Hamming SEC-DED simulation."""
    os.makedirs(os.path.dirname(os.path.abspath(filename)), exist_ok=True)
    test_cases = []

    # Sample known patterns
    known_patterns = [
        0x0000000000000000,
        0xFFFFFFFFFFFFFFFF,
        0xAAAAAAAAAAAAAAAA,
        0x5555555555555555,
        0x123456789ABCDEF0,
        0xDEADBEEFCAFEFA00
    ]

    for data in known_patterns:
        # Clean (no flips: 255)
        test_cases.append((data, 255, 255))
        # Single bit flip in 72-bit codeword (0..71)
        test_cases.append((data, random.randint(0, 71), 255))
        # Double bit flips in 72-bit codeword (0..71)
        test_cases.append((data, random.randint(0, 71), random.randint(0, 71)))

    while len(test_cases) < num_cases:
        data = random.getrandbits(64)
        flip1 = random.choice([255, random.randint(0, 71)])
        flip2 = random.choice([255, random.randint(0, 71)])
        test_cases.append((data, flip1, flip2))

    with open(filename, "w") as f:
        for orig_data, flip1, flip2 in test_cases:
            f.write(f"{orig_data:016X} {flip1:3d} {flip2:3d}\n")

    print("=" * 75)
    print(f"[+] Generated {len(test_cases)} Hamming (72,64) test vectors in '{filename}'")
    print("=" * 75)

def evaluate_verilog_results(out_filename=DEFAULT_OUTPUT_FILE):
    """Parses hamming_output_vector.txt written by Verilog testbench and evaluates correction performance."""
    if not os.path.exists(out_filename):
        print(f"[-] Result file '{out_filename}' not found.")
        print(f"[-] Please run Verilog testbench 'tb_hamming_code.v' to generate '{out_filename}'.")
        return False

    total = 0
    passed = 0
    failed = 0
    total_data_bits = 0
    residual_bit_errors = 0

    print("\n" + "=" * 90)
    print("         VERILOG HAMMING SEC-DED (72, 64) EVALUATION REPORT")
    print("=" * 90)
    print(f"{'CASE':<5} | {'ORIGINAL DATA':<18} | {'FLIP 1':<6} | {'FLIP 2':<6} | {'CORRECTED DATA':<18} | {'SEC':<4} | {'DED':<4} | {'STATUS':<12}")
    print("-" * 90)

    with open(out_filename, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            parts = line.split()
            if len(parts) < 8:
                continue

            total += 1
            orig_data_hex = parts[0]
            orig_data = int(orig_data_hex, 16)
            flip1 = int(parts[1])
            flip2 = int(parts[2])
            rx_codeword_hex = parts[3]
            corrected_hex = parts[4]
            corrected_data = int(corrected_hex, 16)
            single_err = int(parts[5])
            double_err = int(parts[6])
            err_corr = int(parts[7])

            bit_diff = orig_data ^ corrected_data
            diff_count = bin(bit_diff).count('1')
            residual_bit_errors += diff_count
            total_data_bits += 64

            if diff_count == 0:
                passed += 1
                status = "CORRECTED [OK]"
            else:
                failed += 1
                status = f"FAILED ({diff_count}b)"

            flip1_str = f"{flip1}" if flip1 < 72 else "NONE"
            flip2_str = f"{flip2}" if flip2 < 72 else "NONE"

            print(f"{total:<5} | 0x{orig_data_hex:<16} | {flip1_str:<6} | {flip2_str:<6} | 0x{corrected_hex:<16} | {single_err:<4} | {double_err:<4} | {status:<12}")

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
    parser = argparse.ArgumentParser(description="Hamming SEC-DED (72, 64) Code Manager & Evaluator")
    parser.add_argument("--gen", action="store_true", help="Generate input vectors for Verilog testbench")
    parser.add_argument("--evaluate", action="store_true", help="Evaluate output vector file generated by Verilog")
    parser.add_argument("--count", type=int, default=25, help="Number of test cases to generate")

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
