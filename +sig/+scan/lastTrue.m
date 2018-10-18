function n = lastTrue(n, pred)
%SIG.SCAN.LASTTRUE Returns last function call to be true
%  Iterates n when pred evaluates true, returns 0 otherwise
%  Example:
%    repeatLast = advance.keepWhen(hasNext);
%    repeatNum = repeatLast.scan(@sig.scan.lastTrue, 0);
% 
%  See also EXP.TRIALCONDITIONS

if pred
  n = 0;
else
  n = n + 1;
end

end

