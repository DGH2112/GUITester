(**

  This module contains the main programme for the GUI Tester.

  @Author  David Hoyle
  @Version 5.776
  @Date    07 Jun 2026

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
Unit GUITester.MainForm;

Interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.D2D1,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Actions,
  System.ImageList,
  System.Diagnostics,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.PlatformDefaultStyleActnCtrls,
  Vcl.ActnList,
  Vcl.ActnMan,
  Vcl.ToolWin,
  Vcl.ActnCtrls,
  Vcl.ImgList,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Spring.Collections,
  SynEdit,
  SynEditHighlighter,
  SynHighlighterGeneral,
  SynEditMiscClasses,
  GUITester.Interfaces;

Type
  (** A class which represents a form displaying the GUI Tester. **)
  TfrmTestGUIMainForm = Class(TForm)
    seCommands: TSynEdit;
    atbToolbar: TActionToolBar;
    amActions: TActionManager;
    ilActions: TImageList;
    actFileOpen: TAction;
    dlgOpen: TOpenDialog;
    shGeneral: TSynGeneralSyn;
    actFileParseAndRun: TAction;
    StatusBar1: TStatusBar;
    ilGutterStatus: TImageList;
    seOutput: TSynEdit;
    Splitter1: TSplitter;
    procedure actFileOpenExecute(Sender: TObject);
    procedure actFileParseAndRunExecute(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure seCommandsChange(Sender: TObject);
    procedure seCommandsStatusChange(Sender: TObject; Changes: TSynStatusChanges);
    procedure seCommandsTSynGutterBands5PaintLines(RT: ID2D1RenderTarget; ClipR: TRect; const FirstRow,
      LastRow: Integer; var DoDefaultPainting: Boolean);
  Strict Private
    FCurrentFile      : String;
    FGutterImageDict  : IDictionary<Integer, Integer>;
    FLastCommandError : String;
    FParserStatements : IGTParserStatements;
  Strict Protected
    Procedure LoadSettings();
    Procedure SaveSettings();
    Function  INIFileName : String;
    Procedure OpenFile(Const strFileName : String);
    Procedure MarkLinesWithStatements(Const Statements : IGTStatements);
    Procedure ProcessStatements(Const Statements : IGTStatements);
    Procedure EditorUpdateEvent(Const iLine : Integer; Const eStatus : TGTTestStatus);
    Procedure LastCommandError(Const strMsg : String);
    Procedure OutputEvent(Const strMsg : String; Const Args : Array Of Const);
  Public
  End;

Var
  (** A Delphi managed variable for the application main VCL form. **)
  frmTestGUIMainForm: TfrmTestGUIMainForm;

Implementation

uses
  System.IniFiles,
  System.IOUtils,
  System.UITypes,
  System.TypInfo,
  CodeSiteLogging,
  Spring,
  GUITester.Parser,
  SynDWrite,
  GUITester.Functions,
  GUITester.Parser.Statements;

Const
  (** A constant to define the Setup section of the INI File. **)
  strSetupINISection = 'Setup';
  (** A constant to define the Left INI Key. **)
  strLeftINIKey = 'Left';
  (** A constant to define the Top INI Key. **)
  strTopINIKey = 'Top';
  (** A constant to define the Width INI Key. **)
  strWidthINIKey = 'Width';
  (** A constant to define the Height INI Key. **)
  strHeightINIKey = 'Height';
  (** A constant to define the Current File INI Key. **)
  strCurrentFileINIKey = 'Current File';

{$R *.dfm}

{.$DEFINE CODESITE}

(**

  This is an on execute event handler for the File Open action.

  @precon  None.
  @postcon Displays a dialogue from which a GUI Tester source file can be opened.

  @param   Sender as a TObject

**)
Procedure TfrmTestGUIMainForm.actFileOpenExecute(Sender: TObject);

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'actFileOpenExecute', tmoTiming);{$ENDIF}
  If dlgOpen.Execute(Self.Handle) Then
    OpenFile(dlgOpen.FileName);
End;

(**

  This is an on execute event handler for the File Parser and Run action.

  @precon  None.
  @postcon This method parses the editor text and if okay runs the statements generated from the code.

  @param   Sender as a TObject

**)
Procedure TfrmTestGUIMainForm.actFileParseAndRunExecute(Sender: TObject);

ResourceString
  strOkay = 'Okay';
  strParsedInMs = 'Parsed in %1.0n ms!';

Var
  Parser : IGTParser;
  Statements : IGTStatements;
  Timer : TStopwatch;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'actFileParseAndRunExecute', tmoTiming);{$ENDIF}
  Timer := TStopwatch.Create();
  Timer.Start;
  seCommands.Indicators.Clear;
  Parser := TGTParser.Create();
  Parser.Parse(seCommands.Lines.Text);
  If Parser.LastError <> '' Then
    Begin
      OutputEvent(Parser.LastError, []);
      seCommands.CaretY := Parser.Line;
      seCommands.CaretX := Parser.Column;
    End Else
      OutputEvent(strOkay, []);
  Timer.Stop;
  OutputEvent(strParsedInMs, [Timer.ElapsedMilliseconds.ToExtended]);
  If Supports(Parser, IGTStatements, Statements) Then
    Begin
      MarkLinesWithStatements(Statements);
      If Parser.LastError <> '' Then
        Begin
          EditorUpdateEvent(Parser.Line, tsFailure);
          Exit;
        End;
      ProcessStatements(Statements);
    End;
