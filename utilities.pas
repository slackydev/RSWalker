type
  RSWUtils = type Pointer;

var
  MM_AREA: TBox := [570,11,714,155];//[570,9,714,159];
  MM_CROP: TBox := [0,0,MM_AREA.X2-MM_AREA.X1,MM_AREA.Y2-MM_AREA.Y1];
  MM_RAD: Int32 := 64;


function RSWUtils.InPoly(p:TPoint; const Poly:TPointArray): Boolean; static;
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

function RSWUtils.BuildPath(TPA: TPointArray; step:Int32=15): TPointArray; static;
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

function RSWUtils.MinBoxInRotated(B: TBox; Angle: Double): TBox; static;
var
  sinA,cosA,ss,ls,x,wr,hr: Double;
  W,H: Int32;
begin
  W := B.x2-B.x1+1;
  H := B.y2-B.y1+1;
  ls := W;
  ss := H;
  if w < h then Swap(ls,ss);

  sinA := Abs(Sin(Angle));
  cosA := Abs(Cos(Angle));
  if (ss <= 2.0*sinA*cosA*ls) or (abs(sinA-cosA) < 0.00001) then
  begin
    wr := (0.5*ss)/sinA;
    hr := (0.5*ss)/cosA;
    if (w < h) then Swap(wr,hr);
  end else
  begin
    wr := (W*cosA - H*sinA) / (Sqr(cosA) - Sqr(sinA));
    hr := (H*cosA - W*sinA) / (Sqr(cosA) - Sqr(sinA));
  end;

  with B.Middle() do
  begin
    Result := [Trunc(X-wr/2), Trunc(Y-hr/2), Ceil(X+wr/2), Ceil(Y+hr/2)];
    Result.LimitTo(B);
  end;
end;

function RSWUtils.GetMinimap(Smooth, Sample: Boolean; ratio:Int32=1): T2DIntArray; static;
var
  bmp: PtrUInt;
  B: TBox;
  th: Double;

  procedure ClearCorners();
  var
    i,color: Int32;
    TPA: TPointArray;
  begin
    TPA := TPAFromPolygon(Minimap.MaskPoly);
    TPA := TPA.Invert();
    FilterPointsBox(TPA, MM_AREA.X1,MM_AREA.Y1+1,MM_AREA.X2,MM_AREA.Y2);
    TPA.Offset(Point(-MM_AREA.X1,-MM_AREA.Y1));
    DrawTPABitmap(BMP, TPA, 0);
    TPA.SortByY(True);
    for i:=0 to High(TPA) do
      FastSetPixel(bmp, TPA[i].x,TPA[i].y, FastGetPixel(bmp,TPA[i].x,TPA[i].y-1));
  end;
begin
  th  := Minimap.GetCompassAngle(False);
  BMP := BitmapFromClient(MM_AREA.x1, MM_AREA.y1, MM_AREA.x2, MM_AREA.y2);
  ClearCorners();
  Result := BitmapToMatrix(BMP);
  FreeBitmap(BMP);
  Result := w_ImRotate(Result, th, False, Smooth);
  B := RSWUtils.MinBoxInRotated(MM_CROP, th);
  while B.Width  > 110 do begin B.x2 -= 1; B.x1 += 1; end;
  while B.Height > 100 do begin B.y2 -= 1; B.y1 += 1; end;
  Result := w_GetArea(Result, B.x1,B.y1,B.x2,B.y2);

  if Sample then
    Result := w_ImSample(Result, ratio);
end;
