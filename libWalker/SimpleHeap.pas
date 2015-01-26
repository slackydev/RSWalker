unit SimpleHeap;
{=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=]
 Copyright (c) 2013, Jarl K. <Slacky> Holta || http://github.com/WarPie
 All rights reserved.
 For more info see: Copyright.txt
[=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=}
{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$macro on}
interface

uses SysUtils, Variants;

type
  (* An implmentation of heap queue algorithm *)
  generic HeapQueue<T> = class
  public type
    THeapItem = record Value:T; Extra:Int32; end;
  private
    FHeap : Array of THeapItem;
    FMinHeap: Boolean;
    FLen: Int32;

    function Get(index:Int32): THeapItem; inline;
    procedure Put(index:Int32; Value: THeapItem); inline;

    procedure Siftdown(startpos, pos:Int32); inline;
    procedure Siftdown_max(startpos, pos:Int32); inline;
    procedure Siftup(pos:Int32=0); inline;
    procedure Siftup_max(pos:Int32=0); inline;

  public
    constructor Create(MinHeap:Boolean=True);
    destructor Destroy; override;

    property Index[I: Int32]: THeapItem read Get write Put; default;
    property Size: Int32 read FLen write FLen;

    procedure Push(constref item:T); inline;
    procedure Push(constref item:T; extra:Int32); inline; overload;

    function Pop(): T; inline;
    function Pop(out extra:Int32): T; inline; overload;
  end;


//----------------------------------------------------------------------------\\
implementation


constructor HeapQueue.Create(MinHeap:Boolean=True);
begin
  SetLength(FHeap,0);
  FLen     := 0;
  FMinHeap := MinHeap;
end;

destructor HeapQueue.Destroy;
begin
  SetLength(FHeap,0);
  inherited;
end;

function HeapQueue.Get(index:Int32): THeapItem;
begin
  Result := FHeap[index];
end;

procedure HeapQueue.Put(index:Int32; Value: THeapItem);
begin
  FHeap[index] := Value;
end;

(*
 FHeap is a heap at all indices >= startpos, except possibly for pos.
 pos is the index of a leaf with a possibly out-of-order value.
 - Restore the heap invariant.
*)
procedure HeapQueue.Siftdown(startpos, pos:Int32);
var
  parentpos: Int32;
  parent,newitem: THeapItem;
begin
  newitem := FHeap[pos];
  while (pos > startpos) do begin
    parentpos := (pos - 1) shr 1;
    parent := FHeap[parentpos];
    if (newitem.value < parent.value) then
    begin
      FHeap[pos] := parent;
      pos := parentpos;
      continue;
    end;
    break;
  end;
  FHeap[pos] := newitem;
end;

//same as above except that this is used for MaxHeap
procedure HeapQueue.Siftdown_Max(startpos, pos:Int32);
var
  parentpos: Int32;
  parent,newitem: THeapItem;
begin
  newitem := FHeap[pos];
  while (pos > startpos) do begin
    parentpos := (pos - 1) shr 1;
    parent := FHeap[parentpos];
    if (newitem.value > parent.value) then
    begin
      FHeap[pos] := parent;
      pos := parentpos;
      continue;
    end;
    break;
  end;
  FHeap[pos] := newitem;
end;

(*
 The child indices of heap index pos are already heaps, and we want to make
 a heap at index pos too.  We do this by bubbling the smaller child of
 pos up (and so on with that child's children, etc) until hitting a leaf,
 then using Siftdown to move the oddball originally at index pos into place.
*)
procedure HeapQueue.Siftup(pos:Int32=0);
var
  endpos,startpos,childpos,rightpos:Int32;
  newitem: THeapItem;
begin
  endpos := FLen;
  startpos := pos;
  newitem := FHeap[pos];

  childpos := 2 * pos + 1;
  while childpos < endpos do begin
    rightpos := childpos + 1;
    if (rightpos < endpos) and not(FHeap[childpos].value < FHeap[rightpos].value) then
      childpos := rightpos;
    FHeap[pos] := FHeap[childpos];
    pos := childpos;
    childpos := 2 * pos + 1;
  end;
  FHeap[pos] := newitem;
  Self.Siftdown(startpos, pos);
end;

//same as above except that this is used for MaxHeap
procedure HeapQueue.Siftup_Max(pos:Int32=0);
var
  endpos,startpos,childpos,rightpos:Int32;
  newitem: THeapItem;
begin
  endpos := FLen;
  startpos := pos;
  newitem := FHeap[pos];

  childpos := 2 * pos + 1;
  while childpos < endpos do begin
    rightpos := childpos + 1;
    if (rightpos < endpos) and not(FHeap[childpos].value > FHeap[rightpos].value) then
      childpos := rightpos;
    FHeap[pos] := FHeap[childpos];
    pos := childpos;
    childpos := 2 * pos + 1;
  end;
  FHeap[pos] := newitem;
  Self.Siftdown_Max(startpos, pos);
end;


(*
 Push item onto heap, maintaining the heap invariant.
*)
procedure HeapQueue.Push(constref item:T);
begin
  SetLength(FHeap,FLen+1);

  FHeap[FLen].value := item;
  FHeap[FLen].extra := -1;
  if Self.FMinHeap then
    Self.Siftdown(0, FLen)
  else
    Self.Siftdown_Max(0, FLen);
  Inc(FLen);
end;

procedure HeapQueue.Push(constref item:T; extra:Int32);
begin
  SetLength(FHeap,FLen+1);

  FHeap[FLen].value := item;
  FHeap[FLen].extra := extra;
  if Self.FMinHeap then
    Self.Siftdown(0, FLen)
  else
    Self.Siftdown_Max(0, FLen);
  Inc(FLen);
end;


(*
 Pop the smallest item off the heap, maintaining the heap invariant.
*)
function HeapQueue.Pop(): T;
var item: T; extr: Int32;
begin
  if (FLen = 0) then Exit();
  Dec(FLen);
  item := FHeap[FLen].value;
  extr := FHeap[FLen].extra;
  SetLength(FHeap, FLen);
  if (FLen >= 1) then begin
    Result := FHeap[0].value;
    FHeap[0].value := item;
    FHeap[0].extra := extr;
    if Self.FMinHeap then
      Self.Siftup()
    else
      Self.Siftup_Max();
  end else
    Exit(item);
end;

function HeapQueue.Pop(out extra:Int32): T;
var item: T; extr: Int32;
begin
  if (FLen = 0) then Exit();
  Dec(FLen);
  item := FHeap[FLen].value;
  extr := FHeap[FLen].extra;
  SetLength(FHeap, FLen);
  if (FLen >= 1) then begin
    Result := FHeap[0].value;
    extra := FHeap[0].extra;
    FHeap[0].value := item;
    FHeap[0].extra := extr;
    if Self.FMinHeap then
      Self.Siftup()
    else
      Self.Siftup_Max();
  end else
  begin
    extra := extr;
    Exit(item);
  end;
end;




end.

