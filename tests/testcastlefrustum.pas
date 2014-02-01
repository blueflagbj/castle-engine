{
  Copyright 2005-2014 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

unit TestCastleFrustum;

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry,
  CastleVectors, CastleBoxes, CastleFrustum;

type
  TTestCastleFrustum = class(TTestCase)
  private
    procedure AssertFrustumSphereCollisionPossible(const Frustum: TFrustum;
      const SphereCenter: TVector3Single; const SphereRadiusSqt: Single;
      const GoodResult: TFrustumCollisionPossible);
    procedure AssertFrustumBox3DCollisionPossible(const Frustum: TFrustum;
      const Box3D: TBox3D; const GoodResult: TFrustumCollisionPossible);
  published
    procedure TestFrustum;
    procedure TestInfiniteFrustum;
    procedure TestCompareWithUnoptimizedPlaneCollision;
  end;

implementation

uses Math, CastleUtils, CastleTimeUtils;

function RandomFrustum(MakeZFarInfinity: boolean): TFrustum;

  function RandomNonZeroVector(const Scale: Float): TVector3Single;
  begin
    repeat
      Result[0] := Random * Scale - Scale/2;
      Result[1] := Random * Scale - Scale/2;
      Result[2] := Random * Scale - Scale/2;
    until not PerfectlyZeroVector(Result);
  end;

var
  ZFar: Single;
begin
  if MakeZFarInfinity then
    ZFar := ZFarInfinity else
    ZFar := Random * 100 + 100;
  Result.Init(
    PerspectiveProjMatrixDeg(
      Random * 30 + 60,
      Random * 0.5 + 0.7,
      Random * 5 + 1,
      ZFar),
    LookDirMatrix(
      { Don't randomize camera pos too much, as we want some non-trivial
        collisions with boxes generated by RandomBox. }
      RandomNonZeroVector(10),
      RandomNonZeroVector(1),
      RandomNonZeroVector(1)));
end;

function RandomBox: TBox3D;
begin
  Result.Data[0][0] := Random * 20 - 10;
  Result.Data[0][1] := Random * 20 - 10;
  Result.Data[0][2] := Random * 20 - 10;

  Result.Data[1][0] := Random * 20 - 10;
  Result.Data[1][1] := Random * 20 - 10;
  Result.Data[1][2] := Random * 20 - 10;

  OrderUp(Result.Data[0][0], Result.Data[1][0]);
  OrderUp(Result.Data[0][1], Result.Data[1][1]);
  OrderUp(Result.Data[0][2], Result.Data[1][2]);
end;

procedure TTestCastleFrustum.AssertFrustumSphereCollisionPossible(const Frustum: TFrustum;
  const SphereCenter: TVector3Single; const SphereRadiusSqt: Single;
  const GoodResult: TFrustumCollisionPossible);
begin
 Assert( Frustum.SphereCollisionPossible(SphereCenter,
   SphereRadiusSqt) = GoodResult);

 Assert( Frustum.SphereCollisionPossibleSimple(SphereCenter,
     SphereRadiusSqt) = (GoodResult <> fcNoCollision) );
end;

procedure TTestCastleFrustum.AssertFrustumBox3DCollisionPossible(const Frustum: TFrustum;
  const Box3D: TBox3D; const GoodResult: TFrustumCollisionPossible);
begin
 Assert( Frustum.Box3DCollisionPossible(Box3D) = GoodResult);

 Assert( Frustum.Box3DCollisionPossibleSimple(Box3D) =
   (GoodResult <> fcNoCollision) );
end;

procedure TTestCastleFrustum.TestFrustum;
var
  Frustum: TFrustum;
begin
 { Calculate testing frustum }
 Frustum.Init(
   PerspectiveProjMatrixDeg(60, 1, 10, 100),
   LookDirMatrix(
     Vector3Single(10, 10, 10) { eye position },
     Vector3Single(1, 0, 0) { look direction },
     vector3Single(0, 0, 1) { up vector } ));
 Assert(not Frustum.ZFarInfinity);

 AssertFrustumSphereCollisionPossible(Frustum, Vector3Single(0, 0, 0), 81,
   fcNoCollision);
 { This is between camera pos and near plane }
 AssertFrustumSphereCollisionPossible(Frustum, Vector3Single(0, 0, 0), 200,
   fcNoCollision);
 { This should collide with frustum, as it crosses near plane }
 AssertFrustumSphereCollisionPossible(Frustum, Vector3Single(0, 0, 0), 420,
   fcSomeCollisionPossible);
 AssertFrustumSphereCollisionPossible(Frustum, Vector3Single(50, 10, 10), 1,
   fcInsideFrustum);
 { This sphere intersects near plane }
 AssertFrustumSphereCollisionPossible(Frustum, Vector3Single(20, 10, 10), 1,
   fcSomeCollisionPossible);

 AssertFrustumBox3DCollisionPossible(Frustum, EmptyBox3D, fcNoCollision);
 AssertFrustumBox3DCollisionPossible(Frustum,
   Box3D(Vector3Single(-1, -1, -1), Vector3Single(9, 9, 9)),
   fcNoCollision);
 AssertFrustumBox3DCollisionPossible(Frustum,
   Box3D(Vector3Single(50, 10, 10), Vector3Single(51, 11, 11)),
   fcInsideFrustum);
 AssertFrustumBox3DCollisionPossible(Frustum,
   Box3D(Vector3Single(19, 10, 10), Vector3Single(21, 11, 11)),
   fcSomeCollisionPossible);
end;

procedure TTestCastleFrustum.TestInfiniteFrustum;
var
  Frustum: TFrustum;
begin
  Frustum.Init(
    PerspectiveProjMatrixDeg(60, 1, 10, ZFarInfinity),
    LookDirMatrix(
      Vector3Single(10, 10, 10) { eye position },
      Vector3Single(1, 0, 0) { look direction },
      vector3Single(0, 0, 1) { up vector } ));

  Assert(Frustum.Planes[fpFar][0] = 0);
  Assert(Frustum.Planes[fpFar][1] = 0);
  Assert(Frustum.Planes[fpFar][2] = 0);
  Assert(Frustum.ZFarInfinity);

  AssertFrustumSphereCollisionPossible(Frustum, Vector3Single(0, 0, 0), 81,
    fcNoCollision);
  AssertFrustumSphereCollisionPossible(Frustum, Vector3Single(100, 10, 10), 1,
    fcInsideFrustum);
  AssertFrustumSphereCollisionPossible(Frustum, Vector3Single(0, 0, 0), 400,
    fcSomeCollisionPossible);
end;

procedure TTestCastleFrustum.TestCompareWithUnoptimizedPlaneCollision;
{ Compare current Box3DCollisionPossible implementation with older
  implementation that didn't use smart Box3DPlaneCollision,
  instead was testing all 8 corners of bounding box.
  This compares results (should be equal) and speed (hopefully, new
  implementation is much faster!).
}
{ $define WRITELN_TESTS}

  function OldFrustumBox3DCollisionPossible(
    const Frustum: TFrustum;
    const Box: TBox3D): TFrustumCollisionPossible;

  { Note: I tried to optimize this function,
    since it's crucial for TOctree.EnumerateCollidingOctreeItems,
    and this is crucial for TCastleScene.RenderFrustumOctree,
    and this is crucial for overall speed of rendering. }

  var
    fp: TFrustumPlane;
    FrustumMultiplyBox: TBox3D;

    function CheckOutsideCorner(const XIndex, YIndex, ZIndex: Cardinal): boolean;
    begin
     Result :=
       { Frustum[fp][0] * Box[XIndex][0] +
         Frustum[fp][1] * Box[YIndex][1] +
         Frustum[fp][2] * Box[ZIndex][2] +
         optimized version : }
       FrustumMultiplyBox.Data[XIndex][0] +
       FrustumMultiplyBox.Data[YIndex][1] +
       FrustumMultiplyBox.Data[ZIndex][2] +
       Frustum.Planes[fp][3] < 0;
    end;

  var
    InsidePlanesCount: Cardinal;
    LastPlane: TFrustumPlane;
  begin
    with Frustum do
    begin
      InsidePlanesCount := 0;

      LastPlane := High(FP);
      Assert(LastPlane = fpFar);

      { If the frustum has far plane in infinity, then ignore this plane.
        Inc InsidePlanesCount, since the box is inside this infinite plane. }
      if ZFarInfinity then
      begin
        LastPlane := Pred(LastPlane);
        Inc(InsidePlanesCount);
      end;

      { The logic goes like this:
          if box is on the "outside" of *any* of 6 planes, result is NoCollision
          if box is on the "inside" of *all* 6 planes, result is InsideFrustum
          else SomeCollisionPossible. }

      for fp := Low(fp) to LastPlane do
      begin
       { This way I need 6 multiplications instead of 8*3=24
         (in case I would have to execute CheckOutsideCorner 8 times) }
       FrustumMultiplyBox.Data[0][0] := Planes[fp][0] * Box.Data[0][0];
       FrustumMultiplyBox.Data[0][1] := Planes[fp][1] * Box.Data[0][1];
       FrustumMultiplyBox.Data[0][2] := Planes[fp][2] * Box.Data[0][2];
       FrustumMultiplyBox.Data[1][0] := Planes[fp][0] * Box.Data[1][0];
       FrustumMultiplyBox.Data[1][1] := Planes[fp][1] * Box.Data[1][1];
       FrustumMultiplyBox.Data[1][2] := Planes[fp][2] * Box.Data[1][2];

       { I'm splitting code below to two possilibilities.
         This way I can calculate 7 remaining CheckOutsideCorner
         calls using code  like
           "... and ... and ..."
         or
           "... or ... or ..."
         , and this means that short-circuit boolean evaluation
         may usually reduce number of needed CheckOutsideCorner calls
         (i.e. I will not need to actually call CheckOutsideCorner 8 times
         per frustum plane). }

       if CheckOutsideCorner(0, 0, 0) then
       begin
        if CheckOutsideCorner(0, 0, 1) and
           CheckOutsideCorner(0, 1, 0) and
           CheckOutsideCorner(0, 1, 1) and
           CheckOutsideCorner(1, 0, 0) and
           CheckOutsideCorner(1, 0, 1) and
           CheckOutsideCorner(1, 1, 0) and
           CheckOutsideCorner(1, 1, 1) then
         { All 8 corners outside }
         Exit(fcNoCollision);
       end else
       begin
        if not (
           CheckOutsideCorner(0, 0, 1) or
           CheckOutsideCorner(0, 1, 0) or
           CheckOutsideCorner(0, 1, 1) or
           CheckOutsideCorner(1, 0, 0) or
           CheckOutsideCorner(1, 0, 1) or
           CheckOutsideCorner(1, 1, 0) or
           CheckOutsideCorner(1, 1, 1) ) then
         { All 8 corners inside }
         Inc(InsidePlanesCount);
       end;
      end;

      if InsidePlanesCount = 6 then
        Result := fcInsideFrustum else
        Result := fcSomeCollisionPossible;
    end;
  end;

  function OldFrustumBox3DCollisionPossibleSimple(
    const Frustum: TFrustum;
    const Box: TBox3D): boolean;

  { Implementation is obviously based on
    FrustumBox3DCollisionPossible above, see there for more comments. }

  var
    fp: TFrustumPlane;
    FrustumMultiplyBox: TBox3D;

    function CheckOutsideCorner(const XIndex, YIndex, ZIndex: Cardinal): boolean;
    begin
     Result :=
       { Planes[fp][0] * Box[XIndex][0] +
         Planes[fp][1] * Box[YIndex][1] +
         Planes[fp][2] * Box[ZIndex][2] +
         optimized version : }
       FrustumMultiplyBox.Data[XIndex][0] +
       FrustumMultiplyBox.Data[YIndex][1] +
       FrustumMultiplyBox.Data[ZIndex][2] +
       Frustum.Planes[fp][3] < 0;
    end;

  var
    LastPlane: TFrustumPlane;
  begin
    with Frustum do
    begin
      LastPlane := High(FP);
      Assert(LastPlane = fpFar);

      { If the frustum has far plane in infinity, then ignore this plane. }
      if ZFarInfinity then
        LastPlane := Pred(LastPlane);

      for fp := Low(fp) to LastPlane do
      begin
        { This way I need 6 multiplications instead of 8*3=24 }
        FrustumMultiplyBox.Data[0][0] := Planes[fp][0] * Box.Data[0][0];
        FrustumMultiplyBox.Data[0][1] := Planes[fp][1] * Box.Data[0][1];
        FrustumMultiplyBox.Data[0][2] := Planes[fp][2] * Box.Data[0][2];
        FrustumMultiplyBox.Data[1][0] := Planes[fp][0] * Box.Data[1][0];
        FrustumMultiplyBox.Data[1][1] := Planes[fp][1] * Box.Data[1][1];
        FrustumMultiplyBox.Data[1][2] := Planes[fp][2] * Box.Data[1][2];

        if CheckOutsideCorner(0, 0, 0) and
           CheckOutsideCorner(0, 0, 1) and
           CheckOutsideCorner(0, 1, 0) and
           CheckOutsideCorner(0, 1, 1) and
           CheckOutsideCorner(1, 0, 0) and
           CheckOutsideCorner(1, 0, 1) and
           CheckOutsideCorner(1, 1, 0) and
           CheckOutsideCorner(1, 1, 1) then
          Exit(false);
      end;

      Result := true;
    end;
  end;

const
  Tests = {$ifdef WRITELN_TESTS} 1000000 {$else} 1000 {$endif};
var
  TestCases: array of record
    Frustum: TFrustum;
    Box: TBox3D;
    Result1: TFrustumCollisionPossible;
    Result2: boolean;
  end;
  I: Integer;
  NoOutsideResults: Cardinal;
begin
  SetLength(TestCases, Tests);

  for I := 0 to Tests - 1 do
    with TestCases[I] do
    begin
      Frustum := RandomFrustum(I > Tests div 2);
      Box := RandomBox;
    end;

  {$ifdef WRITELN_TESTS} ProcessTimerBegin; {$endif}
  for I := 0 to Tests - 1 do
    with TestCases[I] do
    begin
      Result1 := OldFrustumBox3DCollisionPossible(Frustum, Box);
    end;
  {$ifdef WRITELN_TESTS}
  Writeln('Old TFrustum.Box3DCollisionPossible: ', ProcessTimerEnd);
  {$endif}

  {$ifdef WRITELN_TESTS} ProcessTimerBegin; {$endif}
  for I := 0 to Tests - 1 do
    with TestCases[I] do
    begin
      Assert(Result1 = Frustum.Box3DCollisionPossible(Box));
    end;
  {$ifdef WRITELN_TESTS}
  Writeln('New TFrustum.Box3DCollisionPossible: ', ProcessTimerEnd);
  {$endif}

  {$ifdef WRITELN_TESTS} ProcessTimerBegin; {$endif}
  for I := 0 to Tests - 1 do
    with TestCases[I] do
    begin
      Result2 := OldFrustumBox3DCollisionPossibleSimple(Frustum, Box);
    end;
  {$ifdef WRITELN_TESTS}
  Writeln('Old TFrustum.Box3DCollisionPossibleSimple: ', ProcessTimerEnd);
  {$endif}

  {$ifdef WRITELN_TESTS} ProcessTimerBegin; {$endif}
  for I := 0 to Tests - 1 do
    with TestCases[I] do
    begin
      Assert(Result2 = Frustum.Box3DCollisionPossibleSimple(Box));
    end;
  {$ifdef WRITELN_TESTS}
  Writeln('New TFrustum.Box3DCollisionPossibleSimple: ', ProcessTimerEnd);
  {$endif}

  {$ifdef WRITELN_TESTS}

  NoOutsideResults := 0;

  for I := 0 to Tests - 1 do
    with TestCases[I] do
      if Result1 <> fcNoCollision then
        Inc(NoOutsideResults);

  { How much the random data resembles real-life data, in real-life
    we may get something significant like 1/6 }
  Writeln('Ratio of non-outside results: ', (NoOutsideResults/Tests):1:10);

  {$endif}
end;

initialization
 RegisterTest(TTestCastleFrustum);
end.
