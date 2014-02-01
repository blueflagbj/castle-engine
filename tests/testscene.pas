{
  Copyright 2004-2014 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ }
unit TestScene;

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry;

type
  TTestScene = class(TTestCase)
  published
    procedure TestScene;
  end;

implementation

uses X3DNodes, CastleSceneCore, CastleScene, CastleBoxes, CastleVectors;

procedure TTestScene.TestScene;

  procedure EmptySceneAsserts(EmptyScene: TCastleScene);
  var
    CamProjection: TProjectionType;
    CamPos, CamDir, CamUp, GravityUp: TVector3Single;
  begin
   Assert(EmptyScene.VerticesCount(false) = 0);
   Assert(EmptyScene.VerticesCount(true) = 0);
   Assert(EmptyScene.TrianglesCount(false) = 0);
   Assert(EmptyScene.TrianglesCount(true) = 0);

   Assert(EmptyScene.BoundingBox.IsEmpty);

   Assert(EmptyScene.ShapesActiveCount = 0);

   Assert(EmptyScene.GetViewpoint(CamProjection, CamPos, CamDir, CamUp, GravityUp) = nil);

   Assert(EmptyScene.FogStack.Top = nil);

   Assert(EmptyScene.Background = nil);
  end;

var EmptyScene: TCastleScene;
begin
 EmptyScene := TCastleScene.Create(nil);
 try
  EmptySceneAsserts(EmptyScene);
  EmptyScene.ChangedAll;
  EmptySceneAsserts(EmptyScene);
 finally FreeAndNil(EmptyScene) end;

 EmptyScene := TCastleScene.Create(nil);
 try
  EmptyScene.Load(TX3DRootNode.Create('', ''), true);
  EmptySceneAsserts(EmptyScene);
  EmptyScene.ChangedAll;
  EmptySceneAsserts(EmptyScene);
 finally FreeAndNil(EmptyScene) end;
end;

initialization
 RegisterTest(TTestScene);
end.
