{==============================================================================]
  Author: Jarl K. Holta
  Project: RSWalker 
  Project URL: https://github.com/WarPie/RSWalker
  License: GNU GPL (http://www.gnu.org/licenses/gpl.html)
[==============================================================================}
var
  W_MAP_OFFSET  := 12;              //memory scanning offset thingys
  W_SIZE_OFFSET := 8;               //...
  
type
  TFeaturePoint = record
    x,y: Int32;
    value: Single;
  end;
  
  TRSPosFinder = record
    ScanRatio: Byte;
    TMFormula: ETMFormula;
    Similarity: Single;   //from last correlation
    
    //mem-stuff
    process:Int32;
    scan: {$IFDECL TMemScan}TMemScan{$ELSE}Pointer{$ENDIF};
    addr: PtrUInt;
    bufferW, bufferH: Int32;
    localMap: T2DIntArray;
  end;


//---| TRSPosFinder |-----------------------------------------------------------------------\\
procedure TRSPosFinder.Init(PID:Int32);
var
  errno:UInt32;
  procedure CheckError(errno:UInt32);
  begin
    {$IFDECL TMEMSCAN}
    case errno of
      $0:  Exit;
      $5:  RaiseException(Format('TMemScan.Init -> PID `%d` does not exist (Access is denied)', [errno]));
      else RaiseException(Format('TMemScan.Init -> `%s`', [GetLastErrorAsString(errno)]));
    end;
    {$ENDIF}
  end;
begin
  with Self do
  begin
    scanRatio  := 8; //overwritten by TRSWalker
    process    := PID;
    {$IFDECL TMEMSCAN}
    if PID > 0 then CheckError(scan.Init(process));
    {$ENDIF}
    addr    := $0;
    bufferW := 512;
    bufferH := 512;
  end;
end;


procedure TRSPosFinder.Free();
begin
  with self do
  begin
    {$IFDECL TMEMSCAN}scan.Free();{$ENDIF}
    addr := 0;
    SetLength(localMap,0);
  end;
end;

// ---------------------------------------------------------------------------------
// Memory scanning related methods:

{$IFDECL TMEMSCAN}
function TRSPosFinder.ValidMapAddr(address:PtrUInt): Boolean;
var data:Int32;
begin
  data := BytesToInt( self.scan.CopyMem(address+W_SIZE_OFFSET,4,False));
  if (data = self.bufferW * self.bufferH) then
  begin
    data := BytesToInt(self.scan.CopyMem(address+W_MAP_OFFSET,4,False));
    Result := data = 0;
  end;
end;

function TRSPosFinder.MustUpdateAddr(): Boolean;
begin
  Result := (self.addr = 0) or (not self.ValidMapAddr(self.addr));
end;

//updates the address of the minimap-buffer
procedure TRSPosFinder.UpdateAddr();
var
  matches: array of PtrUInt;
  TIA: array of Int32;
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
    c := GetTickCount();
    repeat
      t := GetTickCount();
      self.UpdateAddr();
      t := GetTickCount() - t;
      if self.ValidMapAddr(self.addr) then
        break;
      Wait(t div 2);
      
      if GetTickCount() - c > 60000 then
        RaiseException(erException, 'TRSPosFinder.UpdateMap: Unable to locate a valid address');
    until False;
  end;
  
  self.LocalMap := GetMemBufferImage(self.scan, self.addr+W_MAP_OFFSET, self.bufferW, self.bufferH);
end;

function TRSPosFinder.GetLocalImage(): TMufasaBitmap;
begin
  if Self.MustUpdateAddr then Self.UpdateMap(True);
  Result.Init(client.GetMBitmaps);
  Result.DrawMatrix(self.LocalMap);
end;

{$ELSE}

function TRSPosFinder.MustUpdateAddr(): Boolean;
begin
  RaiseException(erException, 'Memscan not avaialble on your platform');
end;

procedure TRSPosFinder.UpdateMap(rescan:Boolean=False);
begin
  RaiseException(erException, 'Memscan not avaialble on your platform');
end;

{$ENDIF}



// ---------------------------------------------------------------------------------
// Positioning related methods:

// Cross correlation without any resizing around an area.
function TRSPosFinder.XCorrPeakNear(p:TPoint; Large, Sub:T2DIntArray; Area:Int32): TPoint;
var
  W,H: Int32;
  mat: T2DIntArray;
  B: TBox;
begin
  H := High(Large);
  W := High(Large[0]);
  if (H < Length(Sub)) or (W < Length(Sub[0])) then
    RaiseException(erException, 'TRSPosFinder.FindPeakAround: `large` bitmap is smaller than `sub`');
  
  B := [p.x, p.y, p.x + Length(Sub[0]), p.y + Length(Sub)];
  B := [B.x1-Area, B.y1-Area, B.x2+Area, B.y2+Area];
  B := [max(0,B.x1),max(0,B.y1),min(W,B.x2),min(H,B.y2)];
  mat := Large.Crop(B);
            
  Result := MatchTemplate(mat, Sub, Self.TMFormula).ArgMax();
  Result := [Result.x-Area+p.x, Result.y-Area+p.y];
end;

function TRSPosFinder.GetLocalPos(): TPoint;
var
  minimap, tmpLocal, tmpMMap: T2DIntArray;
  match: T2DRealArray;
  best: TFeaturePoint;
  //bmp: TMufasaBitmap;
begin
  Self.UpdateMap(Self.MustUpdateAddr());
  Minimap  := RSWUtils.GetMinimap(False, False, self.ScanRatio);
  tmpMMap  := Minimap.DownscaleImage(Self.ScanRatio);
  tmpLocal := LocalMap.DownscaleImage(Self.ScanRatio);

  //bmp.Init(client.GetMBitmaps);
  //bmp.DrawMatrix(tmpMMap);
  //bmp.ResizeEx(RM_Nearest, Length(Minimap[0]), Length(Minimap));
  //bmp.Debug();
  //bmp.Free();
  
  match := MatchTemplate(tmpLocal, tmpMmap, Self.TMFormula);
  with match.ArgMax() do
  begin
    best.Value := match[Y,X];
    best.X := X * self.ScanRatio;
    best.Y := Y * self.ScanRatio;
  end;

  Result := XCorrPeakNear([best.x, best.y], LocalMap, Minimap, 20);
  Result.X += Length(minimap[0]) div 2;
  Result.Y += Length(minimap   ) div 2;

  Self.Similarity := best.Value;
end;


procedure TRSPosFinder.DebugPos(p:TPoint; text:String='');
var
  TPA: TPointArray;
  BMP: TMufasaBitmap;
  W,H,_: Int32;
begin
  BMP.Init(client.GetMBitmaps);
  BMP.DrawMatrix(self.LocalMap);
  GetBitmapSize(BMP.GetIndex, W,H);
  if not(PointInBox(p, [2,2,W-3,H-3])) then Exit();

  BMP.DrawTPA(TPAFromLine(0,p.y,W-1,p.y), $00FF00);
  BMP.DrawTPA(TPAFromLine(p.x,0,p.x,H-1), $00FF00);
  BMP.DrawBox(Box(p,2,2), False, $FFFFFF);

  if text then
  try
    TPA := TPAFromText(text,'SmallChars07',_,_);
    OffsetTPA(TPA,Point(10,10));
    BMP.DrawTPA(TPA, $00FF00);
  except
    //nothing;
  end;
  
  BMP.Debug();
  BMP.Free();
end;
