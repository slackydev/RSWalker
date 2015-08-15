unit MemScan;
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
  SysUtils,
  Classes,
  Windows;

type
  PUInt32 = ^UInt32;
  TIntArray = Array of Int32;
  TByteArray = Array of Byte;

  TPtrInfo = packed record
    addr: PtrUInt;
    raw: TByteArray;
  end;
  TPtrInfoArray = Array of TPtrInfo;
  TPtrIntArray = Array of PtrUInt;

  PMemScan = ^TMemScan;
  TMemScan = packed record
    Proc: HANDLE;
    SysMemLo: PtrUInt;
    SysMemHi: PtrUInt;

    function Init(pid:UInt32): Boolean;
    procedure Free();

    function CopyMem(addr:Pointer; bytesToRead:Int32; unsafe:Boolean): TByteArray;
    function Search(targetData:Pointer; targetSize:Int32; Alignment:Int8): TPtrIntArray;
    function FindInstanceI32(contents:TIntArray; instSize:Int32): TPtrIntArray;
  end;


function GetWindowProcessID(window:HWND): UInt32; cdecl;

function TMemScan_Init(var scan:TMemScan; pid:UInt32): Boolean; cdecl;
procedure TMemScan_Free(var scan:TMemScan); cdecl;
function TMemScan_CopyMem(var scan:TMemScan; addr:Pointer; bytesToRead:Int32; unsafe:LongBool): TByteArray; cdecl;
function TMemScan_Search(var scan:TMemScan; targetData:Pointer; targetSize:Int32; alignment:Int8): TPtrIntArray; cdecl;
function TMemScan_FindInstanceI32(var scan:TMemScan; contents:TIntArray; instSize:Int32): TPtrIntArray; cdecl;

function TMemScan_SearchRaw(var scan:TMemScan; var targetData; itemSize:SizeInt; alignment:Int8): TPtrIntArray; cdecl;
function TMemScan_FindInt8(var scan:TMemScan; data:UInt8; alignment:Int8): TPtrIntArray; cdecl;
function TMemScan_FindInt16(var scan:TMemScan; data:UInt16; alignment:Int8): TPtrIntArray; cdecl;
function TMemScan_FindInt32(var scan:TMemScan; data:UInt32; alignment:Int8): TPtrIntArray; cdecl;
function TMemScan_FindInt64(var scan:TMemScan; data:UInt64; alignment:Int8): TPtrIntArray; cdecl;
function TMemScan_FindFloat(var scan:TMemScan; data:Single; alignment:Int8): TPtrIntArray; cdecl;
function TMemScan_FindDouble(var scan:TMemScan; data:Double; alignment:Int8): TPtrIntArray; cdecl;
function TMemScan_FindString(var scan:TMemScan; data:AnsiString; alignment:Int8): TPtrIntArray; cdecl;
function TMemScan_FindWideString(var scan:TMemScan; data:WideString; alignment:Int8): TPtrIntArray; cdecl;
function TMemScan_FindByteArray(var scan:TMemScan; data:TByteArray; alignment:Int8): TPtrIntArray; cdecl;


implementation
uses Math;

function fastCompareMem(P1,P2:PChar; Length:SizeInt): Boolean; Inline;
var upper:PtrUInt;
begin
  Result := True;
  upper := PtrUInt(P1)+Length;
  while (PtrUInt(P1) < upper) do
  begin
    if P1^ <> P2^ then Exit(False);
    Inc(P1);
    Inc(P2);
  end;
end;


function GetWindowProcessID(window:HWND): UInt32; cdecl;
begin
  Windows.GetWindowThreadProcessId(window, result);
end;

function TMemScan.Init(pid:UInt32): Boolean;
var
  sysInfo: SYSTEM_INFO;
begin
  Windows.GetSystemInfo(@sysInfo);
  Self.SysMemLo := PtrUInt(sysInfo.lpMinimumApplicationAddress);
  Self.SysMemHi := PtrUInt(sysInfo.lpMaximumApplicationAddress);

  Self.Proc := OpenProcess(PROCESS_ALL_ACCESS,False,pid);
  if Self.Proc = 0 then
    raise Exception.Create(Format('TMemScan.Init -> PID %d does not exist', [pid]));

  Result := True;
end;

procedure TMemScan.Free();
begin
  if Self.Proc > 0 then
     CloseHandle(Self.Proc);
  Self.Proc     := 0;
  Self.SysMemLo := 0;
  Self.SysMemHi := 0;
end;


function TMemScan.CopyMem(addr:Pointer; bytesToRead:Int32; unsafe:Boolean): TByteArray;
var
  gotBytes:PtrUInt;
  memInfo: MEMORY_BASIC_INFORMATION;
