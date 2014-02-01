{
  Copyright 2003-2014 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Utilities specifically for VRML/X3D cameras.
  @seealso(CastleCameras For our general classes and utilities
    for camera handling.) }
unit X3DCameraUtils;

interface

uses CastleUtils, CastleVectors, CastleBoxes, X3DNodes;

type
  { Version of VRML/X3D camera definition. }
  TX3DCameraVersion = (cvVrml1_Inventor, cvVrml2_X3d);

const
  { Standard camera settings given by VRML/X3D specifications.
    @groupBegin }
  DefaultX3DCameraPosition: array [TX3DCameraVersion] of TVector3Single =
    ( (0, 0, 1), (0, 0, 10) );
  DefaultX3DCameraDirection: TVector3Single = (0, 0, -1);
  DefaultX3DCameraUp: TVector3Single = (0, 1, 0);
  DefaultX3DGravityUp: TVector3Single = (0, 1, 0);
  { @groupEnd }

{ Construct string with VRML/X3D node defining camera with given
  properties. }
function MakeCameraStr(const Version: TX3DCameraVersion;
  const Xml: boolean;
  const Position, Direction, Up, GravityUp: TVector3Single): string;

{ Construct TX3DNode defining camera with given properties.

  Overloaded version with ViewpointNode parameter returns
  the TAbstractViewpointNode descendant that is (somewhere within)
  the returned node. }
function MakeCameraNode(const Version: TX3DCameraVersion;
  const BaseUrl: string;
  const Position, Direction, Up, GravityUp: TVector3Single): TX3DNode;
function MakeCameraNode(const Version: TX3DCameraVersion;
  const BaseUrl: string;
  const Position, Direction, Up, GravityUp: TVector3Single;
  out ViewpointNode: TAbstractViewpointNode): TX3DNode;

{ Make camera node (like MakeCameraNode) that makes the whole box
  nicely visible (like CameraViewpointForWholeScene). }
function CameraNodeForWholeScene(const Version: TX3DCameraVersion;
  const BaseUrl: string;
  const Box: TBox3D;
  const WantedDirection, WantedUp: Integer;
  const WantedDirectionPositive, WantedUpPositive: boolean): TX3DNode;

function MakeCameraNavNode(const Version: TX3DCameraVersion;
  const BaseUrl: string;
  const NavigationType: string;
  const WalkSpeed, VisibilityLimit: Single; const AvatarSize: TVector3Single;
  const Headlight: boolean): TNavigationInfoNode;

implementation

uses SysUtils, CastleCameras;

function MakeCameraStr(const Version: TX3DCameraVersion;
  const Xml: boolean;
  const Position, Direction, Up, GravityUp: TVector3Single): string;
const
  Comment: array [boolean] of string = (
    '# Camera settings "encoded" in the VRML/X3D declaration below :' +nl+
    '# direction %s' +nl+
    '# up %s' +nl+
    '# gravityUp %s' + nl,

    '<!-- Camera settings "encoded" in the X3D declaration below :' +nl+
    '  direction %s' +nl+
    '  up %s' +nl+
    '  gravityUp %s -->' + nl);

  UntransformedViewpoint: array [TX3DCameraVersion, boolean] of string = (
    ('PerspectiveCamera {' +nl+
     '  position %s' +nl+
     '  orientation %s' +nl+
     '}',

     '<PerspectiveCamera' +nl+
     '  position="%s"' +nl+
     '  orientation="%s"' +nl+
     '/>'),

    ('Viewpoint {' +nl+
     '  position %s' +nl+
     '  orientation %s' +nl+
     '}',

     '<Viewpoint' +nl+
     '  position="%s"' +nl+
     '  orientation="%s"' +nl+
     '/>')
  );
  TransformedViewpoint: array [TX3DCameraVersion, boolean] of string = (
    ('Separator {' +nl+
     '  Transform {' +nl+
     '    translation %s' +nl+
     '    rotation %s %s' +nl+
     '  }' +nl+
     '  PerspectiveCamera {' +nl+
     '    position 0 0 0 # camera position is expressed by translation' +nl+
     '    orientation %s' +nl+
     '  }' +nl+
     '}',

     '<Separator>' +nl+
     '  <Transform' +nl+
     '    translation="%s"' +nl+
     '    rotation="%s %s"' +nl+
     '  />' +nl+
     '  <!-- the camera position is already expressed by the translation above -->' +nl+
     '  <PerspectiveCamera' +nl+
     '    position="0 0 0"' +nl+
     '    orientation="%s"' +nl+
     '  />' +nl+
     '</Separator>'),

    ('Transform {' +nl+
     '  translation %s' +nl+
     '  rotation %s %s' +nl+
     '  children Viewpoint {' +nl+
     '    position 0 0 0 # camera position is expressed by translation' +nl+
     '    orientation %s' +nl+
     '  }' +nl+
     '}',

     '<Transform' +nl+
     '  translation="%s"' +nl+
     '  rotation="%s %s">' +nl+
     '  <!-- the camera position is already expressed by the translation above -->' +nl+
     '  <Viewpoint' +nl+
     '    position="0 0 0"' +nl+
     '    orientation="%s"' +nl+
     '  />' +nl+
     '</Transform>')
  );

