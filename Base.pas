{==============================================================================]
  Author: Jarl K. Holta
  Project: RSWalker 
  Project URL: https://github.com/WarPie/RSWalker
  License: GNU GPL (http://www.gnu.org/licenses/gpl.html)
[==============================================================================}
{$loadlib ../Includes/RSWalker/libWalker.dll}
{$include_once MatchTempl.pas}
{$include_once MemScan.pas}

{$ifdecl srl}{$ifdecl mouse}
  {$DEFINE SRL_MOUSE}
{$endif}{$endif}

{$IFNDEF CODEINSIGHT}
var
  WMM_OUTER:TBox = [570,9,714,159];
  WMM_INNER:TBox = [25,26,119,120];
  WMM_RAD:Int32  = 66;               //(safe) Radius of the minimap
  WMM_CX:Int32   = 643;              //minimap center X
  WMM_CY:Int32   = 83;               //minimap center Y    

  W_MAP_OFFSET = 12;                 //memory scanning offset thingys
  W_SIZE_OFFSET = 8;                 //...
{$ENDIF}
  
type
  TFeaturePoint = record
    x,y:Int32;
    value:Single;
    angle:Int32;
  end;
  TFeatPointArray = Array of TFeaturePoint;   
  T2DFeatPointArray = Array of TFeatPointArray;
  
  TRSPosFinder = record
    matchAlgo: cvCrossCorrAlgo;
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

procedure w_ClickMouse(box:TBox; btn:Int32);
begin
  {$IFDEF SRL_MOUSE}
    Mouse.Click(box, btn);
  {$ELSE}
    {$IFDEF AEROLIB}
      MouseBox(box, btn);
    {$ELSE}
      RaiseException('Not implemented yet');
    {$ENDIF}
  {$ENDIF}
end;


function w_Distance(A,B: TPoint): Double;
begin
  Result := Sqrt(Sqr(A.X-B.X) + Sqr(A.Y-B.Y));
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
  t:Int64;
begin
  Result := False;
  t := GetTickCount64() + searchTime;
  while GetTickCount64() < t do
    if FindColorsTolerance(TPA, 255, B.x1,B.y1,B.x2,B.y2, 1) then
    begin
      ATPA := SplitTPA(TPA,1);
      for i:=0 to High(ATPA) do
        if (Length(ATPA[i]) >= 10) and (Length(ATPA[i]) <= 50) then
          Exit(True);
    end;
end;


function w_RunEnergy(): Integer;
var
  cts := GetToleranceSpeed();
  hmod,smod:Extended;
  text:String;
begin
  GetToleranceSpeed2Modifiers(hmod,smod);
  SetColorToleranceSpeed(2);
  SetToleranceSpeed2Modifiers(1,0.0); //only hue changes, from 0 to 34
  text := GetTextAtEx(547,137,565,147, 0,4, 1, 255,34, 'StatChars07');
  SetColorToleranceSpeed(cts);
  SetToleranceSpeed2Modifiers(hmod,smod);
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


//---| TRSPosFinder |-----------------------------------------------------------------------\\
procedure TRSPosFinder.Init(PID:Int32);
var
  errno:UInt32;
  procedure CheckError(errno:UInt32);
  begin
    if errno = 0 then
      Exit()
    else if errno = $5 then
      RaiseException(
        Format('TMemScan.Init -> PID `%d` does not exist (Access is denied)', [errno])
      )
    else
      RaiseException(
        Format('TMemScan.Init -> `%s`', [GetLastErrorAsString(errno)])
      );
  end;

begin
  with Self do
  begin
    matchAlgo := CV_TM_CCOEFF_NORMED;
    scanRatio := 8;
    numSamples := 100;
    process := PID;
    
    if PID > 0 then CheckError(scan.Init(process));
    
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


function TRSPosFinder.GetMMAngle(): Double;
begin
  self.GetLocalPos(True); //updates the "minimap to compass"-offset
  Result := FixD(w_GetCompassAngle() - self.mmOffset) ;
end;


function TRSPosFinder.ValidMapAddr(address:PtrUInt): Boolean;
var data:Int32;
begin
  data := BytesToInt( self.scan.CopyMem(address+W_SIZE_OFFSET,4,False) );
  Result := (data = self.bufferW * self.bufferH)
end;


function TRSPosFinder.MustUpdateAddr(): Boolean;
begin
  Result := not self.ValidMapAddr(self.addr);
end;

//updates the address of the minimap-buffer
procedure TRSPosFinder.UpdateAddr();
var
  matches: Array of PtrUInt;
  TIA: Array of Int32;
  i,j: Int32;
begin
  matches := scan.MagicFunctionToFindTheMapBuffer([512,512,512,512],36);
  for i:=0 to High(matches) do
  begin
    TIA := BytesToTIA( scan.CopyMem(matches[i],48) );
    if InIntArray(TIA,0) then
      for j:=0 to High(TIA) do
        if self.ValidMapAddr(TIA[j]) then
        begin
          self.addr := TIA[j];
          Exit;
        end;
  end;
  RaiseException(erException, 'TRSPosFinder.UpdateAddr: Unable to locate bitmap');
end;


procedure TRSPosFinder.UpdateMap(rescan:Boolean=False);
var t,c:Int64;
begin
  if rescan then
  begin
    c := GetTickCount64();
    repeat
      t := GetTickCount64();
      self.UpdateAddr();
      t := GetTickCount64() - t;
      if self.ValidMapAddr(self.addr) then
        break;
      Wait(t div 2);
      
      if GetTickCount64() - c > 50000 then
        RaiseException(erException, 'TRSPosFinder.UpdateMap: Unable to locate a valid address');
    until False;
  end;
  
  self.localMap := GetMemBufferImage(self.scan, self.addr+W_MAP_OFFSET, self.bufferW, self.bufferH);
end;


function TRSPosFinder.FastMatchTemplate(large,sub:T2DIntArray; scanID:Int32): TFeatPointArray;
var
  i:Int32;
  mat:T2DFloatArray;
  TPA:TPointArray;
  Acc:Array of Single;
begin
  mat := libCV.MatchTemplate(large,sub, self.matchAlgo);
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
    RaiseException(erException, 'TRSPosFinder.FindPeakAround: `large` bitmap is smaller than `sub`');

  B := [p.x, p.y, p.x + length(sub[0]), p.y + length(sub)];
  B := [B.x1-area, B.y1-area, B.x2+area, B.y2+area];
  B := [max(0,B.x1),max(0,B.y1),min(W,B.x2),min(H,B.y2)];
  mat := w_GetArea(large, b.x1,b.y1,b.x2,b.y2);

  corr   := libCV.MatchTemplate(mat, sub, self.matchAlgo);
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

  Result.x += ((WMM_INNER.x2-WMM_INNER.x1+1) div 2) + 1;
  Result.y += ((WMM_INNER.y2-WMM_INNER.y1+1) div 2) + 1;
  
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
  try
    TPA := TPAFromText(text,'SmallChars07',_,_);
    OffsetTPA(TPA,Point(10,10));
    DrawTPABitmap(BMP, TPA, $00FF00);
  except
    //nothing;
  end;
  
  DisplayDebugImgWindow(W,H);
  DrawBitmapDebugImg(BMP);
  FreeBitmap(BMP);
end;
