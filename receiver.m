function [rxBits, rxInfo] = receiver(rxSignal, params, txInfo)
%RECEIVER  Full receiver chain: BPF -> downconvert -> LPF -> MF -> demod -> decode.
%
%   [rxBits, rxInfo] = receiver(rxSignal, params, txInfo)

Fs  = params.Fs;
sps = params.samplesPerSymbol;
fc  = params.carrierFreq;

%% 1. Bandpass Filter (reject out-of-band noise)
halfBW   = params.symbolRate * (1 + params.rrcRolloff) / 2;
bpfFreqs = [fc - halfBW, fc + halfBW];
bpfFreqNorm = min(max(bpfFreqs / (Fs/2), 0.01), 0.99);
[bpfB, bpfA] = butter(4, bpfFreqNorm, 'bandpass');
rxBPF = filtfilt(bpfB, bpfA, rxSignal);

%% 2. Downconversion (mix with local carrier)
N  = length(rxBPF);
t  = (0:N-1).' / Fs;
rxIQ = rxBPF .* exp(-1j * 2 * pi * fc * t);   % complex baseband

%% 3. Low-Pass Filter (remove 2*fc image)
lpfCutoff = params.symbolRate * (1 + params.rrcRolloff) / (Fs/2);
lpfCutoff = min(lpfCutoff, 0.99);
[lpfB, lpfA] = butter(6, lpfCutoff, 'low');
rxBaseI = filtfilt(lpfB, lpfA, real(rxIQ));
rxBaseQ = filtfilt(lpfB, lpfA, imag(rxIQ));
rxBase  = rxBaseI + 1j * rxBaseQ;

%% 4. RRC Matched Filter
rrcFilter  = txInfo.rrcFilter;
filterDelay = txInfo.filterDelay;
mfOutI = filter(rrcFilter, 1, real(rxBase));
mfOutQ = filter(rrcFilter, 1, imag(rxBase));
mfOut  = mfOutI + 1j * mfOutQ;

% Compensate for total group delay (Tx filter + Rx filter = 2x filterDelay)
totalDelay = 2 * filterDelay;
if totalDelay < length(mfOut)
    mfOut = mfOut(totalDelay+1:end);
else
    mfOut = mfOut;   % edge case: not enough samples
end

%% 5. Symbol-Rate Sampling (downsample)
% Align to first valid sample
rxSymbols = mfOut(1:sps:end);

%% 6. Demodulation (symbol decisions)
rxEncBits = demodulate_symbols(rxSymbols, params.modulation);

%% 7. Viterbi Decoding
trellis = txInfo.trellis;
tbLen   = 5 * params.constraintLength;   % traceback depth
rxBits  = vitdec(rxEncBits, trellis, tbLen, 'trunc', 'hard');

% Trim to original bit count
rxBits = rxBits(1:min(params.numBits, length(rxBits)));

%% Package diagnostics
rxInfo.rxBPF      = rxBPF;
rxInfo.rxBase     = rxBase;
rxInfo.mfOut      = mfOut;
rxInfo.rxSymbols  = rxSymbols;
rxInfo.rxEncBits  = rxEncBits;

end
