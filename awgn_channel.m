function rxSignal = awgn_channel(txSignal, params, EbN0_dB)
%AWGN_CHANNEL  Add white Gaussian noise calibrated to Eb/N0.
%
%   rxSignal = awgn_channel(txSignal, params, EbN0_dB)
%
%   Noise power is computed from Eb/N0 accounting for modulation order,
%   code rate, and samples-per-symbol.

% Bits per symbol
bitsPerSym = 1;
if strcmpi(params.modulation, 'QPSK')
    bitsPerSym = 2;
end

% Es/N0 = Eb/N0 * bitsPerSym * codeRate
EsN0_dB  = EbN0_dB + 10*log10(bitsPerSym * params.convCodeRate);

% Noise variance per real sample (bandpass signal, so divide by samplesPerSymbol)
% Signal is normalized to unit RMS, so Ps = 1.
% N0/2 = Ps / (2 * EsN0_linear * samplesPerSymbol) * (Fs/symbolRate)
EsN0_lin = 10^(EsN0_dB / 10);
noisePow = 1 / (2 * EsN0_lin * params.samplesPerSymbol);

noise    = sqrt(noisePow) * randn(size(txSignal));
rxSignal = txSignal + noise;

end
