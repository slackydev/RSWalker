{=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=]
 Copyright (c) 2013, Jarl K. <Slacky> Holta || http://github.com/WarPie
 All rights reserved.
[=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=}
{$loadlib ../Includes/OSRWalker/libWalker.dll}
{$I matchTempl.pas}
{$I MemScan.pas}

{$ifdecl srl}{$ifdecl mouse}
  {$DEFINE SRL_MOUSE}
{$endif}{$endif}


const
  WMM_OUTER:TBox = [570,9,714,159];
  WMM_INNER:TBox = [25,26,119,120];
  WMM_CX:Int32   = 643;
  WMM_CY:Int32   = 83;
  WMM_OFFSET:TPoint = [1,1];


type
  TFeaturePoint = record
    x,y:Int32;
    value:Single;
    angle:Int32;
  end;
  TFeatPointArray = Array of TFeaturePoint;   
  T2DFeatPointArray = Array of TFeatPointArray;
  
  TRSPosFinder = record
    matchAlgo: Byte;
    scanRatio: Byte;
    numSamples:Int32;
    
    //from last correlation
    mmOffset: Int32;
    topMatch: Single;
    
    //mem-stuff
    process:Int32;
    scan:TMemScan;
    addr:PtrUInt;
    bufferW, bufferH:Int32;
    localMap: T2DIntArray;
  end;


function w_GetClientPID(): UInt32;
var
  H:PtrUInt;
begin
  H := Client.GetIOManager().GetKeyMouseTarget().GetHandle();
  Result := GetWindowProcessID(H);
end;

procedure w_clickMouse(box:TBox; btn:Int32);
begin
  {$IFDEF SRL_MOUSE}
    mouse.click(box, btn);
  {$ELSE}
    {$IFDEF AEROLIB}
      MouseBox(box, btn);
    {$ELSE}
      RaiseException('Not implmented yet');
    {$ENDIF}
  {$ENDIF}
end;


function w_Distance(A,B: TPoint): Double; overload;
begin
  Result := Distance(A.X,A.Y, B.X,B.Y);
end;


function w_GetCompassAngle(AsDegrees:Boolean=True): Extended;
var
  north,south: TPoint;
  M:TPoint := [561, 20];
  TPA:TPointArray;
begin
  if not FindColorsTolerance(TPA, 1911089, 545,4,576,36, 20) then Exit(0);
  FilterPointsDist(TPA, 8,15, M.x,M.y);
  north := MiddleTPA(SplitTPA(TPA,3)[0]);
  south := RotatePoint(north,PI, M.x,M.y);
  if not FindColorsTolerance(TPA, 920735, 545,4,576,36, 20) then Exit(0);
  FilterPointsDist(TPA, 0,6, south.x,south.y);
  SortTPAFrom(TPA,M);
  Result := FixRad(ArcTan2(TPA[high(tpa)].y-M.y, TPA[high(tpa)].x-M.x) - (PI/2));
  if AsDegrees then
    Result := Degrees(Result);
end;


function w_FlagPresent(searchTime:Int32=500): Boolean;
var
  TPA: TPointArray;
  ATPA: T2DPointArray;
  i: Int32;
  B:TBox := [570,9,714,159];
  t:UInt32;
begin
  Result := False;
  t := GetTimeRunning() + searchTime;
  while GetTimeRunning() < t do
    if findColorsTolerance(TPA, 255, B.x1,B.y1,B.x2,B.y2, 1) then
    begin
      ATPA := SplitTPA(TPA,1);
      for i := 0 to High(ATPA) do
        if (Length(ATPA[i]) >= 10) AND (Length(ATPA[i]) <= 50) then
          Exit(True);
    end;
end;


function w_RunEnergy(): Integer;
var
  cts := GetToleranceSpeed();
  text:String;
begin
  SetColorToleranceSpeed(2);
  SetToleranceSpeed2Modifiers(1,0.0); //only hue changes, from 0 to 34
  text := GetTextAtEx(547,137,565,147, 0,4, 1, 255,34, 'StatChars07');
  SetColorToleranceSpeed(cts);
  SetToleranceSpeed2Modifiers(0.2,0.2);
  Result := StrToIntDef(text, 0);
end; 


procedure w_QuickEnableRun(minEnergy:Int32);
var
  B:TBox = [570,128,590,149];
begin
  if CountColorTolerance(6806252,B.x1,B.y1,B.x2,B.y2,30) > 25 then 
    Exit();
  
  if w_RunEnergy() >= minEnergy then
    w_ClickMouse(B, mouse_Left);
end;


{*Credit JuKKa*}
function w_WindPath(Xs, Ys, Xe, Ye, Gravity, Wind, MinWait,
  MaxWait, MaxStep, TargetArea: Extended): TPointArray;
