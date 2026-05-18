function [BER, numErrors] = evaluate_ber(txBits, rxBits, params, txInfo, rxInfo, ...
                                          EbN0_dB, doPlots, varargin)
%EVALUATE_BER  Compute BER and (optionally) generate diagnostic plots.
%
%   [BER, numErrors] = evaluate_ber(txBits, rxBits, params, txInfo, rxInfo,
%                                   EbN0_dB, doPlots)
%
%   Special call for BER curve:
%   evaluate_ber([], [], params, [], [], [], false, ...
%                'plot_ber_curve', BER_sim, EbN0_range)

%% BER Curve plot mode (called from main after sweep)
if nargin >= 8 && ischar(varargin{1}) && strcmp(varargin{1}, 'plot_ber_curve')
    BER_sim_vec  = varargin{2};
    EbN0_range   = varargin{3};
    plot_ber_curve(BER_sim_vec, EbN0_range, params);
    BER = NaN; numErrors = NaN;
    return;
end

%% Standard BER calculation
nCompare = min(length(txBits), length(rxBits));
txTrim   = txBits(1:nCompare);
rxTrim   = rxBits(1:nCompare);
numErrors = sum(txTrim ~= rxTrim);
BER       = numErrors / nCompare;

if ~doPlots
    return;
end

%% ---- Diagnostic Plots ----

%% Figure 1: Constellation Diagrams
figure('Name','Constellation Diagrams','NumberTitle','off','Position',[100 100 900 400]);

subplot(1,2,1);
txSym = txInfo.symbols;
scatter(real(txSym), imag(txSym), 20, 'b', 'filled', 'MarkerFaceAlpha', 0.3);
title('Tx Constellation (after modulation)');
xlabel('In-Phase'); ylabel('Quadrature');
grid on; axis equal;
xlim([-1.8 1.8]); ylim([-1.8 1.8]);

subplot(1,2,2);
rxSym = rxInfo.rxSymbols;
% Trim to same length as Tx symbols for comparison
nSym = min(length(txSym), length(rxSym));
scatter(real(rxSym(1:nSym)), imag(rxSym(1:nSym)), 20, 'r', 'filled', 'MarkerFaceAlpha', 0.3);
title(sprintf('Rx Constellation (Eb/N0 = %d dB)', EbN0_dB));
xlabel('In-Phase'); ylabel('Quadrature');
grid on; axis equal;
xlim([-1.8 1.8]); ylim([-1.8 1.8]);

%% Figure 2: Time-Domain Signals
figure('Name','Time-Domain Signals','NumberTitle','off','Position',[100 560 1200 500]);
Nplot = min(200 * params.samplesPerSymbol, length(txInfo.t));
tPlot = txInfo.t(1:Nplot) * 1e6;   % microseconds

subplot(3,1,1);
plot(tPlot, real(txInfo.baseband(1:Nplot)));
title('Baseband Signal (I channel, after RRC Tx filter)');
xlabel('Time (µs)'); ylabel('Amplitude'); grid on;

subplot(3,1,2);
plot(tPlot, txInfo.rfSignal(1:Nplot));
title('RF Signal (after upconversion)');
xlabel('Time (µs)'); ylabel('Amplitude'); grid on;

rxPlot = rxInfo.rxBase;
subplot(3,1,3);
plot(tPlot(1:min(Nplot,length(rxPlot))), real(rxPlot(1:min(Nplot,length(rxPlot)))));
title('Received Baseband (after downconversion + LPF)');
xlabel('Time (µs)'); ylabel('Amplitude'); grid on;

%% Figure 3: Power Spectral Density
figure('Name','Signal Spectrum','NumberTitle','off','Position',[100 100 1000 400]);
NFFT = 4096;
txRF_seg  = txInfo.rfSignal(1:min(NFFT, length(txInfo.rfSignal)));
rxRF_seg  = rxInfo.rxBPF(1:min(NFFT, length(rxInfo.rxBPF)));

[Ptx, ftx] = pwelch(txRF_seg, [], [], NFFT, params.Fs, 'centered');
[Prx, frx] = pwelch(rxRF_seg, [], [], NFFT, params.Fs, 'centered');

subplot(1,2,1);
plot(ftx/1e6, 10*log10(Ptx));
title('Tx Signal Spectrum (before channel)');
xlabel('Frequency (MHz)'); ylabel('PSD (dB/Hz)'); grid on;

subplot(1,2,2);
plot(frx/1e6, 10*log10(Prx));
title('Rx Signal Spectrum (after channel)');
xlabel('Frequency (MHz)'); ylabel('PSD (dB/Hz)'); grid on;

end

%% ---- Helper: BER Curve ----
function plot_ber_curve(BER_sim, EbN0_range, params)

% Theoretical BER for BPSK (also used as reference for coded systems)
EbN0_lin   = 10.^(EbN0_range/10);
BER_theory = 0.5 * erfc(sqrt(EbN0_lin));   % uncoded BPSK theoretical

figure('Name','BER vs Eb/N0','NumberTitle','off','Position',[200 200 700 500]);

semilogy(EbN0_range, BER_theory, 'b--', 'LineWidth', 2, 'DisplayName', ...
         'Theoretical BPSK (uncoded)');
hold on;

% Replace zero BERs with a small value for plotting
BER_plot = BER_sim;
BER_plot(BER_plot == 0) = 1e-6;
semilogy(EbN0_range, BER_plot, 'ro-', 'LineWidth', 2, 'MarkerSize', 8, ...
         'DisplayName', sprintf('Simulated %s (rate-1/2 conv.)', params.modulation));

xlabel('Eb/N0 (dB)');
ylabel('Bit Error Rate (BER)');
title('BER vs Eb/N0');
legend('Location','southwest');
grid on;
ylim([1e-6 1]);
xlim([EbN0_range(1) EbN0_range(end)]);

end
