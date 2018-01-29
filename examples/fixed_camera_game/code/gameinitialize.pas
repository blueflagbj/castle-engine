{
  Copyright 2007-2018 Michalis Kamburelis.

  This file is part of "The Rift".

  "The Rift" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "The Rift" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "The Rift"; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA

  ----------------------------------------------------------------------------
}

{ Game initialization. }
unit GameInitialize;

interface

implementation

uses SysUtils,
  CastleScene, CastleControls, CastleLog, CastleWindow,
  CastleFilesUtils, CastleSceneCore, CastleKeysMouse, CastleColors,
  CastleUIControls, CastleApplicationProperties, CastleWindowProgress,
  CastleProgress, CastleGameNotifications, CastleVectors, CastleSoundEngine,
  CastleTransform, CastleConfig, CastleUIState,
  GameStateIntro, GameStateMainMenu, GameStatePlay, GameSound,
  GameConfiguration, GameCreatures, GameLocations;

var
  Window: TCastleWindowCustom;

{ routines ------------------------------------------------------------------- }

const
  DefaultWindowWidth = 1024;
  DefaultWindowHeight = 768;

{ One-time initialization of resources. }
procedure ApplicationInitialize;
begin
  Progress.UserInterface := WindowProgressInterface;
  Window.Container.UIReferenceWidth := DefaultWindowWidth;
  Window.Container.UIReferenceHeight := DefaultWindowHeight;
  Window.Container.UIScaling := usEncloseReferenceSize;

  { configure Notifications }
  Notifications.MaxMessages := 4;
  Notifications.Color := Vector4(0.8, 0.8, 0.8, 1.0);

  InitializeSound;

  { The reason for this is historical.
    We designed models in Blender following this (non-standard) orientation. }
  TCastleTransform.DefaultOrientation := otUpZDirectionX;

  { load game configuration }
  GameConfig := TCastleConfig.Create(nil);
  GameConfig.URL := ApplicationData('game.xml');
  CreatureKinds := TCreatureKindList.Create;
  Locations := TLocationList.Create;

  StateIntro := TStateIntro.Create(Application);
  StateMainMenu := TStateMainMenu.Create(Application);
  StatePlay := TStatePlay.Create(Application);

  TUIState.Current := StateIntro;
end;

initialization
  { Set ApplicationName and Version early, as our log uses it. }
  ApplicationProperties.ApplicationName := 'rift';
  ApplicationProperties.Version := '0.1.0';

  { Start logging. Do this as early as possible,
    to log information and eventual warnings during initialization. }
  InitializeLog;

  { Initialize Application.OnInitialize. }
  Application.OnInitialize := @ApplicationInitialize;

  { Create and assign Application.MainWindow. }
  Window := TCastleWindowCustom.Create(Application);
  Application.MainWindow := Window;

  { Assign initial window size and configuration.
    This can be overridden by parsing command-line options for standalone platform. }
  Window.Width := DefaultWindowWidth;
  Window.Height := DefaultWindowHeight;
  Window.FullScreen := true;
  Window.Caption := 'The Rift';
  Window.FpsShowOnCaption := true;
  // for shadow volumes to be possible
  Window.StencilBits := 8;
end.