var
  RotationVectorForGravity: TVector3Single;
  AngleForGravity: Single;
begin
  Result := Format(Comment[Xml],
    [ VectorToRawStr(Direction),
      VectorToRawStr(Up),
      VectorToRawStr(GravityUp) ]);

  RotationVectorForGravity := VectorProduct(DefaultX3DGravityUp, GravityUp);
  if ZeroVector(RotationVectorForGravity) then
  begin
    { Then GravityUp is parallel to DefaultX3DGravityUp, which means that it's
      just the same. So we can use untranslated Viewpoint node. }
    Result := Result +
      Format(
        UntransformedViewpoint[Version, Xml],
        [ VectorToRawStr(Position),
          VectorToRawStr( CamDirUp2Orient(Direction, Up) ) ]);
  end else
  begin
    { Then we must transform Viewpoint node, in such way that
      DefaultX3DGravityUp affected by this transformation will give
      desired GravityUp. }
    AngleForGravity := AngleRadBetweenVectors(DefaultX3DGravityUp, GravityUp);
    Result := Result +
      Format(
        TransformedViewpoint[Version, Xml],
        [ VectorToRawStr(Position),
          VectorToRawStr(RotationVectorForGravity),
          FloatToRawStr(AngleForGravity),
          { I want
            1. standard VRML/X3D dir/up vectors
            2. rotated by orientation
            3. rotated around RotationVectorForGravity
            will give MatrixWalker.Direction/Up.
            CamDirUp2Orient will calculate the orientation needed to
            achieve given up/dir vectors. So I have to pass there
            MatrixWalker.Direction/Up *already rotated negatively
            around RotationVectorForGravity*. }
          VectorToRawStr( CamDirUp2Orient(
            RotatePointAroundAxisRad(-AngleForGravity, Direction, RotationVectorForGravity),
            RotatePointAroundAxisRad(-AngleForGravity, Up       , RotationVectorForGravity)
            )) ]);
  end;
end;

function MakeCameraNode(const Version: TX3DCameraVersion;
  const BaseUrl: string;
  const Position, Direction, Up, GravityUp: TVector3Single;
  out ViewpointNode: TAbstractViewpointNode): TX3DNode;
var
  RotationVectorForGravity: TVector3Single;
  AngleForGravity: Single;
  Separator: TSeparatorNode_1;
  Transform_1: TTransformNode_1;
  Transform_2: TTransformNode;
  Rotation, Orientation: TVector4Single;
