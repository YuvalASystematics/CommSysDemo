# CommSysDemo — How to Run

## Quick Start

1. Open MATLAB (R2021a or later recommended).
2. Open the project: **Home → Open → `CommSysDemo.prj`**  
   (This sets the MATLAB path automatically.)
3. Run the simulation:
   ```matlab
   main_comm_system
   ```

The script sweeps Eb/N0 from −2 dB to 12 dB and produces four figure windows.

---

## System Architecture

```
[generate_signal] → [transmitter] → [awgn_channel] → [receiver] → [evaluate_ber]
```

### Block Descriptions

| File | Role |
|------|------|
| `main_comm_system.m` | Entry point; defines all params, runs BER sweep |
| `generate_signal.m` | Produces random binary bitstream |
| `transmitter.m` | Encode → Modulate → RRC Tx filter → Upconvert → BPF → PA |
| `modulate_symbols.m` | BPSK / QPSK symbol mapping |
| `awgn_channel.m` | Adds AWGN calibrated to Eb/N0 |
| `receiver.m` | BPF → Downconvert → LPF → RRC MF → Downsample → Demodulate → Viterbi |
| `demodulate_symbols.m` | Hard-decision symbol-to-bit demapping |
| `evaluate_ber.m` | BER calculation + all diagnostic plots |

---

## Signal Flow Detail

### Transmitter
1. **Convolutional encoder** — rate-1/2, constraint length 7 (polynomials 171, 133 octal)
2. **BPSK/QPSK modulator** — maps encoded bits to ±1 (BPSK) or Gray-coded complex symbols (QPSK)
3. **RRC Tx filter** — pulse shaping with rolloff α=0.25, span=10 symbols, 8 samples/symbol
4. **Upconversion** — multiply baseband by `exp(j·2π·fc·t)`, take real part → bandpass signal
5. **Bandpass filter** — 4th-order Butterworth; limits out-of-band emissions
6. **Power amplifier** — unity gain; signal normalized to unit RMS

### Channel
- AWGN: noise power calibrated from Eb/N0 accounting for code rate and modulation order

### Receiver
1. **Bandpass filter** — mirrors Tx BPF; rejects out-of-band noise
2. **Downconversion** — multiply by `exp(−j·2π·fc·t)` → complex baseband
3. **Low-pass filter** — removes 2fc image; 6th-order Butterworth
4. **RRC matched filter** — identical to Tx filter (forms raised-cosine end-to-end response)
5. **Group delay compensation** — trims 2 × (filterSpan×sps/2) samples from matched filter output
6. **Symbol-rate downsampling** — take every sps-th sample
7. **Hard-decision demodulator** — threshold detection on I (and Q for QPSK)
8. **Viterbi decoder** — truncation mode, traceback depth = 5 × constraintLength

---

## Output Plots

| Figure | Contents |
|--------|----------|
| Constellation Diagrams | Tx symbols vs. Rx symbols at chosen Eb/N0 |
| Time-Domain Signals | Baseband I, RF, received baseband |
| Signal Spectrum | PSD before and after channel (Welch method) |
| BER vs Eb/N0 | Simulated BER overlaid on theoretical BPSK curve |

---

## Changing Modulation to QPSK

In `main_comm_system.m`, change:
```matlab
params.modulation = 'QPSK';
```

---

## Requirements

- MATLAB Communications Toolbox (`convenc`, `vitdec`, `rcosdesign`)
- No Simulink required

---

## Project Parameters (defaults)

| Parameter | Value |
|-----------|-------|
| numBits | 10 000 |
| samplesPerSymbol | 8 |
| rrcRolloff | 0.25 |
| rrcFilterSpan | 10 symbols |
| convCodeRate | 1/2 |
| constraintLength | 7 |
| modulation | BPSK |
| bitRate | 1 Mbps |
| carrierFreq | 10 MHz |
| Fs (derived) | 8 Msps |
| Eb/N0 sweep | −2 to 12 dB |
