%% main_comm_system.m — Entry point for the digital communication system simulation
% Run this file to execute the full simulation end-to-end.

clear; close all; clc;

%% System Parameters
params.numBits          = 10000;
params.samplesPerSymbol = 8;
params.rrcRolloff       = 0.25;
params.rrcFilterSpan    = 10;        % symbols
params.convCodeRate     = 1/2;
params.constraintLength = 7;
params.modulation       = 'BPSK';    % 'BPSK' or 'QPSK'
params.bitRate          = 1e6;       % 1 Mbps
params.carrierFreq      = 10e6;      % 10 MHz carrier
params.EbN0_dB_range    = -2:1:12;   % Eb/N0 sweep range (dB)

% Derived parameters
params.symbolRate = params.bitRate * params.convCodeRate;
if strcmpi(params.modulation, 'QPSK')
    params.symbolRate = params.symbolRate / 2;
end
params.Fs = params.samplesPerSymbol * params.symbolRate;  % sampling frequency

fprintf('=== Digital Communication System Simulation ===\n');
fprintf('Modulation   : %s\n', params.modulation);
fprintf('Code Rate    : 1/%d\n', round(1/params.convCodeRate));
fprintf('Bit Rate     : %.1f Mbps\n', params.bitRate/1e6);
fprintf('Carrier Freq : %.1f MHz\n', params.carrierFreq/1e6);
fprintf('Sample Rate  : %.1f MHz\n', params.Fs/1e6);
fprintf('Num Bits     : %d\n', params.numBits);
fprintf('===============================================\n\n');

%% BER vs Eb/N0 Sweep
numEbN0 = length(params.EbN0_dB_range);
BER_sim  = zeros(1, numEbN0);

% Single-point detailed run at Eb/N0 = 6 dB for diagnostics/plots
EbN0_plot = 6;
fprintf('Running detailed simulation at Eb/N0 = %d dB...\n', EbN0_plot);

txBits = generate_signal(params);
[txSignal, txInfo] = transmitter(txBits, params);
rxSignal = awgn_channel(txSignal, params, EbN0_plot);
[rxBits, rxInfo] = receiver(rxSignal, params, txInfo);
[BER_single, ~] = evaluate_ber(txBits, rxBits, params, txInfo, rxInfo, EbN0_plot, true);
fprintf('BER at Eb/N0=%ddB : %.4f\n\n', EbN0_plot, BER_single);

%% BER Sweep
fprintf('Running BER sweep over Eb/N0 = [%d : %d] dB...\n', ...
    params.EbN0_dB_range(1), params.EbN0_dB_range(end));

for k = 1:numEbN0
    EbN0 = params.EbN0_dB_range(k);
    bits  = generate_signal(params);
    [tx, tInfo] = transmitter(bits, params);
    rx   = awgn_channel(tx, params, EbN0);
    [rb, ~] = receiver(rx, params, tInfo);
    [BER_sim(k), ~] = evaluate_ber(bits, rb, params, tInfo, [], EbN0, false);
    fprintf('  Eb/N0 = %+3d dB  ->  BER = %.5f\n', EbN0, BER_sim(k));
end

%% Plot BER Curve
evaluate_ber([], [], params, [], [], [], false, ...
             'plot_ber_curve', BER_sim, params.EbN0_dB_range);

fprintf('\nSimulation complete.\n');