var
  VeloX, VeloY, WindX, WindY, VeloMag, Dist, RandomDist, LastDist: Extended;
  Step, Sqrt2, Sqrt3, Sqrt5: Extended;
  LastX, LastY: Integer;
begin
  Sqrt2:= Sqrt(2);
  Sqrt3:= Sqrt(3);
  Sqrt5:= Sqrt(5);
  while Hypot(Xs - Xe, Ys - Ye) > 1 do
  begin
    Dist:= hypot(Xs - Xe, Ys - Ye);
    Wind:= MinE(Wind, Dist);
    if Dist >= TargetArea then
    begin
      WindX:= WindX / Sqrt3 + (Random(Round(Wind) * 2 + 1) - Wind) / Sqrt5;
      WindY:= WindY / Sqrt3 + (Random(Round(Wind) * 2 + 1) - Wind) / Sqrt5;
    end else
    begin
      WindX:= WindX / Sqrt2;
      WindY:= WindY / Sqrt2;
      if (MaxStep < 3) then
        MaxStep:= random(3) + 3.0
      else
        MaxStep:= MaxStep / Sqrt5;
    end;
    VeloX:= VeloX + WindX;
    VeloY:= VeloY + WindY;
    VeloX:= VeloX + Gravity * (Xe - Xs) / Dist;
    VeloY:= VeloY + Gravity * (Ye - Ys) / Dist;
    if Hypot(VeloX, VeloY) > MaxStep then
    begin
      RandomDist:= MaxStep / 2.0 + random(0, (round(MaxStep) div 2));
      VeloMag:= sqrt(VeloX * VeloX + VeloY * VeloY);
      VeloX:= (VeloX / VeloMag) * RandomDist;
      VeloY:= (VeloY / VeloMag) * RandomDist;
    end;
    LastX:= Round(Xs);
    LastY:= Round(Ys);
    Xs:= Xs + VeloX;
    Ys:= Ys + VeloY;
    SetArrayLength(Result, GetArrayLength(Result) + 1);
    Result[High(Result)] := Point(Round(Xs), Round(Ys));
    Step:= Hypot(Xs - LastX, Ys - LastY);
    LastDist:= Dist;
  end;
end;


//---| TRSPosFinder |-----------------------------------------------------------------------\\
procedure TRSPosFinder.Init(PID:Int32);
begin
  with Self do
  begin
    matchAlgo := TM_CCOEFF_NORMED;
    scanRatio := 8;
    numSamples := 100;
    process := PID;
    
    if PID >= 0 then scan.Init(process);
    addr := 0;
    bufferW := 512;
    bufferH := 512;
  end;
end;


procedure TRSPosFinder.Free();
begin
  with self do
  begin
    scan.Free();
    addr := 0;
    setLength(localMap,0);
  end;
end;


function TRSPosFinder.FastMatchTemplate(large,sub:T2DIntArray; scanID:Int32): TFeatPointArray;
var
  i:Int32;
  mat:T2DFloatArray;
  TPA:TPointArray;
  Acc:Array of Single;
begin
  mat := w_MatchTemplate(large,sub, self.matchAlgo);
  tpa := w_ArgMulti(mat, self.numSamples, True);
  acc := w_GetValues(mat, TPA);
  SetLength(Result, Length(TPA));
  for i:=0 to High(tpa) do
    Result[i] := [tpa[i].x*self.scanRatio, tpa[i].y*self.scanRatio, acc[i], scanid];
end;


function TRSPosFinder.FindPeakAround(large, sub:T2DIntArray; p:TPoint; area:Int32): TPoint;
var
  W,H:Int32;
  mat:T2DIntArray;
  corr:T2DFloatArray;
  B:TBox;
begin
  H := High(large);
  W := High(large[0]);
  if (H < length(sub)) or (W < length(sub[0])) then
    RaiseException('Meh.. Time to error');

  B := [p.x, p.y, p.x + length(sub[0]), p.y + length(sub)];
  B := [B.x1-area, B.y1-area, B.x2+area, B.y2+area];
  B := [max(0,B.x1),max(0,B.y1),min(W,B.x2),min(H,B.y2)];
  mat := w_GetArea(large, b.x1,b.y1,b.x2,b.y2);

  corr   := w_MatchTemplate(mat, sub, self.matchAlgo);
  Result := w_ArgMax(corr);
  Result := [Result.x-area+p.x, result.y-area+p.y];
end;


function TRSPosFinder.Correlate(sub,large:T2DIntArray; offset:Double=0): T2DFeatPointArray;
var 
  angle:Int32;
  test:T2DIntArray;
begin
  for angle:=-20 to 20 with 2 do
  begin
    test := w_imRotate(sub, radians(angle)+offset, False,False);
    test := w_GetArea(test, WMM_INNER.x1,WMM_INNER.y1,WMM_INNER.x2,WMM_INNER.y2);
    test := w_imSample(test, self.scanRatio);
    SetLength(Result, length(Result)+1);
    Result[high(Result)] := Self.FastMatchTemplate(large, test, angle);
  end;
