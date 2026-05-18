function rxSignal = awgn_channel(txSignal, params, EbN0_dB)
%AWGN_CHANNEL  Add white Gaussian noise calibrated to Eb/N0.
%
%   rxSignal = awgn_channel(txSignal, params, EbN0_dB)
%
%   Noise power is computed from Eb/N0 accounting for modulation order,
%   code rate, and samples-per-symbol.

% Bits per information symbol
bitsPerSym = 1;
if strcmpi(params.modulation, 'QPSK')
    bitsPerSym = 2;
end

% Discrete-time noise variance for real bandpass signal normalized to unit RMS.
%
% Derivation: Ps = 1, Fs = sps * Rs, Rs = Rb / (codeRate * bitsPerSym)
%   sigma^2 = Ps * Fs / (2 * Rb * EbN0_lin)
%           = sps * Rs / (2 * Rs * codeRate * bitsPerSym * EbN0_lin)
%           = sps / (2 * codeRate * bitsPerSym * EbN0_lin)
EbN0_lin = 10^(EbN0_dB / 10);
noisePow = params.samplesPerSymbol / (2 * params.convCodeRate * bitsPerSym * EbN0_lin);

noise    = sqrt(noisePow) * randn(size(txSignal));
rxSignal = txSignal + noise;

end
