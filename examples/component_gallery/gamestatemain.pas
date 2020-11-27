{ Main state, where most of the application logic takes place.

  Feel free to use this code as a starting point for your own projects.
  (This code is in public domain, unlike most other CGE code which
  is covered by the LGPL license variant, see the COPYING.txt file.) }
unit GameStateMain;

interface

uses Classes,
  CastleUIState, CastleComponentSerialize, CastleUIControls, CastleControls,
  CastleKeysMouse;

type
  { Main state, where most of the application logic takes place. }
  TStateMain = class(TUIState)
  private
    const
      PagesCount = 3;

      { Suffixes of component names in the design,
        to find ButtonXxx and PageXxx matching controls. }
      PageNames: array [1..PagesCount] of String = (
        'Intro',
        'Buttons',
        'Buttons2'
      );

    var
      { Components designed using CGE editor, loaded from state_main.castle-user-interface. }
      LabelFps: TCastleLabel;
      PageButtons: array [1..PagesCount] of TCastleButton;
      Pages: array [1..PagesCount] of TCastleUserInterface;

    procedure ClickPageButton(Sender: TObject);
    procedure ClickToggle(Sender: TObject);
  public
    procedure Start; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
  end;

var
  StateMain: TStateMain;

implementation

uses SysUtils,
  CastleColors;

{ TStateMain ----------------------------------------------------------------- }

procedure TStateMain.Start;
var
  UiOwner: TComponent;
  I: Integer;
  PageButtons2: TCastleDesign;
  ButtonToggle: TCastleButton;
begin
  inherited;

  { Load designed user interface }
  InsertUserInterface('castle-data:/state_main.castle-user-interface', FreeAtStop, UiOwner);

  { Find components, by name, that we need to access from code }
  LabelFps := UiOwner.FindRequiredComponent('LabelFps') as TCastleLabel;
  for I := 1 to PagesCount do
  begin
    PageButtons[I] := UiOwner.FindRequiredComponent('Button' + PageNames[I]) as TCastleButton;
    PageButtons[I].Tag := I; // use button's tag to store page index
    PageButtons[I].OnClick := @ClickPageButton;
    Pages[I] := UiOwner.FindRequiredComponent('Page' + PageNames[I]) as TCastleUserInterface;
  end;

  { Find components inside TCastleDesigns, this needs 2 steps }
  PageButtons2 := UiOwner.FindRequiredComponent('PageButtons2') as TCastleDesign;
  ButtonToggle := PageButtons2.FindRequiredComponent('ButtonToggle') as TCastleButton;

  ButtonToggle.OnClick := @ClickToggle;
end;

procedure TStateMain.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  { This virtual method is executed every frame.}
  LabelFps.Caption := 'FPS: ' + Container.Fps.ToString;
end;

procedure TStateMain.ClickPageButton(Sender: TObject);
var
  I, CurrentPage: Integer;
  PageButton: TCastleButton;
begin
  PageButton := Sender as TCastleButton;
  CurrentPage := PageButton.Tag;
  for I := 1 to PagesCount do
  begin
    PageButtons[I].Pressed := I = CurrentPage;
    if I = CurrentPage then
      PageButtons[I].CustomTextColor := White
    else
      PageButtons[I].CustomTextColor := Black;
    Pages[I].Exists := I = CurrentPage;
  end;
end;

procedure TStateMain.ClickToggle(Sender: TObject);
var
  Button: TCastleButton;
begin
  Button := Sender as TCastleButton;
  Button.Pressed := not Button.Pressed;
end;

end.