End;

(**

  This method is an editor update event for the parser statements that allows the updated of the status
  of the gutter next to the statement.

  @precon  None.
  @postcon The gutter next to the statement is updated to reflect its current test status.

  @param   iLine   as an Integer as a constant
  @param   eStatus as a TGTTestStatus as a constant

**)
Procedure TfrmTestGUIMainForm.EditorUpdateEvent(Const iLine: Integer; Const eStatus: TGTTestStatus);

Begin
  FGutterImageDict[iLine] := Integer(eStatus);
  seCommands.InvalidateGutterLine(iLine);
  seCommands.Update;
End;

(**

  This is an On Form Create Event Handler for the TfrmTestGUIMainForm class.

  @precon  None.
  @postcon Sets up the highlighter defaults and loads the settings.

  @param   Sender as a TObject

**)
procedure TfrmTestGUIMainForm.FormCreate(Sender: TObject);

Const
  iLightGreen = $C0FFC0;
  iLightRed = $C0C0FF;
  iLightPurple = $FFC080;
  iLightBlue = $FFC0C0;

begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'FormCreate', tmoTiming);{$ENDIF}
  FGutterImageDict := TCollections.CreateDictionary<Integer, Integer>;
  shGeneral.KeyAttri.Foreground := TColors.LightYellow;
  shGeneral.SymbolAttri.Foreground := iLightGreen;
  shGeneral.NumberAttri.Foreground := iLightRed;
  shGeneral.StringAttri.Foreground := iLightPurple;
  shGeneral.CommentAttri.Foreground := iLightBlue;
  LoadSettings();
  seCommandsStatusChange(Self, [scAll]);
  FParserStatements := TGTParserStatements.Create(
    EditorUpdateEvent, LastCommandError, OutputEvent
  )
end;

(**

  This is an On Form Destroy Event Handler for the TfrmTestGUIMainForm class.

  @precon  None.
  @postcon Saves the applications settings.

  @param   Sender as a TObject

**)
procedure TfrmTestGUIMainForm.FormDestroy(Sender: TObject);

begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'FormDestroy', tmoTiming);{$ENDIF}
  SaveSettings();
end;

(**

  This method returns the name of the INI file in the users roaming profile.

  @precon  None.
  @postcon Returns the name of the INI file in the users roaming profile.

  @return  a String

**)
Function TfrmTestGUIMainForm.INIFileName: String;

Const
  strINIFileName = '\Season''s Fall\GUITester\GUITester.ini';
  strAppDataEnvVar = 'appdata';

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'INIFileName', tmoTiming);{$ENDIF}
  Result := GetEnvironmentVariable(strAppDataEnvVar) + strINIFileName;
  If Not DirectoryExists(ExtractFilePath(Result)) Then
    ForceDirectories(ExtractFilePath(Result));    
End;

(**

  This is an event for capturing the last command error.

  @precon  None.
  @postcon The last command error is stored for later use.

  @param   strMsg as a String as a constant

**)
Procedure TfrmTestGUIMainForm.LastCommandError(Const strMsg: String);

Begin
  FLastCommandError := strMsg;