begin
  RotationVectorForGravity := VectorProduct(DefaultX3DGravityUp, GravityUp);
  if ZeroVector(RotationVectorForGravity) then
  begin
    { Then GravityUp is parallel to DefaultX3DGravityUp, which means that it's
      just the same. So we can use untranslated Viewpoint node. }
    case Version of
      cvVrml1_Inventor: ViewpointNode := TPerspectiveCameraNode_1.Create('', BaseUrl);
      cvVrml2_X3d     : ViewpointNode := TViewpointNode.Create('', BaseUrl);
      else raise EInternalError.Create('MakeCameraNode Version incorrect');
    end;
    ViewpointNode.Position.Value := Position;
    ViewpointNode.FdOrientation.Value := CamDirUp2Orient(Direction, Up);
    Result := ViewpointNode;
  end else
  begin
    { Then we must transform Viewpoint node, in such way that
      DefaultX3DGravityUp affected by this transformation will give
      desired GravityUp. }
    AngleForGravity := AngleRadBetweenVectors(DefaultX3DGravityUp, GravityUp);
    Rotation := Vector4Single(RotationVectorForGravity, AngleForGravity);
    { I want
      1. standard VRML/X3D dir/up vectors
      2. rotated by orientation
      3. rotated around RotationVectorForGravity
      will give MatrixWalker.Direction/Up.
      CamDirUp2Orient will calculate the orientation needed to
      achieve given up/dir vectors. So I have to pass there
      MatrixWalker.Direction/Up *already rotated negatively
      around RotationVectorForGravity*. }
    Orientation := CamDirUp2Orient(
      RotatePointAroundAxisRad(-AngleForGravity, Direction, RotationVectorForGravity),
      RotatePointAroundAxisRad(-AngleForGravity, Up       , RotationVectorForGravity));
    case Version of
      cvVrml1_Inventor:
        begin
          Transform_1 := TTransformNode_1.Create('', BaseUrl);
          Transform_1.FdTranslation.Value := Position;
          Transform_1.FdRotation.Value := Rotation;

          ViewpointNode := TPerspectiveCameraNode_1.Create('', BaseUrl);
          ViewpointNode.Position.Value := ZeroVector3Single;
          ViewpointNode.FdOrientation.Value := Orientation;

          Separator := TSeparatorNode_1.Create('', BaseUrl);
          Separator.VRML1ChildAdd(Transform_1);
          Separator.VRML1ChildAdd(ViewpointNode);

          Result := Separator;
        end;

      cvVrml2_X3d:
        begin
          Transform_2 := TTransformNode.Create('', BaseUrl);
          Transform_2.FdTranslation.Value := Position;
          Transform_2.FdRotation.Value := Rotation;

          ViewpointNode := TViewpointNode.Create('', BaseUrl);
          ViewpointNode.Position.Value := ZeroVector3Single;
          ViewpointNode.FdOrientation.Value := Orientation;

          Transform_2.FdChildren.Add(ViewpointNode);

          Result := Transform_2;
        end;
      else raise EInternalError.Create('MakeCameraNode Version incorrect');
    end;
  end;
end;

function MakeCameraNode(const Version: TX3DCameraVersion;
  const BaseUrl: string;
  const Position, Direction, Up, GravityUp: TVector3Single): TX3DNode;
var
  ViewpointNode: TAbstractViewpointNode;
begin
  Result := MakeCameraNode(Version, BaseUrl, Position, Direction, Up, GravityUp,
    ViewpointNode { we ignore the returned ViewpointNode });
end;

function CameraNodeForWholeScene(const Version: TX3DCameraVersion;
  const BaseUrl: string;
  const Box: TBox3D;
  const WantedDirection, WantedUp: Integer;
  const WantedDirectionPositive, WantedUpPositive: boolean): TX3DNode;
var
  Position, Direction, Up, GravityUp: TVector3Single;
begin
  CameraViewpointForWholeScene(Box, WantedDirection, WantedUp,
    WantedDirectionPositive, WantedUpPositive, Position, Direction, Up, GravityUp);
  Result := MakeCameraNode(Version, BaseUrl,
    Position, Direction, Up, GravityUp);
end;

function MakeCameraNavNode(const Version: TX3DCameraVersion;
  const BaseUrl: string;
  const NavigationType: string;
  const WalkSpeed, VisibilityLimit: Single; const AvatarSize: TVector3Single;
  const Headlight: boolean): TNavigationInfoNode;
var
  NavigationNode: TNavigationInfoNode;
begin
  case Version of
    cvVrml2_X3d     : NavigationNode := TNavigationInfoNode.Create('', BaseUrl);
    else raise EInternalError.Create('MakeCameraNavNode Version incorrect');
  end;
  NavigationNode.FdType.Items.Clear;
  NavigationNode.FdType.Items.Add(NavigationType);
  NavigationNode.FdAvatarSize.Items.Clear;
  NavigationNode.FdAvatarSize.Items.AddArray(AvatarSize);
  NavigationNode.FdHeadlight.Value := Headlight;
  NavigationNode.FdSpeed.Value := WalkSpeed;
  NavigationNode.FdVisibilityLimit.Value := VisibilityLimit;
  Result := NavigationNode;
end;

end.
