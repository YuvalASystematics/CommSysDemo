function rxBits = demodulate_symbols(rxSymbols, modType)
%DEMODULATE_SYMBOLS  Hard-decision symbol-to-bit mapping.

switch upper(modType)
    case 'BPSK'
        % Threshold at 0 on real axis
        rxBits = double(real(rxSymbols) < 0);   % +1->0, -1->1

    case 'QPSK'
        % Separate I and Q decisions, then interleave
        bI = double(real(rxSymbols) < 0);
        bQ = double(imag(rxSymbols) < 0);
        rxBits = zeros(2*length(rxSymbols), 1);
        rxBits(1:2:end) = bI;
        rxBits(2:2:end) = bQ;

    otherwise
        error('Unsupported modulation: %s', modType);
end

rxBits = rxBits(:);
end