End;

(**

  This method loads the applications settings.

  @precon  None.
  @postcon The applications settings are loaded.

**)
Procedure TfrmTestGUIMainForm.LoadSettings;

Var
  iniFile : IShared<TMemIniFile>;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'LoadSettings', tmoTiming);{$ENDIF}
  iniFile := Shared.Make(TMemIniFile.Create(INIFileName));
  Left := iniFile.ReadInteger(strSetupINISection, strLeftINIKey, Left);
  Top := iniFile.ReadInteger(strSetupINISection, strTopINIKey, Top);
  Width := iniFile.ReadInteger(strSetupINISection, strWidthINIKey, Width);
  Height := iniFile.ReadInteger(strSetupINISection, strHeightINIKey, Height);
  FCurrentFile := iniFile.ReadString(strSetupINISection, strCurrentFileINIKey, '');
  If FileExists(FCurrentFile) Then
    OpenFile(FCurrentFile);
End;

(**

  This method marks the lines in the editor with parsed statements.

  @precon  None.
  @postcon The lines with parsed statements are marked.

  @param   Statements as an IGTStatements as a constant

**)
Procedure TfrmTestGUIMainForm.MarkLinesWithStatements(Const Statements : IGTStatements);

Var
  i : Integer;
  Statement: IGTStatement;
  
Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'MarkLinesWithStatements', tmoTiming);{$ENDIF}
  FGutterImageDict.Clear;
  For i := 0 To Statements.Count - 1 Do
    Begin
      Statement := Statements.Statement[i];
      FGutterImageDict[Statement.Line] := Integer(tsParsed);
    End;
  seCommands.InvalidateGutter;
  seCommands.Update;
End;

(**

  This method attempts to open the given file in the editor.

  @precon  None.
  @postcon The file is opened in the editor else an error message is shown.

  @param   strFileName as a String as a constant

**)
Procedure TfrmTestGUIMainForm.OpenFile(Const strFileName: String);

ResourceString
  strErrorMsg = 'The file "%s" does not exists!';

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'OpenFile', tmoTiming);{$ENDIF}
  If seCommands.Modified And FileExists(FCurrentFile) Then
    seCommands.Lines.SaveToFile(FCurrentFile);
  If Not FileExists(strFileName) Then
    Begin
      TaskMessageDlg(Application.Title, Format(strErrorMsg, [strFileName]), mtError, [mbOK], 0);
      Exit;
    End;
  FCurrentFile := strFileName;
  seCommands.Lines.LoadFromFile(FCurrentFile);
  seCommands.Modified := False;
  seCommands.ClearTrackChanges;
End;

(**

  This method outputs the given message with the given parameters.

  @precon  None.
  @postcon Outputs the message and shows the line.

  @param   strMsg as a String as a constant
  @param   Args   as an Array Of Const as a constant

**)
Procedure TfrmTestGUIMainForm.OutputEvent(Const strMsg: String; Const Args: Array Of Const);

Const
  strTimeFmt = 'hh:nn:ss.zzz';

Var
  iLine: Integer;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'OutputEvent', tmoTiming);{$ENDIF}
  iLine := seOutput.Lines.Add(Format('%s: %s', [
    FormatDateTime(strTimeFmt, Now()),
    Format(strMsg, Args)
  ]));
  seOutput.GotoLineAndCenter(Succ(iLine));
  seOutput.Update;
End;

(**

  This method processes each statement in the statement list one at a time and stops of a statement
  fails.

  @precon  Statement must be a valid instance.
  @postcon Each statement in the list is processed until the end of the list or a failure.

  @param   Statements as an IGTStatements as a constant

**)
Procedure TfrmTestGUIMainForm.ProcessStatements(Const Statements: IGTStatements);

ResourceString
  strTestsCompleted = 'Tests completed in %1.0n ms!';
  strException = '* Exception: %s';

