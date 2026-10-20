# 64-Bit Error Correction Codes in Verilog & Python

This repository contains Verilog modules and Python utility scripts for 64-bit message error detection and correction, organized into dedicated subfolders for each code type.

---

## 📁 Repository Structure

```
Error correction codes/
├── README.md                          # Documentation
├── Repeatation/                       # (3,1) Repetition Code Module
│   ├── repeat.v                       # (3,1) Repetition Encoder, Decoder & Top Module
│   ├── tb_repeat.v                    # Testbench for Repetition Code
│   ├── repeat_manager.py              # Repetition Code Python utility
│   ├── repeat_input_vector.txt        # Test input vectors
│   └── repeat_output_vector.txt       # Test output vectors
├── parity/                            # Simple Parity Check Module
│   ├── parity_check.v                 # Even & Odd Parity Generator and Checker
│   ├── tb_parity_check.v              # Testbench for simple parity checker
│   ├── ecc_manager.py                 # Parity Python utility
│   ├── input_vector.txt               # Test input vectors
│   └── output_vector.txt              # Test output vectors
├── product/                           # 2D Product Code Module
│   ├── product_code.v                 # 2D Product Code (8x8 Matrix Parity)
│   ├── tb_product_code.v              # Testbench for 2D Product Code
│   └── product_code_manager.py        # 2D Product Code Python utility
├── hamming/                           # Hamming SEC-DED Module
│   ├── hamming_code.v                 # Hamming SEC-DED (72, 64) ECC
│   ├── tb_hamming_code.v              # Testbench for Hamming Code
│   └── hamming_code_manager.py        # Hamming Code Python utility
├── bch/                               # BCH (78, 64, t=2) Module
│   ├── bch_code.v                     # BCH (78, 64, t=2) Encoder & Decoder
│   ├── tb_bch_code.v                  # Testbench for BCH Code
│   ├── bch_manager.py                 # BCH Code Python utility
│   ├── bch_input_vector.txt           # Test input vectors
│   └── bch_output_vector.txt          # Test output vectors
└── convolution/                       # Convolutional (Rate 1/2, K=3) & Viterbi Module
    ├── convolution_code.v             # Convolutional Encoder & Viterbi Decoder
    ├── tb_convolution_code.v          # Testbench for Convolutional Code
    ├── convolution_manager.py         # Convolutional Code Python utility
    ├── convolution_input_vector.txt   # Test input vectors
    └── convolution_output_vector.txt  # Test output vectors
```

---

## 🚀 Module Overview

### 1. (3,1) Repetition Code (`Repeatation/`)
- Encodes 64-bit data into a 192-bit codeword by repeating each bit 3 times.
- Decodes using **3-bit Majority Voting** logic to recover original data.
- Detects bit mismatch errors within any triplet and flags errors.

### 2. Simple Parity (`parity/`)
- Simple **Even** and **Odd** parity bits for 64-bit messages.
- Verilog design, testbench, and Python generator/verifier.

### 3. 2D Product Code (`product/`)
- Arranges 64 bits into an $8 \times 8$ matrix.
- Generates 8 Row Parities and 8 Column Parities.
- Corrects 1-bit errors by matrix intersection $(r_{err}, c_{err})$.

### 4. Hamming SEC-DED (72, 64) Code (`hamming/`)
- Encodes 64 data bits into a 72-bit codeword (64 data + 7 Hamming parity bits + 1 overall parity bit).
- **Single Error Correction (SEC)**: Automatically corrects any 1-bit error in data or parity bits.
- **Double Error Detection (DED)**: Flags uncorrectable 2-bit errors.

### 5. Shortened BCH (78, 64, t=2) Code (`bch/`)
- Encodes 64 data bits into a 78-bit codeword with 14 parity bits over $GF(2^7)$ ($p(x) = x^7 + x^3 + 1$).
- **Double Error Correction (DEC)**: Corrects any 1 or 2 arbitrary bit errors anywhere in the codeword using hardware Peterson-Gorenstein-Zierler syndrome calculation and parallel Chien search.
- **Multi-Error Detection**: Flags uncorrectable errors exceeding correction capacity.

### 6. Convolutional & Viterbi Decoder (`convolution/`)
- Encodes 64 data bits with Rate $1/2$, constraint length $K=3$ polynomials ($G_0 = 7_8, G_1 = 5_8$) into a 132-bit zero-terminated codeword.
- **Maximum Likelihood Decoding**: Full hardware Viterbi decoder with Add-Compare-Select (ACS) and Register Exchange path history across all 66 time steps.
- Recovers messages subject to random channel bit errors.

---

## 💻 Python Utility Examples

**1. Test (3,1) Repetition Code:**
```bash
python Repeatation/repeat_manager.py --gen
python Repeatation/repeat_manager.py --evaluate
```

**2. Test Simple Parity:**
```bash
python parity/ecc_manager.py --gen
python parity/ecc_manager.py --evaluate
```

**3. Test 2D Product Code:**
```bash
python product/product_code_manager.py --gen
python product/product_code_manager.py --evaluate
```

**4. Test Hamming (72, 64) Code:**
```bash
python hamming/hamming_code_manager.py --gen
python hamming/hamming_code_manager.py --evaluate
```

**5. Test BCH (78, 64, t=2) Code:**
```bash
python bch/bch_manager.py --gen
python bch/bch_manager.py --evaluate
```

**6. Test Convolutional & Viterbi Code:**
```bash
python convolution/convolution_manager.py --gen
python convolution/convolution_manager.py --evaluate
```
