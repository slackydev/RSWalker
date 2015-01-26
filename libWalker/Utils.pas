unit Utils;
{=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=]
 Copyright (c) 2013, Jarl K. <Slacky> Holta || http://github.com/WarPie
 All rights reserved.
 For more info see: Copyright.txt
 
 Methods are borrowed from SimbaExt
[=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=}
{$mode objfpc}{$H+}
{$macro on}
{$modeswitch advancedrecords}
{$inline on}
interface

uses 
  SysUtils, CoreTypes;

//pointtools
function TPABounds(const TPA: TPointArray): TBox; Inline;

//matrix
function GetValues(const Mat:T2DIntArray; const Indices:TPointArray): TIntArray; cdecl;
function GetValuesF(const Mat:T2DFloatArray; const Indices:TPointArray): TFloatArray; cdecl;
function GetArea(const Mat:T2DIntArray; x1,y1,x2,y2:Int32): T2DIntArray; cdecl;
function ArgMax(const Mat:T2DFloatArray): TPoint; cdecl;
function ArgMulti(const Mat:T2DFloatArray; Count:Int32; HiLo:Boolean): TPointArray; cdecl;

//imaging
function imCompareAt(const large,small:T2DIntArray; pt:TPoint; tol:Int32): Single; cdecl;
function imSample(const imgArr:T2DIntArray; Scale:Int32): T2DIntArray; cdecl;
function imRotate(const imgArr:T2DIntArray; Angle:Single; Expand:Boolean; Bilinear:Boolean=True): T2DIntArray; cdecl;


implementation

uses SimpleHeap, Math;


{*
 Return the largest and the smallest numbers for x, and y-axis in TPA.
*}
function TPABounds(const TPA: TPointArray): TBox; Inline;
var
  I: Int32;
begin
  FillChar(Result,SizeOf(TBox),0);
  if (High(TPA) < 0) then Exit;
  Result.x1 := TPA[0].x;
  Result.y1 := TPA[0].y;
  Result.x2 := TPA[0].x;
  Result.y2 := TPA[0].y;
  for I:=1 to High(TPA) do
  begin
    if TPA[i].x > Result.x2 then
      Result.x2 := TPA[i].x
    else if TPA[i].x < Result.x1 then
      Result.x1 := TPA[i].x;
    if TPA[i].y > Result.y2 then
      Result.y2 := TPA[i].y
    else if TPA[i].y < Result.y1 then
      Result.y1 := TPA[i].y;
  end;
end;


//helpers
function GetMatrixSize(const Mat:T2DIntArray; out W,H:Int32): Boolean; Inline;
begin
  H := Length(Mat);
  if H > 0 then W := Length(Mat[0]) else W := 0;
  Result := H > 0;
end;

function GetMatrixHigh(const Mat:T2DIntArray; out W,H:Int32): Boolean; Inline;
begin
  H := High(Mat);
  if H > -1 then W := High(Mat[0]) else W := -1;
  Result := H > -1;
end;



//---| Matrix |-------------------------------------------------------\\
function GetValues(const Mat:T2DIntArray; const Indices:TPointArray): TIntArray; cdecl;
var i,W,H,c,L:Int32;
begin 
  L := High(Indices);
  H := High(Mat);
  if H < 0 then raise Exception.Create('ArgMax: Empty matrix');

  W := High(Mat[0]);
  SetLength(Result, L+1);
  c := 0;
  for i:=0 to L do
    if (Indices[i].x >= 0) and (Indices[i].y >= 0) then
      if (Indices[i].x <= W) and (Indices[i].y <= H) then
      begin
        Result[c] := Mat[Indices[i].y][Indices[i].x];
        Inc(c);
      end;
  SetLength(Result, c);
end;


function GetValuesF(const Mat:T2DFloatArray; const Indices:TPointArray): TFloatArray; cdecl;
var i,W,H,c,L:Int32;
begin 
  L := High(Indices);
  H := High(Mat);
  if H < 0 then raise Exception.Create('ArgMax: Empty matrix');

  W := High(Mat[0]);
  SetLength(Result, L+1);
  c := 0;
  for i:=0 to L do
    if (Indices[i].x >= 0) and (Indices[i].y >= 0) then
      if (Indices[i].x <= W) and (Indices[i].y <= H) then
      begin
        Result[c] := Mat[Indices[i].y][Indices[i].x];
        Inc(c);
      end;
  SetLength(Result, c);
end;


