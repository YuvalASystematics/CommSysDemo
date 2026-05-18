function txBits = generate_signal(params)
%GENERATE_SIGNAL  Generate a random binary bitstream.
%   txBits = generate_signal(params)
%   Returns a column vector of params.numBits random bits (0/1).

txBits = randi([0 1], params.numBits, 1);
end
