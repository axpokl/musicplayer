{$MODE objfpc}
Unit Math;
interface
type float = single;
function log10(x : float) : float;
function power(base,exponent : float) : float;
function intpower(base : float;const exponent : Integer) : float;
implementation
function log10(x : float) : float;
  begin
    log10:=ln(x)*0.43429448190325182765;  { 1/ln(10) }
  end;
function power(base,exponent : float) : float;
  begin
    if Exponent=0.0 then
      result:=1.0
    else if (base=0.0) and (exponent>0.0) then
      result:=0.0
    else if (abs(exponent)<=maxint) and (frac(exponent)=0.0) then
      result:=intpower(base,trunc(exponent))
    else
      result:=exp(exponent * ln (base));
  end;
function intpower(base : float;const exponent : Integer) : float;
  var
     i : longint;
  begin
     if (base = 0.0) and (exponent = 0) then
       result:=1
     else
       begin
         i:=abs(exponent);
         intpower:=1.0;
         while i>0 do
           begin
              while (i and 1)=0 do
                begin
                   i:=i shr 1;
                   base:=sqr(base);
                end;
              i:=i-1;
              intpower:=intpower*base;
           end;
         if exponent<0 then
           intpower:=1.0/intpower;
       end;
  end;
end.