function GetArea(const Mat:T2DIntArray; x1,y1,x2,y2:Int32): T2DIntArray; cdecl;
var Y,H:Int32;
begin 
  H := High(Mat);
  if (H = -1) then Exit();
  x2 := Min(x2, High(Mat[0]));
  y2 := Min(y2, H);
  SetLength(Result, y2-y1+1, x2-x1+1);
  for Y:=y1 to y2 do
    Move(Mat[y][x1], Result[y-y1][0], (x2-x1+1)*SizeOf(Mat[0,0]));
end;


function ArgMax(const Mat:T2DFloatArray): TPoint; cdecl;
var X,Y,W,H:Int32;
begin 
  Result := Point(0,0);
  H := High(Mat);
  if (H = -1) then raise Exception.Create('ArgMax: Empty matrix');
  W := High(Mat[0]);

  for Y:=0 to H do
    for X:=0 to W do
      if Mat[Y][X] > Mat[Result.y][Result.x] then
      begin
        Result.x := x;
        Result.y := y;
      end;
end;


function ArgMulti(const Mat:T2DFloatArray; Count:Int32; HiLo:Boolean): TPointArray; cdecl;
type
  THeapq = specialize HeapQueue<Single>;
var
  W,H,i,y,x,width: Int32;
  heap:THeapq;
begin
  H := High(Mat);
  if (H = -1) then raise Exception.Create('ArgMulti: Empty matrix');
  W := High(Mat[0]);

  Heap := THeapq.Create(HiLo);
  width := w + 1;
  case HiLo of
    True:
     for y:=0 to H do
       for x:=0 to W do
         if (Heap.Size < count) or (mat[y,x] > Heap[0].value) then
         begin
           if (Heap.Size = count) then Heap.Pop();
           Heap.Push(mat[y,x], y*width+x);
         end;
    False:
     for y:=0 to H do
       for x:=0 to W do
         if (Heap.Size < count) or (mat[y,x] < Heap[0].value) then
         begin
           if (Heap.Size = count) then Heap.Pop();
           Heap.Push(mat[y,x], y*width+x);
         end;
  end;

  SetLength(Result, Heap.Size);
  for i:=0 to Heap.Size-1 do begin
    Result[i].y := Heap[i].extra div Width;
    Result[i].x := Heap[i].extra - Result[i].y * Width;
  end;

  Heap.Destroy;
end;




//---| Imaging |-------------------------------------------------------\\
(*
 Counts the number of matches end returns the num of hits in the range 0 to 1.
*)
function imCompareAt(const large,small:T2DIntArray; pt:TPoint; tol:Int32): Single; cdecl;
var
  x,y,w,h,SAD:Int32;
  c1,c2:TRGB32;
begin
  if not(GetMatrixSize(small, W,H)) then Exit();
  SAD := 0;
  for y:=0 to h-1 do
    for x:=0 to w-1 do
    begin
      c1 := TRGB32(large[y+pt.y, x+pt.x]);
      c2 := TRGB32(small[y, x]);
      if (Abs(c1.R-c2.R) < Tol) and
         (Abs(c1.G-c2.G) < Tol) and
         (Abs(c1.B-c2.B) < Tol) then
        Inc(SAD);
    end;
  Result := SAD / (W*H);
end;


(*
 High quality downsampling algorithm.
*)
function imSample(const imgArr:T2DIntArray; scale:Int32): T2DIntArray; cdecl;
type
  TRGBMatrix = Array of Array of TRGB32;
var
  x,y,ys,W,H,nW,nH,sqscale:Int32;
  mat: TRGBMatrix;
  
  function GetAreaColor(const imgArr:TRGBMatrix; px,py,scale,sqscale:Int32): Int32; inline;
  var
    x,y:Int32;
    R:Int32=0; G:Int32=0; B:Int32=0;
  begin
    for y:=py to py+scale-1 do
      for x:=px to px+scale-1 do
      begin
        R += ImgArr[y,x].R;
        G += ImgArr[y,x].G;
        B += ImgArr[y,x].B;
      end;
    R := R div sqscale;
    G := G div sqscale;
    B := B div sqscale;
    Result := B or G shl 8 or R shl 16;
  end;

begin
  if not(GetMatrixHigh(ImgArr, W,H)) then Exit();
  nW := W div Scale;
  nH := H div Scale;
  sqscale := Scale*Scale;
  SetLength(Result, nH,nW);
  mat := TRGBMatrix(ImgArr);
  for y:=0 to nH-1 do
  begin
    ys := y*scale;
    for x:=0 to nW-1 do
      Result[y,x] := GetAreaColor(mat, x*scale, ys, scale, sqscale);
  end;