begin
  SetLength(Result, bytesToRead);
  if unsafe then
  begin
    ReadProcessMemory(Self.Proc, addr, @Result[0], bytesToRead, gotBytes);
  end else
  begin
    if not InRange(PtrUInt(addr), self.SysMemLo, self.SysMemHi) then
      Exit();

    VirtualQueryEx(Self.Proc, addr, {out} memInfo, SizeOf(memInfo));
    if (MemInfo.State = MEM_COMMIT) and (not (MemInfo.Protect = PAGE_GUARD) or
       (MemInfo.Protect = PAGE_NOACCESS)) and (MemInfo.Protect = PAGE_READWRITE) then
    begin
      //rest := (PtrUInt(memInfo.BaseAddress) + memInfo.RegionSize) - PtrUInt(addr);
      //bytesToRead := Min(rest,bytesToRead);
      ReadProcessMemory(Self.Proc, addr, @Result[0], bytesToRead, gotBytes);
    end;
  end;
end;


(*
  Scans the procceess defined by `pid`, it will then return all addresses which
  matches the given target-value `targetData`. targetData can be any size `targetSize`,
  and will be compared using `CompareMem(...)`

  Alignment is the memory alignment, for example `4` bytes, can be used to skip some unwated matches.
*)
function TMemScan.Search(targetData:Pointer; targetSize:Int32; Alignment:Int8): TPtrIntArray;
var
  lo,hi:Int32;
  overhead,count,buf_size:Int32;
  memInfo: MEMORY_BASIC_INFORMATION;
  gotBytes, procMinAddr, procMaxAddr:PtrUInt;
  buffer:PChar;
begin
  alignment := max(alignment, 1);
  procMinAddr := Self.SysMemLo;
  procMaxAddr := Self.SysMemHi;

  buf_size := 5 * 1024 * 1024;
  buffer   := GetMem(buf_size);

  SetLength(Result, 1024);
  overhead := 1024;
  count := 0;

  while procMinAddr < procMaxAddr do
  begin
    VirtualQueryEx(Self.Proc, pointer(procMinAddr), {out} memInfo, SizeOf(memInfo));

    if (MemInfo.State = MEM_COMMIT) and (not (MemInfo.Protect = PAGE_GUARD) or
       (MemInfo.Protect = PAGE_NOACCESS)) and (MemInfo.Protect = PAGE_READWRITE) then
    begin
      if memInfo.RegionSize > buf_size then
      begin
        buffer := ReAllocMem(buffer, memInfo.RegionSize);
        buf_size := memInfo.RegionSize;
      end;

      if ReadProcessMemory(Self.Proc, memInfo.BaseAddress, buffer, memInfo.RegionSize, {out} gotBytes) then
      begin
        // scan the buffer for given value
        lo := 0;
        hi := memInfo.RegionSize - targetSize;
        if alignment <> 1 then
          lo += alignment - (PtrUInt(memInfo.BaseAddress) mod alignment);

        while lo <= hi do
        begin
          if fastCompareMem(targetData, @buffer[lo], targetSize) then
          begin
            if (count = overhead) then //overallocate result
            begin
              overhead += overhead;
              SetLength(Result, overhead);
            end;
            Result[count] := PtrUInt(memInfo.BaseAddress) + lo;
            inc(count);
          end;
          lo += alignment;
        end;
      end;
    end;
    // move to the next mem-chunk
    procMinAddr += memInfo.RegionSize;
  end;

  FreeMem(buffer);
  SetLength(Result, count);
end;


(*
  ........ yuk (MagicFunctionToFindTheMapBuffer)
*)
function TMemScan.FindInstanceI32(contents:TIntArray; instSize:Int32): TPtrIntArray;
var
  lo,hi,contsize,increment:Int32;
  overhead,count,buf_size:Int32;
  memInfo: MEMORY_BASIC_INFORMATION;
  gotBytes, procMinAddr:PtrUInt;
  buffer:PChar;
  canJump:Boolean;

  function ContainsData(constref needle:TIntArray; haystack:PInt32; instSize:Int16; var canJump:Boolean): Boolean; Inline;
  var j,upper,h:Int32;
  begin
    Result := False;
    j := 0;
    h := High(needle);
    upper := PtrUInt(haystack)+instSize;
    while PtrUInt(haystack) < upper do
    begin
      if haystack^ = needle[j] then
      begin
        Inc(j);
        if j > h then Exit(True);
      end;
      Inc(haystack);
    end;
    canJump := j = 0;
  end;
