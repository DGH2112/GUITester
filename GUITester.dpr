Program GUITester;

uses
  FastMM4,
  CodeSiteLogging,
  VCL.Forms,
  Vcl.Themes,
  Vcl.Styles,
  DDetours,
  Vcl.Styles.Fixes,
  Vcl.Styles.Hooks,
  GUITester.MainForm in 'Source\GUITester.MainForm.pas' {frmTestGUIMainForm},
  GUITester.Interfaces in 'Source\GUITester.Interfaces.pas',
  GUITester.Parser in 'Source\GUITester.Parser.pas',
  GUITester.Statement in 'Source\GUITester.Statement.pas';

{$R *.res}

Begin
  Application.Initialize;
  TStyleManager.TrySetStyle('Tablet Dark');
  Application.Title := 'GUI Tester';
  Application.CreateForm(TfrmTestGUIMainForm, frmTestGUIMainForm);
  Application.MainFormOnTaskBar := True;
  Application.Run;
End.