Var
  eResult : TGTTestStatus;
  i : Integer;
  Statement : IGTStatement;
  Timer : TStopwatch;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'ProcessStatements', tmoTiming);{$ENDIF}
  Try
    Timer := TStopwatch.Create();
    Timer.Start;
    seCommands.ReadOnly := True;
    Try
      For i := 0 To Statements.Count - 1 Do
        Begin
          Statement := Statements.Statement[i];
          seCommands.TopLine := Statement.Line - (seCommands.LinesInWindow Div 2);
          eResult := FParserStatements.RunStatement(Statement);
          If eResult = tsFailure Then
            Begin
              OutputEvent(FLastCommandError, []);
              Exit;
            End;
        End;
      Timer.Stop;
      OutputEvent(strTestsCompleted, [Timer.ElapsedMilliseconds.ToExtended]);
    Finally
      seCommands.ReadOnly := False;
    End;
  Except
    On E : EGTException Do
      Begin
        OutputEvent('*'#13#10, []);
        OutputEvent(strException, [E.Message]);
        OutputEvent('*'#13#10, []);
        EditorUpdateEvent(Statement.Line, tsFailure);
      End;
  End;
End;

(**

  This method saves the applications settings.

  @precon  None.
  @postcon The applications settings are saved.

**)
Procedure TfrmTestGUIMainForm.SaveSettings;

Var
  iniFile : IShared<TMemIniFile>;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'SaveSettings', tmoTiming);{$ENDIF}
  iniFile := Shared.Make(TMemIniFile.Create(INIFileName));
  iniFile.WriteInteger(strSetupINISection, strLeftINIKey, Left);
  iniFile.WriteInteger(strSetupINISection, strTopINIKey, Top);
  iniFile.WriteInteger(strSetupINISection, strWidthINIKey, Width);
  iniFile.WriteInteger(strSetupINISection, strHeightINIKey, Height);
  iniFile.WriteString(strSetupINISection, strCurrentFileINIKey, FCurrentFile);
  If FileExists(FCurrentFile) Then
    seCommands.Lines.SaveToFile(FCurrentFile);
  iniFile.UpdateFile();
End;

(**

  This is an on change event handler for the editor control.

  @precon  None.
  @postcon Clears the gutter of the editor if any changes are detected.

  @param   Sender as a TObject

**)
Procedure TfrmTestGUIMainForm.seCommandsChange(Sender: TObject);

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'seCommandsChange', tmoTiming);{$ENDIF}
  If seCommands.Modified Then
    Begin
      FGutterImageDict.Clear;
      seCommands.InvalidateGutter();
    End;
End;

(**

  This is an on status change event handler for the Editor control.

  @precon  None.
  @postcon Updates the statusbar with the cursor position.

  @param   Sender  as a TObject
  @param   Changes as a TSynStatusChanges

**)
Procedure TfrmTestGUIMainForm.seCommandsStatusChange(Sender: TObject; Changes: TSynStatusChanges);

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'seCommandsStatusChange', tmoTiming);{$ENDIF}
  StatusBar1.Panels[0].Text := Format('%d : %d', [seCommands.CaretY, seCommands.CaretX]);
End;

(**

  This is an on paint lines event handler for the custom gutter for the editor.

  @precon  None.
  @postcon Draws an image for the status of the statements in the editor.

  @nocheck MissingConstInParam

  @param   RT                as an ID2D1RenderTarget
  @param   ClipR             as a TRect
  @param   FirstRow          as an Integer as a constant
  @param   LastRow           as an Integer as a constant
  @param   DoDefaultPainting as a Boolean as a reference

**)
Procedure TfrmTestGUIMainForm.seCommandsTSynGutterBands5PaintLines(RT: ID2D1RenderTarget; ClipR: TRect;
  Const FirstRow, LastRow: Integer; Var DoDefaultPainting: Boolean);

Var
  iRow : Integer;
  iLine : Integer;
  iLineHeight : Integer;
  iY : Integer;
  iImgIndex : Integer;
  
Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'seCommandsTSynGutterBands5PaintLines', tmoTiming);{$ENDIF}
  DoDefaultPainting := False;
  iLineHeight := seCommands.LineHeight;
  For iRow := FirstRow To LastRow Do
    Begin
      iLine := seCommands.RowToLine(iRow);
      If seCommands.LineToRow(iLine) <> iRow Then
        Continue;
      iY := (iLineHeight - ilGutterStatus.Height) Div 2 +
        iLineHeight * (seCommands.LineToRow(iRow) - seCommands.TopLine);
      If FGutterImageDict.TryGetValue(iLine, iImgIndex) Then
        ImageListDraw(RT, ilGutterStatus, ClipR.Left, iY, iImgIndex);
    End;
End;

End.


