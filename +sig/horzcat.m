function C = horzcat(varargin)
%HORZCAT Horizontally concatenate multiple inputs
%   Returns signal what contains multiple values concatenated.  Inputs may
%   be a mix of signals and non-signals.
%
%   Examples:
%     net = sig.Net;
%     sig1 = net.origin('1');
%     sig2 = net.origin('2');
%     inp3 = pi;
%     C = sig.horzcat(sig1,sig2,inp3)
%     sig1.post(1.0)
%     sig2.post(2.0)
%     >> 1.0000    2.0000    3.1416
%
% See also HORZCAT, SIG.VERTCAT

b = cellfun(@(a)isa(a, 'sig.Signal'), varargin);
if ~any(b)
  C = horzcat(varargin{:});
else
  C = mapn(varargin{:}, @(varargin)horzcat(varargin{:}));
end

end

