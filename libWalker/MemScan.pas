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

    function GetMemRange(low,high:PtrUInt; dataSize:Int32; Alignment:Int8): TPtrInfoArray;
    function CopyMem(addr:Pointer; bytesToRead:Int32): TByteArray;
    function Search(targetData:Pointer; targetSize:Int32; Alignment:Int8): TPtrIntArray;
    function SearchBoolMask(maskData:Pointer; maskSize:Int32; Alignment:Int8): TPtrIntArray;
  end;


function GetWindowProcessID(window:HWND): UInt32; cdecl;
  
function TMemScan_Init(var scan:TMemScan; pid:UInt32): Boolean; cdecl;
procedure TMemScan_Free(var scan:TMemScan); cdecl;
function TMemScan_GetMemRange(var scan:TMemScan; low, high:PtrUInt; dataSize:Int32; alignment:Int8): TPtrInfoArray; cdecl;
function TMemScan_CopyMem(var scan:TMemScan; addr:Pointer; bytesToRead:Int32): TByteArray; cdecl;
function TMemScan_Search(var scan:TMemScan; targetData:Pointer; targetSize:Int32; alignment:Int8): TPtrIntArray; cdecl;
function TMemScan_SearchBoolMask(var scan:TMemScan; maskData:Pointer; maskSize:Int32; alignment:Int8): TPtrIntArray; cdecl;

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


function TMemScan.GetMemRange(low,high:PtrUInt; dataSize:Int32; Alignment:Int8): TPtrInfoArray;
var
  lo,hi:Int32;
  overhead,count,buf_size:Int32;
  memInfo: MEMORY_BASIC_INFORMATION;
  gotBytes, procMinAddr, procMaxAddr:PtrUInt;
  buffer:PChar;
begin
  alignment := max(alignment, 1);
  procMinAddr := Max(low,  Self.SysMemLo);
  procMaxAddr := Min(high, Self.SysMemHi);

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
        //append the buffer to the result
        lo := 0;
        if PtrUInt(memInfo.BaseAddress) < procMinAddr then
          lo += procMinAddr - PtrUInt(memInfo.BaseAddress);
        if alignment <> 1 then
          lo += alignment - ((PtrUInt(memInfo.BaseAddress)+lo) mod alignment);
        hi := memInfo.RegionSize - dataSize;

        while lo <= hi do
        begin
          //overallocate result
          if (count >= overhead) then
          begin
            overhead += overhead;
            SetLength(Result, overhead);
          end;

          //set result
          Result[count].addr := PtrUInt(memInfo.BaseAddress) + lo;
          SetLength(Result[count].raw, dataSize);
          Move(buffer[lo], Result[count].raw[0], dataSize);
          inc(count);
          lo += alignment;
          if Result[count-1].addr >= procMaxAddr then
            Break;
        end;
      end;
    end;
    // move to the next mem-chunk
    procMinAddr += memInfo.RegionSize;
  end;

  FreeMem(buffer);
  SetLength(Result, count);
end;


function TMemScan.CopyMem(addr:Pointer; bytesToRead:Int32): TByteArray;
var
  gotBytes:PtrUInt;
begin
  SetLength(Result, bytesToRead);
  ReadProcessMemory(Self.Proc, addr, @Result[0], bytesToRead, {out} gotBytes);
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
          if CompareMem(targetData, @buffer[lo], targetSize) then
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



function CompareLongboolMask(mem,mask:Pointer; len:Int32): Boolean; inline;
var i:Int32 = 0;
begin
  while i < len do
  begin
    if (PUInt32(mem)^ <> 0) <> (PUInt32(mask)^ <> 0) then
      Exit(False);
    inc(mem, SizeOf(LongBool));
    inc(mask, SizeOf(LongBool));
    Inc(i,SizeOf(LongBool));
  end;
  Result := True;
end;

(*
  Scans the procceess defined by `pid`, it will then return all addresses which
  matches the given target-mask `maskData`. maskData can be any size `maskSize`.
  - targetData is a simple boolean-mask.

  Alignment is the memory alignment, for example `4` bytes, can be used to achieve
  better speed, and skip some unwated matches.

  Be warned the result can quickly get far to big with small masks!
*)
function TMemScan.SearchBoolMask(maskData:Pointer; maskSize:Int32; Alignment:Int8): TPtrIntArray;
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
        hi := memInfo.RegionSize - maskSize;
        if alignment <> 1 then
          lo += alignment - (PtrUInt(memInfo.BaseAddress) mod alignment);

        while lo <= hi do
        begin
          if CompareLongboolMask(@buffer[lo], maskData, maskSize) then
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

function TMemScan_GetMemRange(var scan:TMemScan; low, high:PtrUInt; dataSize:Int32; alignment:Int8): TPtrInfoArray; cdecl;
begin
  Result := scan.GetMemRange(low, high, dataSize, alignment);
end;

function TMemScan_CopyMem(var scan:TMemScan; addr:Pointer; bytesToRead:Int32): TByteArray; cdecl;
begin
  Result := scan.CopyMem(addr, bytesToRead);
end;

function TMemScan_Search(var scan:TMemScan; targetData:Pointer; targetSize:Int32; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.Search(targetData, targetSize, alignment);
end;

function TMemScan_SearchBoolMask(var scan:TMemScan; maskData:Pointer; maskSize:Int32; alignment:Int8): TPtrIntArray; cdecl;
begin
  Result := scan.SearchBoolMask(maskData, maskSize, alignment);
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
