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
  addType('TPtrInfo','packed record addr: PtrUInt; raw: TByteArray; end;');
  addType('TPtrInfoArray','array of TPtrInfo;');
  addType('TPtrIntArray','array of PtrUInt;');
  addType('TMemScan','packed record Proc: PtrUInt; SysMemLo: PtrUInt; SysMemHi: PtrUInt; end;');

  addMethod('function GetWindowProcessID(hwnd:UInt32): UInt32;', @GetWindowProcessID);
  addMethod('function GetLastErrorAsString(out errno:UInt32): String;', @GetLastErrorAsString);

  addMethod('function TMemScan.Init(pid:UInt32): Int32;', @TMemScan_Init);
  addMethod('procedure TMemScan.Free();', @TMemScan_Free);
  addMethod('function TMemScan.Search(targetData:Pointer; targetSize:Int32; alignment:Int8=1): TPtrIntArray;', @TMemScan_Search);
  addMethod('function TMemScan.SearchRaw(constref data; itemSize:SizeInt; alignment:Int8=1): TPtrIntArray;', @TMemScan_SearchRaw);
  addMethod('function TMemScan.MagicFunctionToFindTheMapBuffer(contents:TIntegerArray; instSize:Int32): TPtrIntArray;', @TMemScan_FindInstanceI32);
  addMethod('function TMemScan.CopyMem(addr:PtrUInt; bytesToRead:Int32; unsafe:LongBool=True): TByteArray;', @TMemScan_CopyMem);
  
  addMethod('function TMemScan.FindInt8(data:UInt8; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindInt8);
  addMethod('function TMemScan.FindInt16(data:UInt16; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindInt16);
  addMethod('function TMemScan.FindInt32(data:UInt32; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindInt32);
  addMethod('function TMemScan.FindInt64(data:UInt64; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindInt64);
  addMethod('function TMemScan.FindFloat(data:Single; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindFloat);
  addMethod('function TMemScan.FindDouble(data:Double; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindDouble);
  addMethod('function TMemScan.FindString(data:AnsiString; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindString);
  addMethod('function TMemScan.FindWideString(data:WideString; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindWideString);
  addMethod('function TMemScan.FindByteArray(data:TByteArray; alignment:Int8=1): TPtrIntArray;', @TMemScan_FindByteArray);

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


{=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=]
 Export our functions, name, information etc...
 All that is needed for scar to see this as a DLL.
[=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=}
function GetPluginABIVersion: Integer; cdecl; export;
begin
  Result := 2;
end;

procedure SetPluginMemManager(MemMgr : TMemoryManager); cdecl; export;
begin
  if memisset then
    exit;
  GetMemoryManager(OldMemoryManager);
  SetMemoryManager(MemMgr);
  memisset := True;
end;


procedure OnDetach; cdecl; export;
begin
  SetMemoryManager(OldMemoryManager);
end;


function GetFunctionCount: Integer; cdecl; export;
begin
  if not MethodsLoaded then LoadExports;
  Result := Length(Methods);
end;

function GetFunctionInfo(x: Integer; var ProcAddr: Pointer; var ProcDef: PChar): Integer; cdecl; export;
begin
  Result := x;
  if (x > -1) and InRange(x, 0, High(Methods)) then
  begin
    ProcAddr := Methods[x].procAddr;
    StrPCopy(ProcDef, Methods[x].ProcDef);
    if (x = High(Methods)) then FreeMethods;
  end;
end;



function GetTypeCount: Integer; cdecl; export;
begin
  if not TypesLoaded then LoadExports;
  Result := Length(TypeDefs);
end;

function GetTypeInfo(x: Integer; var TypeName, TypeDef: PChar): integer; cdecl; export;
begin
  Result := x;
  if (x > -1) and InRange(x, 0, High(TypeDefs)) then
  begin
    StrPCopy(TypeName, TypeDefs[x].TypeName);
    StrPCopy(TypeDef,  TypeDefs[x].TypeDef);
    if (x = High(TypeDefs)) then FreeTypes;
  end;
end;


exports GetPluginABIVersion;
exports SetPluginMemManager;
exports GetTypeCount;
exports GetTypeInfo;
exports GetFunctionCount;
exports GetFunctionInfo;
exports OnDetach;