end;






//-- Image rotatating ------->

(*
 Computes the expanded bounds according to the new angle
*)
function __GetNewSizeRotated(W,H:Int32; Angle:Single): TBox;
  function Rotate(p:TPoint; angle:Single; mx,my:Int32): TPoint;
  begin
    Result.X := Round(mx + cos(angle) * (p.x - mx) - sin(angle) * (p.y - my));
    Result.Y := Round(my + sin(angle) * (p.x - mx) + cos(angle) * (p.y - my));
  end;
var pts: TPointArray;
begin
  SetLength(pts, 4);
  Result := Box($FFFFFF,$FFFFFF,0,0);
  pts[0]:= Rotate(Point(0,h), angle, W div 2, H div 2);
  pts[1]:= Rotate(Point(w,h), angle, W div 2, H div 2);
  pts[2]:= Rotate(Point(w,0), angle, W div 2, H div 2);
  pts[3]:= Rotate(Point(0,0), angle, W div 2, H div 2);
  Result := TPABounds(pts);
end;


(*
 Rotates the bitmap using bilinear interpolation
*)
function __RotateBI(const ImgArr:T2DIntArray; Angle:Single): T2DIntArray;
var
  i,j,R,G,B,mx,my,W,H,fX,fY,cX,cY: Int32;
  rX,rY,dX,dY,cosa,sina:Single;
  p0,p1,p2,p3: TRGB32;
  topR,topG,topB,BtmR,btmG,btmB:Single;
begin
  if not(GetMatrixHigh(ImgArr, W,H)) then Exit();

  SetLength(Result, H, W);
  cosa := Cos(Angle);
  sina := Sin(Angle);
  mX := W div 2;
  mY := H div 2;

  W -= 1;
  H -= 1;
  for i := 0 to H do begin
    for j := 0 to W do begin
      rx := (mx + cosa * (j - mx) - sina * (i - my));
      ry := (my + sina * (j - mx) + cosa * (i - my));

      fX := Trunc(rX);
      fY := Trunc(rY);
      cX := Ceil(rX);
      cY := Ceil(rY);

      if not((fX < 0) or (cX < 0) or (fX > W) or (cX > W) or
             (fY < 0) or (cY < 0) or (fY > H) or (cY > H)) then
      begin
        dx := rX - fX;
        dy := rY - fY;

        p0 := TRGB32(ImgArr[fY, fX]);
        p1 := TRGB32(ImgArr[fY, cX]);
        p2 := TRGB32(ImgArr[cY, fX]);
        p3 := TRGB32(ImgArr[cY, cX]);

        TopR := (1 - dx) * p0.R + dx * p1.R;
        TopG := (1 - dx) * p0.G + dx * p1.G;
        TopB := (1 - dx) * p0.B + dx * p1.B;
        BtmR := (1 - dx) * p2.R + dx * p3.R;
        BtmG := (1 - dx) * p2.G + dx * p3.G;
        BtmB := (1 - dx) * p2.B + dx * p3.B;

        R := Round((1 - dy) * TopR + dy * BtmR);
        G := Round((1 - dy) * TopG + dy * BtmG);
        B := Round((1 - dy) * TopB + dy * BtmB);

        if (R < 0) then R := 0
        else if (R > 255)then R := 255;
        if (G < 0) then G := 0
        else if (G > 255)then G := 255;
        if (B < 0) then B := 0
        else if (B > 255)then B := 255;

        Result[i,j] := B or (G shl 8) or (R shl 16);
      end;
    end;
  end;
end;


(*
 Rotates the bitmap using bilinear interpolation, does expand
*)
function __RotateExpandBI(const ImgArr:T2DIntArray; Angle:Single): T2DIntArray;
var
  i,j,R,G,B,mx,my,W,H,nW,nH,fX,fY,cX,cY: Int32;
  rX,rY,dX,dY,cosa,sina:Single;
  topR,topG,topB,BtmR,btmG,btmB:Single;
  p0,p1,p2,p3: TRGB32;
  NewB:TBox;
