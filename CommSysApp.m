classdef CommSysApp < matlab.apps.AppBase

    % ------------------------------------------------------------------ %
    %  UI component properties                                            %
    % ------------------------------------------------------------------ %
    properties (Access = public)
        UIFigure        matlab.ui.Figure

        % Sidebar
        SidePanel       matlab.ui.container.Panel

        % Parameter controls
        ModDropDown     matlab.ui.control.DropDown
        NumBitsField    matlab.ui.control.NumericEditField
        EbN0FromField   matlab.ui.control.NumericEditField
        EbN0ToField     matlab.ui.control.NumericEditField
        EbN0StepField   matlab.ui.control.NumericEditField
        EbN0SingField   matlab.ui.control.NumericEditField
        BitRateField    matlab.ui.control.NumericEditField
        CarrierField    matlab.ui.control.NumericEditField
        SpsField        matlab.ui.control.NumericEditField
        RolloffField    matlab.ui.control.NumericEditField
        SpanField       matlab.ui.control.NumericEditField

        % Buttons
        RunSweepBtn     matlab.ui.control.Button
        RunSingleBtn    matlab.ui.control.Button

        % Status
        StatusLabel     matlab.ui.control.Label

        % Tabs
        TabGroup        matlab.ui.container.TabGroup
        BERTab          matlab.ui.container.Tab
        ConsTab         matlab.ui.container.Tab
        TimeTab         matlab.ui.container.Tab
        SpecTab         matlab.ui.container.Tab

        % Axes
        BERAx           matlab.ui.control.UIAxes

        ConsTxAx        matlab.ui.control.UIAxes
        ConsRxAx        matlab.ui.control.UIAxes

        TimeBBAx        matlab.ui.control.UIAxes
        TimeRFAx        matlab.ui.control.UIAxes
        TimeRxAx        matlab.ui.control.UIAxes

        SpecTxAx        matlab.ui.control.UIAxes
        SpecRxAx        matlab.ui.control.UIAxes
    end

    % ------------------------------------------------------------------ %
    %  Static helper — sidebar label factory                              %
    % ------------------------------------------------------------------ %
    methods (Static, Access = private)
        function lbl = sL(parent, txt, x, y, w, h, sz, bold, fc, bg)
            if nargin < 8 || isempty(bold), bold = false; end
            if nargin < 9 || isempty(fc),   fc   = [0.90 0.90 0.90]; end
            if nargin < 10|| isempty(bg),   bg   = [0.13 0.16 0.21]; end
            fw = 'normal'; if bold, fw = 'bold'; end
            lbl = uilabel(parent, 'Text', txt, ...
                'Position', [x y w h], 'FontSize', sz, ...
                'FontWeight', fw, 'FontColor', fc, ...
                'BackgroundColor', bg, 'WordWrap', 'off');
        end
    end

    % ------------------------------------------------------------------ %
    %  Private utilities                                                  %
    % ------------------------------------------------------------------ %
    methods (Access = private)

        function params = buildParams(app)
            params.numBits          = app.NumBitsField.Value;
            params.samplesPerSymbol = round(app.SpsField.Value);
            params.rrcRolloff       = app.RolloffField.Value;
            params.rrcFilterSpan    = round(app.SpanField.Value);
            params.convCodeRate     = 0.5;
            params.constraintLength = 7;
            params.modulation       = app.ModDropDown.Value;
            params.bitRate          = app.BitRateField.Value * 1e6;
            params.carrierFreq      = app.CarrierField.Value * 1e6;
            params.EbN0_dB_range    = app.EbN0FromField.Value : ...
                                      app.EbN0StepField.Value : ...
                                      app.EbN0ToField.Value;
            params.symbolRate = params.bitRate / params.convCodeRate;
            if strcmpi(params.modulation, 'QPSK')
                params.symbolRate = params.symbolRate / 2;
            end
            params.Fs = params.samplesPerSymbol * params.symbolRate;
        end

        function setStatus(app, msg, fc)
            if nargin < 3, fc = [0.80 0.82 0.85]; end
            app.StatusLabel.Text      = msg;
            app.StatusLabel.FontColor = fc;
            drawnow limitrate;
        end

        function setBusy(app, busy)
            if busy
                app.RunSweepBtn.Enable  = false;
                app.RunSingleBtn.Enable = false;
            else
                app.RunSweepBtn.Enable  = true;
                app.RunSingleBtn.Enable = true;
            end
        end
    end

    % ------------------------------------------------------------------ %
    %  Callbacks                                                          %
    % ------------------------------------------------------------------ %
    methods (Access = private)

        function RunSweepPushed(app, ~, ~)
            app.setBusy(true);
            try
                params = app.buildParams();
                n      = numel(params.EbN0_dB_range);
                BER    = zeros(1, n);

                for k = 1:n
                    EbN0 = params.EbN0_dB_range(k);
                    app.setStatus( ...
                        sprintf('Sweep %d / %d  —  Eb/N0 = %+.1f dB', k, n, EbN0), ...
                        [0.45 0.80 1.00]);

                    bits       = generate_signal(params);
                    [tx, ti]   = transmitter(bits, params);
                    rx         = awgn_channel(tx, params, EbN0);
                    [rb, ~]    = receiver(rx, params, ti);
                    [BER(k),~] = evaluate_ber(bits, rb, params, ti, [], EbN0, false);
                end

                app.plotBERCurve(params, BER);
                app.TabGroup.SelectedTab = app.BERTab;
                app.setStatus('BER sweep complete  ✓', [0.40 1.00 0.55]);

            catch ME
                app.setStatus(['Error: ' ME.message], [1.00 0.45 0.45]);
            end
            app.setBusy(false);
        end

        function RunSinglePushed(app, ~, ~)
            app.setBusy(true);
            try
                params = app.buildParams();
                EbN0   = app.EbN0SingField.Value;
                app.setStatus(sprintf('Running single point  Eb/N0 = %+.1f dB …', EbN0), ...
                    [0.45 0.80 1.00]);

                bits       = generate_signal(params);
                [tx, ti]   = transmitter(bits, params);
                rx         = awgn_channel(tx, params, EbN0);
                [rb, ri]   = receiver(rx, params, ti);
                [BER, nE]  = evaluate_ber(bits, rb, params, ti, ri, EbN0, false);

                app.plotConstellation(ti, ri, EbN0);
                app.plotTimeDomain(ti, ri, params);
                app.plotSpectrum(ti, ri, params);

                app.TabGroup.SelectedTab = app.ConsTab;
                app.setStatus( ...
                    sprintf('Done  ·  BER = %.5f  (%d bit errors)  ✓', BER, nE), ...
                    [0.40 1.00 0.55]);

            catch ME
                app.setStatus(['Error: ' ME.message], [1.00 0.45 0.45]);
            end
            app.setBusy(false);
        end
    end

    % ------------------------------------------------------------------ %
    %  Plot methods                                                       %
    % ------------------------------------------------------------------ %
    methods (Access = private)

        function plotBERCurve(app, params, BER_sim)
            ax = app.BERAx;
            cla(ax);
            r  = params.EbN0_dB_range;
            th = 0.5 * erfc(sqrt(10.^(r/10)));
            bp = max(BER_sim, 1e-6);

            semilogy(ax, r, th, 'b--', 'LineWidth', 2.0, ...
                'DisplayName', 'Theoretical BPSK (uncoded)');
            hold(ax, 'on');
            semilogy(ax, r, bp, 'o-', 'LineWidth', 2.0, 'MarkerSize', 7, ...
                'Color', [0.93 0.30 0.10], ...
                'DisplayName', sprintf('Simulated %s  (rate-1/2 conv.)', params.modulation));
            hold(ax, 'off');

            xlabel(ax, 'Eb/N0 (dB)');
            ylabel(ax, 'Bit Error Rate');
            title(ax, 'BER vs Eb/N0');
            legend(ax, 'Location', 'southwest');
            grid(ax, 'on');
            ylim(ax, [1e-6 1]);
            xlim(ax, [r(1) r(end)]);
        end

        function plotConstellation(app, txInfo, rxInfo, EbN0)
            cla(app.ConsTxAx);  cla(app.ConsRxAx);

            ts = txInfo.symbols;
            scatter(app.ConsTxAx, real(ts), imag(ts), 22, ...
                [0.20 0.55 0.90], 'filled', 'MarkerFaceAlpha', 0.55);
            title(app.ConsTxAx, 'Tx Constellation');
            xlabel(app.ConsTxAx, 'In-Phase (I)');
            ylabel(app.ConsTxAx, 'Quadrature (Q)');
            grid(app.ConsTxAx, 'on');
            axis(app.ConsTxAx, 'equal');
            xlim(app.ConsTxAx, [-1.8 1.8]);
            ylim(app.ConsTxAx, [-1.8 1.8]);

            rs = rxInfo.rxSymbols;
            n  = min(length(ts), length(rs));
            scatter(app.ConsRxAx, real(rs(1:n)), imag(rs(1:n)), 22, ...
                [0.93 0.30 0.10], 'filled', 'MarkerFaceAlpha', 0.25);
            title(app.ConsRxAx, sprintf('Rx Constellation  (Eb/N0 = %+.1f dB)', EbN0));
            xlabel(app.ConsRxAx, 'In-Phase (I)');
            ylabel(app.ConsRxAx, 'Quadrature (Q)');
            grid(app.ConsRxAx, 'on');
            axis(app.ConsRxAx, 'equal');
            xlim(app.ConsRxAx, [-1.8 1.8]);
            ylim(app.ConsRxAx, [-1.8 1.8]);
        end

        function plotTimeDomain(app, txInfo, rxInfo, params)
            Np = min(200 * params.samplesPerSymbol, length(txInfo.t));
            tp = txInfo.t(1:Np) * 1e6;

            cla(app.TimeBBAx);
            plot(app.TimeBBAx, tp, real(txInfo.baseband(1:Np)), ...
                'Color', [0.20 0.55 0.90], 'LineWidth', 1.0);
            title(app.TimeBBAx, 'Baseband Signal  —  I channel  (after RRC Tx filter)');
            xlabel(app.TimeBBAx, 'Time (µs)');
            ylabel(app.TimeBBAx, 'Amplitude');
            grid(app.TimeBBAx, 'on');

            cla(app.TimeRFAx);
            plot(app.TimeRFAx, tp, txInfo.rfSignal(1:Np), ...
                'Color', [0.93 0.30 0.10], 'LineWidth', 1.0);
            title(app.TimeRFAx, 'RF Signal  (after upconversion)');
            xlabel(app.TimeRFAx, 'Time (µs)');
            ylabel(app.TimeRFAx, 'Amplitude');
            grid(app.TimeRFAx, 'on');

            rb = rxInfo.rxBase;
            Nr = min(Np, length(rb));
            cla(app.TimeRxAx);
            plot(app.TimeRxAx, tp(1:Nr), real(rb(1:Nr)), ...
                'Color', [0.47 0.67 0.19], 'LineWidth', 1.0);
            title(app.TimeRxAx, 'Received Baseband  (after downconversion + LPF)');
            xlabel(app.TimeRxAx, 'Time (µs)');
            ylabel(app.TimeRxAx, 'Amplitude');
            grid(app.TimeRxAx, 'on');
        end

        function plotSpectrum(app, txInfo, rxInfo, params)
            NFFT = 4096;
            Ntx  = min(NFFT, length(txInfo.rfSignal));
            Nrx  = min(NFFT, length(rxInfo.rxBPF));
            [Pt, ft] = pwelch(txInfo.rfSignal(1:Ntx), [], [], NFFT, params.Fs, 'centered');
            [Pr, fr] = pwelch(rxInfo.rxBPF(1:Nrx),   [], [], NFFT, params.Fs, 'centered');

            cla(app.SpecTxAx);
            plot(app.SpecTxAx, ft/1e6, 10*log10(Pt), ...
                'Color', [0.20 0.55 0.90], 'LineWidth', 1.2);
            title(app.SpecTxAx, 'Tx Signal Spectrum  (before channel)');
            xlabel(app.SpecTxAx, 'Frequency (MHz)');
            ylabel(app.SpecTxAx, 'PSD (dB/Hz)');
            grid(app.SpecTxAx, 'on');

            cla(app.SpecRxAx);
            plot(app.SpecRxAx, fr/1e6, 10*log10(Pr), ...
                'Color', [0.93 0.30 0.10], 'LineWidth', 1.2);
            title(app.SpecRxAx, 'Rx Signal Spectrum  (after channel)');
            xlabel(app.SpecRxAx, 'Frequency (MHz)');
            ylabel(app.SpecRxAx, 'PSD (dB/Hz)');
            grid(app.SpecRxAx, 'on');
        end
    end

    % ------------------------------------------------------------------ %
    %  Component construction                                             %
    % ------------------------------------------------------------------ %
    methods (Access = private)

        function createComponents(app)

            % ---- Theme constants ----
            BG   = [0.13 0.16 0.21];   % sidebar background (dark navy)
            FG   = [0.90 0.90 0.90];   % general text
            SEC  = [0.45 0.78 1.00];   % section header accent
            DIV  = [0.25 0.30 0.40];   % divider colour

            FW = 1300;  FH = 780;
            SW = 272;               % sidebar width
            RW = FW - SW;           % right (plot) area width

            % ---- Figure ----
            app.UIFigure = uifigure( ...
                'Name',     'CommSys Simulator', ...
                'Position', [60 40 FW FH], ...
                'Color',    [0.95 0.95 0.96], ...
                'Resize',   'off');

            % ---- Sidebar panel ----
            app.SidePanel = uipanel(app.UIFigure, ...
                'Position',        [0 0 SW FH], ...
                'BackgroundColor', BG, ...
                'BorderType',      'none');

            P = app.SidePanel;   % shorthand

            % ---- Title ----
            CommSysApp.sL(P, 'CommSys Simulator', ...
                10, FH-46, SW-20, 34, 15, true, [1 1 1], BG);
            CommSysApp.sL(P, 'BPSK / QPSK  ·  Conv. Code  ·  AWGN', ...
                10, FH-66, SW-20, 18, 9, false, [0.55 0.65 0.80], BG);

            % Running y-cursor (working downward from top)
            Y = FH - 88;

            % ============================================================
            % SECTION: SIGNAL
            % ============================================================
            CommSysApp.sL(P,'SIGNAL', 10, Y, SW-20, 15, 8, true, SEC, BG);
            Y = Y - 20;

            CommSysApp.sL(P, 'Modulation', 10, Y, SW-20, 15, 9, false, FG, BG);
            Y = Y - 4;
            app.ModDropDown = uidropdown(P, ...
                'Items',    {'BPSK','QPSK'}, ...
                'Value',    'BPSK', ...
                'Position', [10 Y-26 SW-20 26], ...
                'FontSize', 11);
            Y = Y - 34;

            CommSysApp.sL(P, 'Num Bits', 10, Y, SW-20, 15, 9, false, FG, BG);
            Y = Y - 4;
            app.NumBitsField = uieditfield(P, 'numeric', ...
                'Value',    10000, ...
                'Limits',   [100 1e6], ...
                'Position', [10 Y-26 SW-20 26], ...
                'FontSize', 11);
            Y = Y - 38;

            % Divider
            CommSysApp.sL(P, '', 10, Y, SW-20, 1, 8, false, DIV, DIV);
            Y = Y - 10;

            % ============================================================
            % SECTION: CHANNEL
            % ============================================================
            CommSysApp.sL(P, 'CHANNEL', 10, Y, SW-20, 15, 8, true, SEC, BG);
            Y = Y - 20;

            CommSysApp.sL(P, 'Eb/N0 Sweep Range  (dB)', 10, Y, SW-20, 15, 9, false, FG, BG);
            Y = Y - 4;

            % From / To / Step — three equal-width fields
            fw3 = floor((SW - 20 - 12) / 3);   % each field width
            CommSysApp.sL(P, 'From', 10,           Y-14, fw3, 13, 8, false, [0.65 0.72 0.82], BG);
            CommSysApp.sL(P, 'To',   10+fw3+6,     Y-14, fw3, 13, 8, false, [0.65 0.72 0.82], BG);
            CommSysApp.sL(P, 'Step', 10+2*(fw3+6), Y-14, fw3, 13, 8, false, [0.65 0.72 0.82], BG);
            Y = Y - 18;
            app.EbN0FromField = uieditfield(P, 'numeric', ...
                'Value', -2, 'Position', [10 Y-26 fw3 26], 'FontSize', 10);
            app.EbN0ToField   = uieditfield(P, 'numeric', ...
                'Value',  12, 'Position', [10+fw3+6 Y-26 fw3 26], 'FontSize', 10);
            app.EbN0StepField = uieditfield(P, 'numeric', ...
                'Value',   1, 'Limits', [0.1 10], ...
                'Position', [10+2*(fw3+6) Y-26 fw3 26], 'FontSize', 10);
            Y = Y - 38;

            CommSysApp.sL(P, 'Single-Point Eb/N0  (dB)', 10, Y, SW-20, 15, 9, false, FG, BG);
            Y = Y - 4;
            app.EbN0SingField = uieditfield(P, 'numeric', ...
                'Value',    6, ...
                'Position', [10 Y-26 SW-20 26], ...
                'FontSize', 11);
            Y = Y - 38;

            % Divider
            CommSysApp.sL(P, '', 10, Y, SW-20, 1, 8, false, DIV, DIV);
            Y = Y - 10;

            % ============================================================
            % SECTION: RF PARAMETERS
            % ============================================================
            CommSysApp.sL(P, 'RF PARAMETERS', 10, Y, SW-20, 15, 8, true, SEC, BG);
            Y = Y - 20;

            hw = floor((SW - 20 - 8) / 2);   % half-width
            CommSysApp.sL(P, 'Bit Rate (Mbps)',  10,    Y, hw, 15, 9, false, FG, BG);
            CommSysApp.sL(P, 'Carrier (MHz)',  10+hw+8, Y, hw, 15, 9, false, FG, BG);
            Y = Y - 4;
            app.BitRateField = uieditfield(P, 'numeric', ...
                'Value', 1, 'Limits', [0.01 1000], ...
                'Position', [10 Y-26 hw 26], 'FontSize', 11);
            app.CarrierField = uieditfield(P, 'numeric', ...
                'Value', 2, 'Limits', [0.1 1000], ...
                'Position', [10+hw+8 Y-26 hw 26], 'FontSize', 11);
            Y = Y - 38;

            % Divider
            CommSysApp.sL(P, '', 10, Y, SW-20, 1, 8, false, DIV, DIV);
            Y = Y - 10;

            % ============================================================
            % SECTION: PULSE SHAPING
            % ============================================================
            CommSysApp.sL(P, 'PULSE SHAPING', 10, Y, SW-20, 15, 8, true, SEC, BG);
            Y = Y - 20;

            tw = floor((SW - 20 - 12) / 3);
            CommSysApp.sL(P, 'Samp/Symbol',   10,           Y, tw,   15, 9, false, FG, BG);
            CommSysApp.sL(P, 'RRC Rolloff',   10+tw+6,      Y, tw,   15, 9, false, FG, BG);
            CommSysApp.sL(P, 'Span (sym)',     10+2*(tw+6),  Y, tw+2, 15, 9, false, FG, BG);
            Y = Y - 4;
            app.SpsField = uieditfield(P, 'numeric', ...
                'Value', 8, 'Limits', [2 32], ...
                'Position', [10 Y-26 tw 26], 'FontSize', 10);
            app.RolloffField = uieditfield(P, 'numeric', ...
                'Value', 0.25, 'Limits', [0.01 0.99], ...
                'Position', [10+tw+6 Y-26 tw 26], 'FontSize', 10);
            app.SpanField = uieditfield(P, 'numeric', ...
                'Value', 10, 'Limits', [4 20], ...
                'Position', [10+2*(tw+6) Y-26 tw+2 26], 'FontSize', 10);
            Y = Y - 38;    %#ok<NASGU>

            % ============================================================
            % BUTTONS  (anchored to bottom)
            % ============================================================
            app.RunSweepBtn = uibutton(P, 'push', ...
                'Text',             '▶   Run BER Sweep', ...
                'Position',         [10 126 SW-20 38], ...
                'FontSize',         12, ...
                'FontWeight',       'bold', ...
                'BackgroundColor',  [0.17 0.49 0.82], ...
                'FontColor',        [1 1 1], ...
                'ButtonPushedFcn',  @(~,~) app.RunSweepPushed());

            app.RunSingleBtn = uibutton(P, 'push', ...
                'Text',             '◉   Run Single Point', ...
                'Position',         [10 80 SW-20 38], ...
                'FontSize',         12, ...
                'FontWeight',       'bold', ...
                'BackgroundColor',  [0.15 0.42 0.22], ...
                'FontColor',        [1 1 1], ...
                'ButtonPushedFcn',  @(~,~) app.RunSinglePushed());

            % ---- Status label ----
            app.StatusLabel = uilabel(P, ...
                'Text',            'Ready  —  configure parameters and press Run.', ...
                'Position',        [10 4 SW-20 68], ...
                'FontSize',        9, ...
                'FontColor',       [0.70 0.75 0.82], ...
                'BackgroundColor', BG, ...
                'WordWrap',        'on', ...
                'VerticalAlignment','top');

            % ============================================================
            % RIGHT AREA — TAB GROUP
            % ============================================================
            app.TabGroup = uitabgroup(app.UIFigure, ...
                'Position',    [SW 0 RW FH], ...
                'TabLocation', 'top');

            % ---- BER Curve Tab ----
            app.BERTab = uitab(app.TabGroup, 'Title', '  BER Curve  ');
            app.BERAx  = uiaxes(app.BERTab, 'Position', [36 32 RW-56 FH-80]);
            title(app.BERAx,  'BER vs Eb/N0  —  press  ▶ Run BER Sweep');
            xlabel(app.BERAx, 'Eb/N0 (dB)');
            ylabel(app.BERAx, 'Bit Error Rate');
            grid(app.BERAx,   'on');

            % ---- Constellation Tab ----
            app.ConsTab  = uitab(app.TabGroup, 'Title', '  Constellation  ');
            CW = floor((RW - 60) / 2);
            app.ConsTxAx = uiaxes(app.ConsTab, 'Position', [14        32 CW FH-80]);
            app.ConsRxAx = uiaxes(app.ConsTab, 'Position', [24+CW     32 CW FH-80]);
            title(app.ConsTxAx, 'Tx Constellation  —  press  ◉ Run Single Point');
            title(app.ConsRxAx, 'Rx Constellation  —  press  ◉ Run Single Point');
            grid(app.ConsTxAx, 'on');
            grid(app.ConsRxAx, 'on');

            % ---- Time Domain Tab ----
            app.TimeTab  = uitab(app.TabGroup, 'Title', '  Time Domain  ');
            TH = floor((FH - 90) / 3);
            app.TimeBBAx = uiaxes(app.TimeTab, ...
                'Position', [36 FH-TH-48    RW-56 TH-10]);
            app.TimeRFAx = uiaxes(app.TimeTab, ...
                'Position', [36 FH-2*TH-48  RW-56 TH-10]);
            app.TimeRxAx = uiaxes(app.TimeTab, ...
                'Position', [36 FH-3*TH-48  RW-56 TH-10]);
            title(app.TimeBBAx, 'Baseband I  (after RRC Tx filter)');
            title(app.TimeRFAx, 'RF Signal  (after upconversion)');
            title(app.TimeRxAx, 'Received Baseband  (after downconversion + LPF)');
            grid(app.TimeBBAx, 'on');
            grid(app.TimeRFAx, 'on');
            grid(app.TimeRxAx, 'on');

            % ---- Spectrum Tab ----
            app.SpecTab  = uitab(app.TabGroup, 'Title', '  Spectrum  ');
            app.SpecTxAx = uiaxes(app.SpecTab, 'Position', [14        32 CW FH-80]);
            app.SpecRxAx = uiaxes(app.SpecTab, 'Position', [24+CW     32 CW FH-80]);
            title(app.SpecTxAx, 'Tx Signal Spectrum  (before channel)');
            title(app.SpecRxAx, 'Rx Signal Spectrum  (after channel)');
            grid(app.SpecTxAx, 'on');
            grid(app.SpecRxAx, 'on');
        end
    end

    % ------------------------------------------------------------------ %
    %  Constructor / Destructor                                           %
    % ------------------------------------------------------------------ %
    methods (Access = public)

        function app = CommSysApp()
            % Ensure simulation functions are on the path
            appDir = fileparts(mfilename('fullpath'));
            if ~isempty(appDir)
                addpath(appDir);
            end

            createComponents(app);
            registerApp(app, app.UIFigure);

            if nargout == 0
                clear app;
            end
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end
end