begin
  procMinAddr := Self.SysMemLo;

  buf_size := 5 * 1024 * 1024;
  buffer   := GetMem(buf_size);

  SetLength(Result, 1024);
  overhead := 1024;
  count := 0;

  contsize := instSize + (4 - instSize mod 4); //assumes 4 byte alignment
  increment := Max(4,contsize - 4);
  while procMinAddr < Self.SysMemHi do
  begin
    VirtualQueryEx(Self.Proc, pointer(procMinAddr), {out} memInfo, SizeOf(memInfo));

    if (MemInfo.State = MEM_COMMIT) and (MemInfo.Protect = PAGE_READWRITE) and
       (not (MemInfo.Protect = PAGE_GUARD) or (MemInfo.Protect = PAGE_NOACCESS)) then
    begin
      if memInfo.RegionSize > buf_size then
      begin
        buffer := ReAllocMem(buffer, memInfo.RegionSize);
        buf_size := memInfo.RegionSize;
      end;

      if ReadProcessMemory(Self.Proc, memInfo.BaseAddress, buffer, memInfo.RegionSize, {out} gotBytes) then
      begin
        // scan the buffer for given value
        lo := 0;
        hi := memInfo.RegionSize - contsize;
        
        while lo <= hi do
        begin
          if ContainsData(contents,@buffer[lo],instSize,canJump) then
          begin
            if (count = overhead) then //overallocate result
            begin
              overhead += overhead;
              SetLength(Result, overhead);
            end;
            Result[count] := PtrUInt(memInfo.BaseAddress) + lo;
            inc(count);
            Inc(lo, increment);
          end;
          if canJump then Inc(lo, increment)
          else Inc(lo, 4);
        end;
      end;
    end;
    // move to the next mem-chunk
    procMinAddr += memInfo.RegionSize;
  end;

  FreeMem(buffer);
  SetLength(Result, count);
end;



//----------------------------------------------------------------------------|\
//---| WRAPPERS |-------------------------------------------------------------||
//----------------------------------------------------------------------------|/
function TMemScan_Init(var scan:TMemScan; pid:UInt32): Boolean; cdecl;
begin
  Result := scan.Init(pid);
end;

procedure TMemScan_Free(var scan:TMemScan); cdecl;
begin
  scan.Free();
end;

function TMemScan_FindInstanceI32(var scan:TMemScan; contents:TIntArray; instSize:Int32): TPtrIntArray; cdecl;
begin
  Result := scan.FindInstanceI32(contents,instSize);
end;

function TMemScan_CopyMem(var scan:TMemScan; addr:Pointer; bytesToRead:Int32; unsafe:LongBool): TByteArray; cdecl;
begin
  Result := scan.CopyMem(addr, bytesToRead, unsafe);
end;

function TMemScan_Search(var scan:TMemScan; targetData:Pointer; targetSize:Int32; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.Search(targetData, targetSize, alignment);
end;

function TMemScan_SearchRaw(var scan:TMemScan; var targetData; itemSize:SizeInt; alignment:Int8): TPtrIntArray; cdecl;
var sizePtr:PInt32;
begin
  sizePtr := @Byte(targetData)-SizeOf(SizeInt);
  Result := scan.Search(@targetData, (sizePtr^ + 1) * itemSize, alignment);
end;

//---| Helpers |--------------------------------------------------------------\\
// ints
function TMemScan_FindInt8(var scan:TMemScan; data:UInt8; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.Search(@data, SizeOf(UInt8), alignment);
end;

function TMemScan_FindInt16(var scan:TMemScan; data:UInt16; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.Search(@data, SizeOf(UInt16), alignment);
end;

function TMemScan_FindInt32(var scan:TMemScan; data:UInt32; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.Search(@data, SizeOf(UInt32), alignment);
end;

function TMemScan_FindInt64(var scan:TMemScan; data:UInt64; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.Search(@data, SizeOf(UInt64), alignment);
end;

// floats
function TMemScan_FindFloat(var scan:TMemScan; data:Single; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.Search(@data, SizeOf(Single), alignment);
end;

function TMemScan_FindDouble(var scan:TMemScan; data:Double; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.Search(@data, SizeOf(Double), alignment);
end;

// str
function TMemScan_FindString(var scan:TMemScan; data:AnsiString; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.Search(@data[1], Length(data), alignment);
end;

function TMemScan_FindWideString(var scan:TMemScan; data:WideString; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.Search(@data[1], Length(data)*2, alignment);
end;

// general
function TMemScan_FindByteArray(var scan:TMemScan; data:TByteArray; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.Search(@data[0], Length(data), alignment);
end;



end.
