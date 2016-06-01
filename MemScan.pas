{==============================================================================]
  Author: Jarl K. Holta
  Project: RSWalker 
  Project URL: https://github.com/WarPie/RSWalker
  License: GNU GPL (http://www.gnu.org/licenses/gpl.html)
  
  Misc stuff
[==============================================================================}
function HexStr(x:PtrUInt; Size:SizeInt=SizeOf(PtrUInt)): String;
begin
  Result := IntToHex(x, Size*2);
end;

function BytesToInt(data:TByteArray; start:Int32=0): Int32;
begin
  MemMove(data[start], result, 4);
end;

function BytesToTIA(data:TByteArray): TIntegerArray;
begin
  SetLength(result, length(data) div 4);
  MemMove(data[0], result[0], Length(data));
end;


(*
  Debug the bitmap at the given address
*)
procedure DebugMemBufferImage(scan:TMemScan; loc:PtrUInt; W,H:Int32);
var
  img: TMufasaBitmap;
  data:TByteArray;
  ptr: PRGB32;
begin
  data := scan.CopyMem(loc,W*H*SizeOf(TRGB32));
  img.Init(Client.getMBitmaps());
  img.SetSize(W,H);
  ptr := img.getData();
  MemMove(data[0], ptr^, Length(data));
  DisplayDebugImgWindow(W,H);
  DrawBitmapDebugImg(img.GetIndex());
  img.Free();
end;


(*
  Copy the data found at `loc` in to a TIntMatrix
*)
function GetMemBufferImage(scan:TMemScan; loc:PtrUInt; W,H:Int32): T2DIntArray;
var
  img: TMufasaBitmap;
  data:TByteArray;
  ptr: PRGB32;
begin
  data := scan.CopyMem(loc, W*H*SizeOf(TRGB32));
  img.Init();
  img.SetSize(W,H);
  ptr := img.getData();
  MemMove(data[0], ptr^, Length(data));
  Result := img.ToMatrix();
  img.Free();
end;

