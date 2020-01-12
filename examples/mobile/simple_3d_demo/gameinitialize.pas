{
  Copyright 2013-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Simple 3D application. This unit implements the application logic,
  actually independent from the target (mobile, desktop...). }
unit GameInitialize;

interface

implementation

uses SysUtils,
  CastleWindowTouch, CastleWindow, CastleControls, CastleUIControls,
  CastleRectangles,
  CastleGLUtils, CastleColors, X3DNodes, CastleFilesUtils, CastleLog,
  CastleSceneCore, CastleFindFiles, CastleStringUtils, CastleMessages,
  CastleProgress, CastleWindowProgress, CastleUtils, CastleSoundEngine,
  CastleApplicationProperties;

{ TODO:
  Using TCastleWindowTouch and TCastleWindow is deprecated.
  You should instead create your own Viewport: TCastleViewport instance.
  But... TCastleWindowTouch navigation UI is not yet upgraded.
}

var
  Window: TCastleWindowTouch;

  Image: TCastleImageControl;

  ToggleShaderButton: TCastleButton;
  ToggleScreenEffectButton: TCastleButton;
  ToggleSSAOButton: TCastleButton;
  TouchUIButton: TCastleButton;
  MessageButton: TCastleButton;
  ProgressButton: TCastleButton;
  ReopenContextButton: TCastleButton;
  ToggleTextureUpdatesButton: TCastleButton;
  PlaySoundWavButton: TCastleButton;
  PlaySoundOggButton: TCastleButton;
  TerminateButton: TCastleButton;

  MyShaderEffect: TEffectNode;
  MyScreenEffect: TScreenEffectNode;

  SoundBufferWav, SoundBufferOgg: TSoundBuffer;

type
  TEventsHandler = class
    class procedure ToggleShaderClick(Sender: TObject);
    class procedure ToggleScreenEffectClick(Sender: TObject);
    class procedure ToggleSSAOClick(Sender: TObject);
    class procedure TouchUIClick(Sender: TObject);
    class procedure MessageClick(Sender: TObject);
    class procedure ProgressClick(Sender: TObject);
    class procedure ReopenContextClick(Sender: TObject);
    class procedure ToggleTextureUpdates(Sender: TObject);
    class procedure ToggleTextureUpdatesCallback(Node: TX3DNode);
    class procedure PlaySoundWav(Sender: TObject);
    class procedure PlaySoundOgg(Sender: TObject);
    class procedure TerminateClick(Sender: TObject);
  end;

class procedure TEventsHandler.ToggleShaderClick(Sender: TObject);
begin
  if MyShaderEffect <> nil then
  begin
    MyShaderEffect.Enabled := not MyShaderEffect.Enabled;
    ToggleShaderButton.Pressed := MyShaderEffect.Enabled;
  end;
end;

class procedure TEventsHandler.ToggleScreenEffectClick(Sender: TObject);
begin
  if MyScreenEffect <> nil then
  begin
    MyScreenEffect.Enabled := not MyScreenEffect.Enabled;
    ToggleScreenEffectButton.Pressed := MyScreenEffect.Enabled;
  end;
end;

class procedure TEventsHandler.ToggleSSAOClick(Sender: TObject);
begin
  Window.SceneManager.ScreenSpaceAmbientOcclusion :=
    not Window.SceneManager.ScreenSpaceAmbientOcclusion;
  ToggleSSAOButton.Pressed := Window.SceneManager.ScreenSpaceAmbientOcclusion;
end;

class procedure TEventsHandler.TouchUIClick(Sender: TObject);
begin
  if Window.TouchInterface = High(TTouchInterface) then
    Window.TouchInterface := Low(TTouchInterface) else
    Window.TouchInterface := Succ(Window.TouchInterface);
end;

