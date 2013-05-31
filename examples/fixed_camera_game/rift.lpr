{
  Copyright 2007-2013 Michalis Kamburelis.

  This file is part of "the rift".

  "the rift" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "the rift" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "the rift"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  ----------------------------------------------------------------------------
}

{ }
program rift;

{$apptype GUI}

uses SysUtils, CastleParameters, CastleUtils, CastleWindow,
  CastleClassUtils, CastleStringUtils, CastleProgress, CastleWindowProgress,
  CastleGLUtils, CastleLog, CastleGameNotifications,
  RiftWindow, RiftVideoOptions, RiftIntro, RiftMainMenu,
  RiftSound, RiftCreatures, CastleConfig, CastleSoundEngine, CastleVectors;

{ requested screen size ------------------------------------------------------ }

const
  DefaultRequestedScreenWidth = 1024;
  DefaultRequestedScreenHeight = 768;

var
  RequestedScreenWidth: Integer = DefaultRequestedScreenWidth;
  RequestedScreenHeight: Integer = DefaultRequestedScreenHeight;

function RequestedScreenSize: string;
begin
  Result := Format('%dx%d', [RequestedScreenWidth, RequestedScreenHeight]);
end;

function DefaultRequestedScreenSize: string;
begin
  Result := Format('%dx%d',
    [DefaultRequestedScreenWidth, DefaultRequestedScreenHeight]);
end;

{ parsing parameters --------------------------------------------------------- }

var
  WasParam_NoScreenChange: boolean = false;