begin
  if not(GetMatrixSize(ImgArr, W,H)) then Exit();

  NewB := __GetNewSizeRotated(W,H,Angle);
  nW := NewB.Width;
  nH := NewB.Height;
  mX := nW div 2;
  mY := nH div 2;
  SetLength(Result,nH,nW);
  cosa := Cos(Angle);
  sina := Sin(Angle);
  nW -= 1; nH -= 1;
  for i := 0 to nH do begin
    for j := 0 to nW do begin
      rx := (mx + cosa * (j - mx) - sina * (i - my));
      ry := (my + sina * (j - mx) + cosa * (i - my));

      fX := (Trunc(rX)+ NewB.x1);
      fY := (Trunc(rY)+ NewB.y1);
      cX := (Ceil(rX) + NewB.x1);
      cY := (Ceil(rY) + NewB.y1);

      if not((fX < 0) or (cX < 0) or (fX >= W) or (cX >= W) or
             (fY < 0) or (cY < 0) or (fY >= H) or (cY >= H)) then
      begin
        dx := rX - (fX - NewB.x1);
        dy := rY - (fY - NewB.y1);

        p0 := TRGB32(ImgArr[fY, fX]);
        p1 := TRGB32(ImgArr[fY, cX]);
        p2 := TRGB32(ImgArr[cY, fX]);
        p3 := TRGB32(ImgArr[cY, cX]);

        TopR := (1 - dx) * p0.R + dx * p1.R;
        TopG := (1 - dx) * p0.G + dx * p1.G;
        TopB := (1 - dx) * p0.B + dx * p1.B;
        BtmR := (1 - dx) * p2.R + dx * p3.R;
        BtmG := (1 - dx) * p2.G + dx * p3.G;
        BtmB := (1 - dx) * p2.B + dx * p3.B;

        R := Round((1 - dy) * TopR + dy * BtmR);
        G := Round((1 - dy) * TopG + dy * BtmG);
        B := Round((1 - dy) * TopB + dy * BtmB);

        if (R < 0) then R := 0
        else if (R > 255) then R := 255;
        if (G < 0) then G := 0
        else if (G > 255) then G := 255;
        if (B < 0) then B := 0
        else if (B > 255) then B := 255;

        Result[i,j] := (B or (G shl 8) or (R shl 16));
      end;
    end;
  end;
end;


(*
 Rotates the bitmap using nearest neighbor
*)
function __RotateNN(const Mat:T2DIntArray; Angle:Single): T2DIntArray;
var
  W,H,x,y,mx,my,i,j:Int32;
  cosa,sina:Single;
begin
  if not(GetMatrixHigh(Mat, W,H)) then Exit();
  
  mx := W div 2;
  my := H div 2;
  SetLength(Result, H+1,W+1);
  cosa := cos(angle);
  sina := sin(angle);
  for i:=0 to H do
    for j:=0 to W do
    begin
      x := Round(mx + cosa * (j - mx) - sina * (i - my));
      y := Round(my + sina * (j - mx) + cosa * (i - my));
      if (x >= 0) and (x < W) and (y >= 0) and (y < H) then
        Result[i,j] := Mat[y,x];
    end;
end;


(*
 Rotates the bitmap using nearest neighbor, does expand
*)
function __RotateExpandNN(const Mat:T2DIntArray; Angle:Single): T2DIntArray;
var
  nW,nH,W,H,x,y,mx,my,j,i:Int32;
  NewB:TBox;
  cosa,sina:Single;
begin
  if not(GetMatrixSize(Mat, W,H)) then Exit();

  mx := W div 2;
  my := H div 2;
  NewB := __GetNewSizeRotated(W,H,Angle);
  nW := NewB.Width;
  nH := NewB.Height;
  SetLength(Result, nH,nW);
  cosa := cos(angle);
  sina := sin(angle);

  nw -= 1; nh -= 1;
  for i:=0 to nH do
    for j:=0 to nW do
    begin
      x := Round(mx + cosa * (NewB.x1+j - mx) - sina * (NewB.y1+i - my));
      y := Round(my + sina * (NewB.x1+j - mx) + cosa * (NewB.y1+i - my));
      if (x >= 0) and (x < W) and (y >= 0) and (y < H) then
        Result[i,j] := Mat[y,x];
    end;
end;


function imRotate(const imgArr:T2DIntArray; Angle:Single; Expand:Boolean; Bilinear:Boolean=True): T2DIntArray; cdecl;
begin
  case Expand of
    True:
      case Bilinear of
        True:  Result := __RotateExpandBI(imgArr,Angle);
        False: Result := __RotateExpandNN(imgArr,Angle);
      end;
    False:
      case Bilinear of
        True:  Result := __RotateBI(imgArr,Angle);
        False: Result := __RotateNN(imgArr,Angle);
      end;
  end;
end;


end.