class procedure TEventsHandler.MessageClick(Sender: TObject);
begin
  { On Android, a nice test is to switch to desktop (home)
    when one of these modal MessageXxx is working. The application loop
    (done inside MessageXxx, they call Application.ProcessMessage in a loop)
    will still work, even though the window is closed.
    When user gets back to our app, she/he will see the message box again. }
  if MessageYesNo(Window, 'Test of a yes/no message test.' + NL + NL +' Do you want to deliberately cause an exception (to test our CastleWindow.HandleException method)?') then
  begin
    MessageOK(Window, 'You clicked "Yes". Raising an exception, get ready!');
    raise Exception.Create('Test exception');
  end else
    MessageOK(Window, 'You clicked "No".');
end;

class procedure TEventsHandler.ProgressClick(Sender: TObject);
const
  TestProgressSteps = 100;
var
  I: Integer;
begin
  Progress.Init(TestProgressSteps, 'Please wait');
  try
    for I := 1 to TestProgressSteps do
    begin
      Sleep(100);
      Progress.Step;
      { Note that on Android, Window may get closed (OpenGL context lost)
        at any time, also during such progress operation.
        For example when user switches to desktop (home) on Android.

        Progress.Step processes events (Application.ProcessMessage),
        so it will correctly react to it, closing the Window.
        This "for" loop will still continue, even though the window
        is closed (so no redraw will happen). It will actually get to the end
        of progress quickier (because without redraw, our speed is not throttled;
        you can see this by commenting Sleep call above. With window open,
        we're throttled by redraw speed. With window closed, we're not,
        and even long progress finishes quickly.)
        When the progress finishes, the main loop (from Application.Run)
        will allow to wait for next event (without doing busy waiting and wasting
        CPU), so we do not drain your battery power at all.

        If user will get back to our application before the progress finished,
        she/he will even correctly see the progress continuing at correct point.
        So everything just works. Just do not assume that Window stays
        open when processing events, and you're fine. }
      WritelnLog('Progress', 'Step %d', [I]);
    end;
  finally Progress.Fini end;
end;

class procedure TEventsHandler.ReopenContextClick(Sender: TObject);
begin
  Window.Close(false);
  Window.Open;
end;

class procedure TEventsHandler.ToggleTextureUpdatesCallback(Node: TX3DNode);
var
  CubeMap: TGeneratedCubeMapTextureNode;
  LogStr: string;
begin
  CubeMap := Node as TGeneratedCubeMapTextureNode;
  if CubeMap.Update = upNone then
    CubeMap.Update := upAlways else
    CubeMap.Update := upNone;
  WriteStr(LogStr, 'Toggled updates on ' + CubeMap.NiceName + ' to ', CubeMap.Update);
  WritelnLog('CubeMap', LogStr);
end;

class procedure TEventsHandler.ToggleTextureUpdates(Sender: TObject);
begin
  Window.SceneManager.MainScene.RootNode.EnumerateNodes(
    TGeneratedCubeMapTextureNode, @ToggleTextureUpdatesCallback, false);
end;

class procedure TEventsHandler.PlaySoundWav(Sender: TObject);
begin
  SoundEngine.PlaySound(SoundBufferWav);
end;

class procedure TEventsHandler.PlaySoundOgg(Sender: TObject);
begin
  SoundEngine.PlaySound(SoundBufferOgg);
end;

class procedure TEventsHandler.TerminateClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure FindFilesCallback(const FileInfo: TFileInfo; Data: Pointer; var StopSearch: boolean);
begin
  WritelnLog('FindFiles', 'Found URL:%s, Name:%s, AbsoluteName:%s, Directory:%s',
    [FileInfo.URL, FileInfo.Name, FileInfo.AbsoluteName, BoolToStr(FileInfo.Directory, true)]);
end;

{ One-time initialization. }
procedure ApplicationInitialize;
const
  Margin = 10;

var
  AnchorY: Integer;

  { Anchor next button under the previous one. }
  procedure AnchorNextButton(const B: TCastleButton);
  begin
    B.Anchor(vpTop, AnchorY);
    AnchorY -= Margin + Round(B.EffectiveHeight / B.UIScale);
  end;

begin
  Progress.UserInterface := WindowProgressInterface;

  Window.Container.UIScaling := usEncloseReferenceSize;
  Window.Container.UIReferenceWidth := 1024;
  Window.Container.UIReferenceHeight := 768;

  Image := TCastleImageControl.Create(Window);
  Image.URL := 'castle-data:/sample_image_with_alpha.png';
  Image.Anchor(hpLeft, Margin);
  Image.Anchor(vpTop, -Margin);
  Window.Controls.InsertFront(Image);

  Window.Load('castle-data:/castle_with_lights_and_camera.wrl');
  Window.MainScene.Spatial := [ssRendering, ssDynamicCollisions];
  Window.MainScene.ProcessEvents := true;

  { buttons in middle-top, from top to bottom }

  AnchorY := -Margin;

  ToggleShaderButton := TCastleButton.Create(Window);
  ToggleShaderButton.Caption := 'Toggle Shader Effect';
  ToggleShaderButton.OnClick := @TEventsHandler(nil).ToggleShaderClick;
  ToggleShaderButton.Toggle := true;
  ToggleShaderButton.Anchor(hpMiddle);
  Window.Controls.InsertFront(ToggleShaderButton);
  AnchorNextButton(ToggleShaderButton);

  ToggleScreenEffectButton := TCastleButton.Create(Window);
  ToggleScreenEffectButton.Caption := 'Toggle Screen Effect';
  ToggleScreenEffectButton.OnClick := @TEventsHandler(nil).ToggleScreenEffectClick;
  ToggleScreenEffectButton.Toggle := true;
  ToggleScreenEffectButton.Anchor(hpMiddle);
  Window.Controls.InsertFront(ToggleScreenEffectButton);
  AnchorNextButton(ToggleScreenEffectButton);

  ToggleSSAOButton := TCastleButton.Create(Window);
  ToggleSSAOButton.Caption := 'Toggle SSAO';
  ToggleSSAOButton.OnClick := @TEventsHandler(nil).ToggleSSAOClick;
  ToggleSSAOButton.Toggle := true;
  ToggleSSAOButton.Anchor(hpMiddle);
  Window.Controls.InsertFront(ToggleSSAOButton);
  AnchorNextButton(ToggleSSAOButton);

  { buttons in right-top, from top to bottom }

  AnchorY := -Margin;

  TouchUIButton := TCastleButton.Create(Window);
  TouchUIButton.Caption := 'Next Touch UI';
  TouchUIButton.OnClick := @TEventsHandler(nil).TouchUIClick;
  TouchUIButton.Anchor(hpRight, -Margin);
  Window.Controls.InsertFront(TouchUIButton);
  AnchorNextButton(TouchUIButton);

  MessageButton := TCastleButton.Create(Window);
  MessageButton.Caption := 'Test Modal Message';
  MessageButton.OnClick := @TEventsHandler(nil).MessageClick;
  MessageButton.Anchor(hpRight, -Margin);
  Window.Controls.InsertFront(MessageButton);
  AnchorNextButton(MessageButton);

  ProgressButton := TCastleButton.Create(Window);
  ProgressButton.Caption := 'Test Progress Bar';
  ProgressButton.OnClick := @TEventsHandler(nil).ProgressClick;
  ProgressButton.Anchor(hpRight, -Margin);
  Window.Controls.InsertFront(ProgressButton);
  AnchorNextButton(ProgressButton);

  ReopenContextButton := TCastleButton.Create(Window);
  ReopenContextButton.Caption := 'Test Reopening OpenGL Context';
  ReopenContextButton.OnClick := @TEventsHandler(nil).ReopenContextClick;
  ReopenContextButton.Anchor(hpRight, -Margin);
  Window.Controls.InsertFront(ReopenContextButton);
  AnchorNextButton(ReopenContextButton);

  ToggleTextureUpdatesButton := TCastleButton.Create(Window);
  ToggleTextureUpdatesButton.Caption := 'Toggle CubeMap Texture Updates';
  ToggleTextureUpdatesButton.OnClick := @TEventsHandler(nil).ToggleTextureUpdates;
  ToggleTextureUpdatesButton.Anchor(hpRight, -Margin);
  Window.Controls.InsertFront(ToggleTextureUpdatesButton);
  AnchorNextButton(ToggleTextureUpdatesButton);

  PlaySoundWavButton := TCastleButton.Create(Window);
  PlaySoundWavButton.Caption := 'Play Sound (Wav)';
  PlaySoundWavButton.OnClick := @TEventsHandler(nil).PlaySoundWav;
  PlaySoundWavButton.Anchor(hpRight, -Margin);
  Window.Controls.InsertFront(PlaySoundWavButton);
  AnchorNextButton(PlaySoundWavButton);

  PlaySoundOggButton := TCastleButton.Create(Window);
  PlaySoundOggButton.Caption := 'Play Sound (Ogg Vorbis)';
  PlaySoundOggButton.OnClick := @TEventsHandler(nil).PlaySoundOgg;
  PlaySoundOggButton.Anchor(hpRight, -Margin);
  Window.Controls.InsertFront(PlaySoundOggButton);
  AnchorNextButton(PlaySoundOggButton);

  TerminateButton := TCastleButton.Create(Window);
  TerminateButton.Caption := 'Terminate Application';
  TerminateButton.OnClick := @TEventsHandler(nil).TerminateClick;
  TerminateButton.Anchor(hpRight, -Margin);
  TerminateButton.Exists := {$if (defined(ANDROID) and not defined(CASTLE_NINTENDO_SWITCH)) or defined(CASTLE_IOS)} false {$else} true {$endif};
  Window.Controls.InsertFront(TerminateButton);
  AnchorNextButton(TerminateButton);

  MyShaderEffect := Window.SceneManager.MainScene.RootNode.TryFindNodeByName(
    TEffectNode, 'MyShaderEffect', false) as TEffectNode;
  ToggleShaderButton.Pressed := (MyShaderEffect <> nil) and MyShaderEffect.Enabled;

  MyScreenEffect := Window.SceneManager.MainScene.RootNode.TryFindNodeByName(
    TScreenEffectNode, 'MyScreenEffect', false) as TScreenEffectNode;
  ToggleScreenEffectButton.Pressed := (MyScreenEffect <> nil) and MyScreenEffect.Enabled;

  Window.TouchInterface := tiCtlWalkDragRotate;

  { Test that FindFiles works also on Android asset filesystem. }
  FindFiles('castle-data:/', '*', true, @FindFilesCallback, nil, [ffRecursive]);
  FindFiles('castle-data:/skies', '*', true, @FindFilesCallback, nil, [ffRecursive]);
  FindFiles('castle-data:/textures/castle', '*', true, @FindFilesCallback, nil, [ffRecursive]);
  FindFiles('castle-data:/textures/castle/', '*', true, @FindFilesCallback, nil, [ffRecursive]);

  SoundBufferWav := SoundEngine.LoadBuffer('castle-data:/sounds/player_potion_drink.wav');

  try
    SoundBufferOgg := SoundEngine.LoadBuffer('castle-data:/sounds/werewolf_howling.ogg');
  except
    on E: ESoundFileError do
      WritelnWarning('OggVorbis loading failed: ' + E.Message);
  end;
end;

procedure WindowRender(Container: TUIContainer);
begin
  UIFont.Print(10, 10, Yellow, Format('FPS : %s. Shapes : %d / %d',
   [Window.Fps.ToString,
    Window.SceneManager.Statistics.ShapesRendered,
    Window.SceneManager.Statistics.ShapesVisible]));
end;

initialization
  { Set ApplicationName early, as our log uses it. }
  ApplicationProperties.ApplicationName := 'simple_3d_demo';

  InitializeLog;

  { initialize Application callbacks }
  Application.OnInitialize := @ApplicationInitialize;

  { test: this is forbidden on Android.
    You cannot open files before Application.OnInitialize happened.
  LoadImage('castle-data:/sample_texture.ppm').Free;
  }

  { create Window and initialize Window callbacks }
  Window := TCastleWindowTouch.Create(Application);
  Application.MainWindow := Window;
  Window.OnRender := @WindowRender;
end.
