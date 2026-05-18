function [txSignal, txInfo] = transmitter(txBits, params)
%TRANSMITTER  Full transmitter chain: encode -> modulate -> pulse-shape -> upconvert.
%
%   [txSignal, txInfo] = transmitter(txBits, params)
%
%   txInfo carries intermediate signals and metadata needed by the receiver.

%% 1. Convolutional Encoding
trellis   = poly2trellis(params.constraintLength, [171 133]);  % rate-1/2, K=7
encBits   = convenc(txBits, trellis);                           % column vector

%% 2. Baseband Modulation
[symbols, bitsPerSym] = modulate_symbols(encBits, params.modulation);

%% 3. RRC Pulse Shaping (Tx filter)
rrcFilter = rcosdesign(params.rrcRolloff, params.rrcFilterSpan, ...
                        params.samplesPerSymbol, 'sqrt');
filterDelay = params.rrcFilterSpan * params.samplesPerSymbol / 2;  % samples

% Upsample and filter
symbolsUp = upsample(symbols, params.samplesPerSymbol);
basebandI = filter(rrcFilter, 1, real(symbolsUp));
basebandQ = filter(rrcFilter, 1, imag(symbolsUp));
baseband  = basebandI + 1j * basebandQ;

%% 4. Upconversion to RF
N  = length(baseband);
t  = (0:N-1).' / params.Fs;
carrier = exp(1j * 2 * pi * params.carrierFreq * t);
rfSignal = real(baseband .* carrier);   % real bandpass signal

%% 5. Transmit Bandpass Filter (limit OOB emissions)
% BPF spans ±halfBW around the carrier frequency
halfBW   = params.symbolRate * (1 + params.rrcRolloff) / 2;
bpfFreqs = [params.carrierFreq - halfBW, params.carrierFreq + halfBW];
bpfFreqNorm = bpfFreqs / (params.Fs / 2);
bpfFreqNorm = min(max(bpfFreqNorm, 0.01), 0.99);   % clamp to valid range
[bpfB, bpfA] = butter(4, bpfFreqNorm, 'bandpass');
txFiltered = filtfilt(bpfB, bpfA, rfSignal);

%% 6. Power Amplifier (gain + normalization)
paGain   = 1.0;                                          % unity gain (linear)
txSignal = paGain * txFiltered;
txSignal = txSignal / rms(txSignal);                     % normalize to unit RMS

%% Package intermediate signals for diagnostics / receiver
txInfo.encBits      = encBits;
txInfo.symbols      = symbols;
txInfo.baseband     = baseband;
txInfo.rfSignal     = rfSignal;
txInfo.filterDelay  = filterDelay;
txInfo.bitsPerSym   = bitsPerSym;
txInfo.trellis      = trellis;
txInfo.rrcFilter    = rrcFilter;
txInfo.t            = t;

end