end;


function TRSPosFinder.FindPeak(arr:T2DFeatPointArray): TFeaturePoint;
var
  i,j:Int32;
  top:Single;
begin
  result.value := arr[0][0].value;
  for i:=0 to High(arr) do
    for j:=0 to High(arr[i]) do
      if arr[i][j].value > result.value then
        result := arr[i][j];
end;


function TRSPosFinder.MustUpdateAddr(): Boolean;
var
  colors:TIntegerArray;
  i:Int32;
const
  boxes:TBoxArray = [
    [20,20,490,490],
    [10,10,500,500],
    [0, 0, 511,511]
  ];
begin
  if length(localMap) <> self.bufferH then
    Exit(True);

  for i:=0 to High(Boxes) do
  begin
    colors := w_GetValues(localMap, EdgeFromBox(boxes[i]));
    if (MinA(colors) <> 0) or (MaxA(colors) <> 0) then
      Exit(True);
  end;
end;

procedure TRSPosFinder.UpdateAddr();
var
  matches:TPtrIntArray;
  tmp:PtrUInt;
  size,i,k:Int32;
begin
  size := self.bufferW*self.bufferH;
  matches := self.scan.FindByteArray([0,2,0,0,0,2,0,0,0,0,0,0,0,2,0,0,0,2,0,0], 4); //meh..
  for i:=0 to High(Matches) do
  begin
    tmp := BytesToInt( self.scan.CopyMem(matches[i]+20,4) );
    k := BytesToInt( self.scan.CopyMem(tmp+8,4) );
    if ( k = size ) then
    begin
      self.addr := tmp+12;
      Exit;
    end;
  end;
  
  //now why da fuq did the above fail? Reverting to old method:
  self.addr := FindMemBufferImage(self.scan, self.bufferW, self.bufferH);
end;


procedure TRSPosFinder.UpdateMap(rescan:Boolean=False);
begin
  if rescan then
  begin
    self.UpdateAddr();
    //check again.. temporary solution.
    if self.MustUpdateAddr() then
      self.UpdateAddr();
  end;
  
  self.localMap := GetMemBufferImage(self.scan, self.addr, self.bufferW, self.bufferH);
end;


(*

*)
function TRSPosFinder.GetLocalPos(anyAngle:Boolean=False): TPoint;
var
  feat: T2DFeatPointArray;
  BMP: Integer;
  MM,test,world: T2DIntArray;
  best:TFeaturePoint;
  compRad:Double = 0;
begin
  self.UpdateMap(self.MustUpdateAddr());
  world := w_imSample(localMap, self.scanRatio);
  if anyAngle then
    compRad := w_GetCompassAngle(False);

  BMP := BitmapFromClient(WMM_OUTER.x1,WMM_OUTER.y1,WMM_OUTER.x2,WMM_OUTER.y2);
  MM := BitmapToMatrix(BMP);
  FreeBitmap(BMP);

  feat := self.Correlate(MM, world, compRad);
  best := self.FindPeak(feat);

  test := w_imRotate(MM, radians(best.angle) + compRad, False,True);
  test := w_GetArea(test, WMM_INNER.x1,WMM_INNER.y1,WMM_INNER.x2,WMM_INNER.y2);
  Result := findPeakAround(
    self.localMap,
    test,
    Point(best.x,best.y),
    20
  );

  Result.x += ((WMM_INNER.x2-WMM_INNER.x1+1) div 2) + WMM_OFFSET.x;
  Result.y += ((WMM_INNER.y2-WMM_INNER.y1+1) div 2) + WMM_OFFSET.y;
  
  Self.topMatch := best.value;
  Self.mmOffset := best.angle;
end;


procedure TRSPosFinder.DebugPos(p:TPoint; text:String='');
var
  TPA:TPointArray;
  BMP:Integer;
  W,H,_:Int32;
begin
  BMP := CreateBitmap(0,0);
  DrawMatrixBitmap(BMP,self.localMap);
  GetBitmapSize(BMP,W,H);
  if not(PointInBox(p, [0,0,W-1,H-1])) then Exit();
  
  DrawTPABitmap(BMP, TPAFromLine(0,p.y,W-1,p.y), $00FF00);
  DrawTPABitmap(BMP, TPAFromLine(p.x,0,p.x,H-1), $00FF00);

  if text then
  begin
    TPA := TPAFromText(text,'SmallChars07',_,_);
    OffsetTPA(TPA,Point(10,10));
    DrawTPABitmap(BMP, TPA, $00FF00);
  end;
  
  DisplayDebugImgWindow(W,H);
  DrawBitmapDebugImg(BMP);
  FreeBitmap(BMP);
end;
