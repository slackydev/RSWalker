{=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=]
 Copyright (c) 2014, Jarl K. <Slacky> Holta || http://github.com/WarPie
 All rights reserved.
[=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=}
var
  Methods: array of record procAddr: Pointer; ProcDef:PChar; end;
  TypeDefs: array of record TypeName, TypeDef:PChar; end;
  TypesLoaded: Boolean = False;
  MethodsLoaded: Boolean = False;
  
  OldMemoryManager: TMemoryManager;
  MemIsset: Boolean = False;


procedure AddMethod(ProcDef: PChar; ProcAddr: Pointer);
var L: Integer;
begin
  L := Length(Methods);
  SetLength(Methods, L + 1);
  Methods[l].ProcAddr := ProcAddr;
  Methods[l].ProcDef := ProcDef;
end;

procedure AddType(TypeName, TypeDef: PChar);
var L: Integer;
begin
  L := Length(TypeDefs);
  SetLength(TypeDefs, L + 1);
  TypeDefs[l].TypeName := TypeName;
  TypeDefs[l].TypeDef := TypeDef;
end;

procedure LoadExports;
begin
  addType('TFloatArray', 'Array of Single;');
  addType('T2DFloatArray','Array of TFloatArray;');

  addType('TPtrInfo','packed record addr: PtrUInt; raw: TByteArray; end;');
  addType('TPtrInfoArray','Array of TPtrInfo;');
  addType('TPtrIntArray','Array of PtrUInt;');
  addType('TMemScan','packed record Proc: PtrUInt; SysMemLo: PtrUInt; SysMemHi: PtrUInt; end;');

  addMethod('function GetWindowProcessID(hwnd:UInt32): UInt32;', @GetWindowProcessID);
  addMethod('function TMemScan.Init(pid:UInt32): Boolean;', @TMemScan_Init);
  addMethod('procedure TMemScan.Free();', @TMemScan_Free);
  addMethod('function TMemScan.Search(targetData:Pointer; targetSize:Int32; alignment:Int8=1): TPtrIntArray;', @TMemScan_Search);
  addMethod('function TMemScan.GetMemRange(low,high:PtrUInt; dataSize:Int32; alignment:Int8=1): TPtrInfoArray;', @TMemScan_GetMemRange);
  addMethod('function TMemScan.SearchBoolMask(maskData:Pointer; maskSize:Int32; alignment:Int8=1): TPtrIntArray;', @TMemScan_SearchBoolMask);
  addMethod('function TMemScan.CopyMem(addr:PtrUInt; bytesToRead:Int32): TByteArray;', @TMemScan_CopyMem);
  addMethod('function TMemScan.FindInt8(data:UInt8; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindInt8);
  addMethod('function TMemScan.FindInt16(data:UInt16; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindInt16);
  addMethod('function TMemScan.FindInt32(data:UInt32; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindInt32);
  addMethod('function TMemScan.FindInt64(data:UInt64; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindInt64);
  addMethod('function TMemScan.FindFloat(data:Single; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindFloat);
  addMethod('function TMemScan.FindDouble(data:Double; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindDouble);
  addMethod('function TMemScan.FindString(data:AnsiString; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindString);
  addMethod('function TMemScan.FindWideString(data:WideString; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindWideString);
  addMethod('function TMemScan.FindByteArray(data:TByteArray; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindByteArray);
  
  addMethod('function w_GetValues(const Mat:T2DIntArray; const Indices:TPointArray): TIntegerArray;', @GetValues);
  addMethod('function w_GetValues(const Mat:T2DFloatArray; const Indices:TPointArray): TFloatArray; overload;', @GetValuesF);
  addMethod('function w_GetArea(const Mat:T2DIntArray; x1,y1,x2,y2:Int32): T2DIntArray;', @GetArea);
  addMethod('function w_ArgMax(const Mat:T2DFloatArray): TPoint;', @ArgMax);
  addMethod('function w_ArgMulti(const Mat:T2DFloatArray; Count:Int32; HiLo:Boolean): TPointArray;', @ArgMulti);

  addMethod('function w_imCompareAt(const large,small:T2DIntArray; pt:TPoint; tol:Int32): Single;', @imCompareAt);
  addMethod('function w_imSample(const imgArr:T2DIntArray; Scale:Int32): T2DIntArray;', @imSample);
  addMethod('function w_imRotate(const imgArr:T2DIntArray; Angle:Single; Expand:Boolean; Bilinear:Boolean=True): T2DIntArray;', @imRotate);

  MethodsLoaded := True;
  TypesLoaded := True;
end;

procedure FreeMethods;
begin
  SetLength(Methods, 0);
  MethodsLoaded := False;
end;


procedure FreeTypes;
begin
  SetLength(TypeDefs, 0);
  TypesLoaded := False;
end;
