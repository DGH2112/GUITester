(**

  This module contains the main project data for the GUI tester application.

  @Author  David Hoyle
  @Version 1.120
  @Date    03 Jun 2026

  @nocheck hardcodedstring
  @license

    GUI Tester is a Win64 GUI application in which you can write statements
    to mimic a users interaction with an application and test that certain
    operations perform as expected.
    
    Copyright (C) 2026  David Hoyle (https://github.com/DGH2112/GUITester/)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

**)
Program GUITester;

{$R 'ITHVerInfo.res' 'ITHVerInfo.RC'}

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
  GUITester.Statement in 'Source\GUITester.Statement.pas',
  GUITester.Functions in 'Source\GUITester.Functions.pas',
  GUITester.Parser.Statements in 'Source\GUITester.Parser.Statements.pas';

{$R *.res}

Begin
  Application.Initialize;
  TStyleManager.TrySetStyle('Tablet Dark');
  Application.Title := 'GUI Tester';
  Application.CreateForm(TfrmTestGUIMainForm, frmTestGUIMainForm);
  Application.MainFormOnTaskBar := True;
  Application.Run;
End.
