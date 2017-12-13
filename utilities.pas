type TRSWUtils = type Pointer;
var  RSWUtils: TRSWUtils;

function TRSWUtils.InPoly(p:TPoint; const Poly:TPointArray): Boolean;
var j,i,H: Int32;
begin
  H := High(poly);
  j := H;
  Result := False;
  for i:=0 to H do begin
    if ((poly[i].y < p.y) and (poly[j].y >= p.y) or (poly[j].y < p.y) and (poly[i].y >= p.y)) then
      if (poly[i].x+(p.y-poly[i].y) / (poly[j].y-poly[i].y) * (poly[j].x-poly[i].x) < p.x) then
        Result := not(Result);
    j := i;
  end;
end;

function TRSWUtils.BuildPath(TPA: TPointArray; step:Int32=25): TPointArray;
var
  i,j,l: Int32;
  tmp: TPointArray;
begin
  for i:=1 to High(TPA) do
  begin
    tmp := TPAFromLine(TPA[i-1].x,TPA[i-1].y, TPA[i].x,TPA[i].y);
    SetLength(Result, l + Ceil(Length(tmp) / step));
    for j:=0 to High(tmp) with step do
      Result[Inc(l)-1] := tmp[j];
  end;
  Result := Result + TPA[High(TPA)];
end;
