type TRSWUtils = type Pointer;
var  RSWUtils: TRSWUtils;
  
  
{*
 @TPASkeleton: 
 Given a set of points, this function should thin the TPA down to it's bare Skeleton.
 It also takes two modifiers which allow you to change the outcome.
 By letting eather FMin, or FMax be -1 then it will be set to it's defaults which are 2 and 6.
*}
function TRSWUtils.TPASkeleton(const TPA:TPointArray; FMin,FMax:Int32): TPointArray; static;
var
  j,i,x,y,h,transit,sumn,MarkHigh,hits: Int32;
  p2,p3,p4,p5,p6,p7,p8,p9:Int32;
  Change, PTS: TPointArray;
  Matrix: T2DByteArray;
  iter : Boolean;
  Area: TBox;
  
  function TransitCount(p2,p3,p4,p5,p6,p7,p8,p9:Int32): Int32;
  begin
    Result := 0;
    if ((p2 = 0) and (p3 = 1)) then Inc(Result);
    if ((p3 = 0) and (p4 = 1)) then Inc(Result);
    if ((p4 = 0) and (p5 = 1)) then Inc(Result);
    if ((p5 = 0) and (p6 = 1)) then Inc(Result);
    if ((p6 = 0) and (p7 = 1)) then Inc(Result);
    if ((p7 = 0) and (p8 = 1)) then Inc(Result);
    if ((p8 = 0) and (p9 = 1)) then Inc(Result);
    if ((p9 = 0) and (p2 = 1)) then Inc(Result);
  end;
  
begin
  H := High(TPA);
  if (H = -1) then Exit;
  Area := GetTPABounds(TPA);
  Area.x1 := Area.x1 - 2;
  Area.y1 := Area.y1 - 2;
  Area.x2 := (Area.x2 - Area.x1) + 2;
  Area.y2 := (Area.y2 - Area.y1) + 2;
  SetLength(Matrix, Area.y2, Area.x2);
  if (FMin = -1) then FMin := 2;
  if (FMax = -1) then FMax := 6;

  SetLength(PTS, H + 1);
  for i:=0 to H do
  begin
    x := (TPA[i].x-Area.x1);
    y := (TPA[i].y-Area.y1);
    PTS[i] := Point(x,y);
    Matrix[y][x] := 1;
  end;
  j := 0;
  MarkHigh := H;
  SetLength(Change, H+1);
  repeat
    iter := (J mod 2) = 0;
    Hits := 0;
    i := 0;
    while i < MarkHigh do begin
      x := PTS[i].x;
      y := PTS[i].y;
      p2 := Matrix[y-1][x];
      p4 := Matrix[y][x+1];
      p6 := Matrix[y+1][x];
      p8 := Matrix[y][x-1];

      if (Iter) then begin
        if (((p4 * p6 * p8) <> 0) or ((p2 * p4 * p6) <> 0)) then begin
          Inc(i);
          Continue;
        end;
      end else if ((p2 * p4 * p8) <> 0) or ((p2 * p6 * p8) <> 0) then
      begin
        Inc(i);
        Continue;
      end;

      p3 := Matrix[y-1][x+1];
      p5 := Matrix[y+1][x+1];
      p7 := Matrix[y+1][x-1];
      p9 := Matrix[y-1][x-1];
      Sumn := (p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9);
      if (SumN >= FMin) and (SumN <= FMax) then begin
        Transit := TransitCount(p2,p3,p4,p5,p6,p7,p8,p9);
        if (Transit = 1) then begin
          Change[Hits] := PTS[i];
          Inc(Hits);
          PTS[i] := PTS[MarkHigh];
          PTS[MarkHigh] := Point(x,y);
          Dec(MarkHigh);
          Continue;
        end;
      end;
      Inc(i);
    end;

    for i:=0 to (Hits-1) do
      Matrix[Change[i].y][Change[i].x] := 0;

    inc(j);
  until ((Hits=0) and (Iter=False));

  SetLength(Result, (MarkHigh + 1));
  for i := 0 to MarkHigh do
    Result[i] := Point(PTS[i].x+Area.x1, PTS[i].y+Area.y1);
end;

function TRSWUtils.InPolyR(x,y:Int32; const Poly:TPointArray): Boolean; static;
var j,i,H: Int32;
begin
  H := High(poly);
  j := H;
  Result := False;
  for i:=0 to H do begin
    if ((poly[i].y < y) and (poly[j].y >= y) or (poly[j].y < y) and (poly[i].y >= y)) then
      if (poly[i].x+(y-poly[i].y) / (poly[j].y-poly[i].y) * (poly[j].x-poly[i].x) < x) then
        Result := not(Result);
    j := i;
  end;
end;


function TRSWUtils.TPAFromPolygon(const Poly:TPointArray): TPointArray; static;
var 
  i,j,x,y,w,h,c: Int32;
  mat: array of TBoolArray;
  TPA: TPointArray;
  area: TBox;
  inside: Boolean;
begin
  TPA := Copy(Poly);
  area := GetTPABounds(TPA);
  w := area.x2-area.x1+1;
  h := area.y2-area.y1+1;
  
  SetLength(mat, H, W);
  OffsetTPA(TPA, Point(area.x1, area.y1));
  SetLength(Result, 1024);
  for y:=0 to H-1 do
    for x:=0 to W-1 do
    begin
      j := High(TPA);
      inside := False;
      for i:=0 to High(TPA) do
      begin
        if ((TPA[i].y < y) and (TPA[j].y >= y) or (TPA[j].y < y) and (TPA[i].y >= y)) then
          if (TPA[i].x+(y-TPA[i].y) / (TPA[j].y-TPA[i].y) * (TPA[j].x-TPA[i].x) < x) then
            inside := not(inside);
        j := i;
      end;
      
      if inside then
      begin
        if c = Length(Result) then
          SetLength(Result, Length(Result)*2);
        
        Result[c] := Point(x,y);
        Inc(c);
      end;
    end;
end;

function TRSWUtils.BuildPath(TPA: TPointArray; step:Int32=25): TPointArray; static;
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
