function [symbols, bitsPerSym] = modulate_symbols(bits, modType)
%MODULATE_SYMBOLS  Map encoded bits to complex baseband symbols.
%   BPSK: 1 bit/symbol,  constellation {-1, +1}
%   QPSK: 2 bits/symbol, Gray-coded, unit-energy constellation

switch upper(modType)
    case 'BPSK'
        bitsPerSym = 1;
        symbols    = 1 - 2 * double(bits(:));  % 0->+1, 1->-1

    case 'QPSK'
        bitsPerSym = 2;
        bits = bits(:);
        % Pad to even length
        if mod(length(bits), 2) ~= 0
            bits = [bits; 0];
        end
        bI = bits(1:2:end);
        bQ = bits(2:2:end);
        % Gray mapping: 0->+1, 1->-1 on each axis; normalize to unit energy
        symbols = (1 - 2*double(bI) + 1j*(1 - 2*double(bQ))) / sqrt(2);

    otherwise
        error('Unsupported modulation: %s. Use BPSK or QPSK.', modType);
end

end