const
  Version = '0.1.0';
  Options: array [0..7] of TOption =
  ( (Short:'h'; Long: 'help'; Argument: oaNone),
    (Short:'v'; Long: 'version'; Argument: oaNone),
    (Short:'n'; Long: 'no-screen-change'; Argument: oaNone),
    (Short: #0; Long: 'screen-size'; Argument: oaRequired),
    (Short: #0; Long: 'debug-menu-designer'; Argument: oaNone),
    (Short: #0; Long: 'debug-menu-fps'; Argument: oaNone),
    (Short: #0; Long: 'debug-log'; Argument: oaNone),
    (Short: #0; Long: 'debug-no-creatures'; Argument: oaNone)
  );

procedure OptionProc(OptionNum: Integer; HasArgument: boolean;
  const Argument: string; const SeparateArgs: TSeparateArgs; Data: Pointer);
begin
  case OptionNum of
    0: begin
         InfoWrite(
           '"The Rift" version ' + Version + '.' +nl+
           'WWW: http://castle-engine.sourceforge.net/' +nl+
           '     (no rift-specific webpage yet)' +nl+
           nl+
           'Options:' +nl+
           HelpOptionHelp +nl+
           VersionOptionHelp +nl+
           SoundEngine.ParseParametersHelp +nl+
           '  -n / --no-screen-resize' +nl+
           '                        Do not try to resize the screen.' +nl+
           '                        If your screen size is not the required' +nl+
           '                        size (set by --screen-size)' +nl+
           '                        then will run in windowed mode.' +nl+
           '  --screen-size WIDTHxHEIGHT' +nl+
           '                        Change the screen size (default is ' +
             DefaultRequestedScreenSize + ').' +nl+
           nl+
           Window.ParseParametersHelp([poDisplay], true) +nl+
           nl+
           'Debug (use only if you know what you''re doing):' +nl+
           '  --debug-menu-designer   Toggle menu designer by F12' +nl+
           '  --debug-menu-fps      Window caption will show intro/menus FPS' +nl+
           '  --debug-no-creatures  Do not load creatures. Only for developers,' +nl+
           '                        avoids loading creatures (may cause crashes' +nl+
           '                        if you don''t know what you''re doing).' +nl+
           '  --debug-log           Print log on StdOut. Be sure to redirect' +nl+
           '                        if running on Windows.'
           );
         ProgramBreak;
       end;
    1: begin
         WritelnStr(Version);
         ProgramBreak;
       end;
    2: WasParam_NoScreenChange := true;
    3: begin
         DeFormat(Argument, '%dx%d',
           [@RequestedScreenWidth, @RequestedScreenHeight]);
       end;
    4: DebugMenuDesignerAllowed := true;
    5: DebugMenuFps := true;
    6: InitializeLog(Version);
    7: DebugNoCreatures := true;
    else raise EInternalError.Create('OptionProc');
  end;
end;

function MyGetApplicationName: string;
begin
  Result := 'rift';
end;

{ main -------------------------------------------------------------------- }

begin
  { This is needed because
    - I sometimes display ApplicationName for user, and under Windows
      ParamStr(0) is ugly uppercased.
    - ParamStr(0) is unsure for Unixes.
    - ApplicationConfig uses this. }
  OnGetApplicationName := @MyGetApplicationName;

  { configure Notifications }
  Notifications.MaxMessages := 4;
  Notifications.Color := Vector3Single(0.8, 0.8, 0.8);

  SoundEngine; //< initialize before loading config and SoundEngine.ParseParameters
  Config.Load;

  { parse parameters }
  SoundEngine.ParseParameters;
  Window.ParseParameters([poDisplay]);
  Parameters.Parse(Options, @OptionProc, nil);

  { This should be called from CastleXMLConfig actually...
    but at CastleXMLConfig initialization it's too soon to call it
    (Log is not initialized yet). }
  if Log then
    WritelnLog('Config', 'Loading configuration from "%s"', [Config.URL]);

  Window.Width := RequestedScreenWidth;
  Window.Height := RequestedScreenHeight;
  Window.ColorBits := ColorDepthBits;
  if WasParam_NoScreenChange { or (not AllowScreenChange) } then
  begin
    Window.FullScreen :=
      (Application.ScreenWidth = RequestedScreenWidth) and
      (Application.ScreenHeight = RequestedScreenHeight);
  end else
  begin
    Window.FullScreen := true;
    if (Application.ScreenWidth <> RequestedScreenWidth) or
       (Application.ScreenHeight <> RequestedScreenHeight) or
       (VideoFrequency <> 0) or
       (ColorDepthBits <> 0) then
    begin
      Application.VideoColorBits := ColorDepthBits;
      Application.VideoFrequency := VideoFrequency;
      Application.VideoResize := true;
      Application.VideoResizeWidth := RequestedScreenWidth;
      Application.VideoResizeHeight := RequestedScreenHeight;

      if not Application.TryVideoChange then
      begin
        WarningWrite('Can''t change display settings to: ' +nl+
          Application.VideoSettingsDescribe +
          'Now I will just continue with default system settings. ');
        Window.FullScreen :=
          (Application.ScreenWidth = RequestedScreenWidth) and
          (Application.ScreenHeight = RequestedScreenHeight);
        { AllowScreenChange := false; }
      end;
    end;
  end;

  { open window }
  Window.Caption := 'The Rift';
  Window.ResizeAllowed := raOnlyAtOpen;
  Window.StencilBits := 8;
  Window.Open;

  { init progress }
  WindowProgressInterface.Window := Window;
  Progress.UserInterface := WindowProgressInterface;

  { open OpenAL (after opening Glw and Progress, because ALContextOpen
    wants to display progress of "Loading sounds") }
  {
  TODO: maybe later. DrawInitialBackground;}
  SoundEngine.ALContextOpen;
  try
    DoIntro;
    DoMainMenu;

    { unload all }
    CreaturesKinds.UnLoad;
  finally
    { Usually Window.Closed = false here.
      But this is finally...end clause so we try hard to avoid raising
      another exception here --- so we safeguard and eventually change
      Progress.UserInterface here. }
    if Window.Closed then
      Progress.UserInterface := ProgressNullInterface;

    SoundEngine.ALContextClose;
  end;

  Config.Save;
end.
