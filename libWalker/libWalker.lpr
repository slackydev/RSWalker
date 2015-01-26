library libWalker;

{$mode objfpc}{$H+}
{$macro on}
{$inline on}
{$modeswitch advancedrecords}

uses
  SysUtils,
  Classes,
  Math,
  Windows,
  Utils,
  MemScan;


{$I SimbaPlugin.inc}

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

begin
end.
