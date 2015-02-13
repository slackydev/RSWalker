{=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=]
 Copyright (c) 2013, Jarl K. <Slacky> Holta || http://github.com/WarPie
 All rights reserved.
[=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=}
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
  There are many diff bitmap structures so best we can do is to
  iterate over the n-nearest values hoping to find bitmaps dimensions.
*)
function ContainsBitmapDim(TIA:TIntegerArray; W,H:Int32): Boolean;
var i:Int32;
begin
  for i:=0 to High(TIA)-1 do
    if (tia[i] = W) and (tia[i+1] = H) then
      Exit(True);
end;


(*
  Search for a bitmap of the given size.
*)
function FindMemBufferImage(scan:TMemScan; W,H:Int32; AlignSize:Boolean=True; ExitOnFirst:Boolean=True): PtrUInt;
var
  matches,ref,tmp:TPtrIntArray;
  cl: TIntegerArray;
  data: TByteArray;
  size,i,j:Int32;
begin
  size := W*H;
  // It seems like the array-length should be divisible by four
  if AlignSize and InRange((4 - size mod 4),1,3) then
    size += (4 - size mod 4);

  matches := scan.FindInt32(size,4);
  for i:=0 to High(Matches) do
  begin
    // they always seems to be refering to a point which is 8 bytes
    // before the array-size is declared
    data := scan.CopyMem(matches[i]-8,8);
    if (BytesToInt(data,0) = 1) and      //array-dimensions?
       (BytesToInt(data,4) > scan.SysMemLo) then //some pointer
    begin
      // checking if somthing that looks like a bitmap structure refers
      // to what we think is the array
      ref := scan.FindInt32(Matches[i]-8,4);
      for j:=0 to High(ref) do
      begin
        cl := BytesToTIA(scan.CopyMem(ref[j]-32,64));
        if ContainsBitmapDim(cl,W,H) then
          if ExitOnFirst then
            Exit(Matches[i]+4)
          else
            tmp := tmp + Matches[i]+4;
      end;
    end;
  end;

  if length(tmp) > 0 then Exit(tmp[0]);
  RaiseException('Image buffer can''t be found');
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

