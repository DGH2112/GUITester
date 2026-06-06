(**

  This module contains the main programme for the GUI Tester.

  @Author  David Hoyle
  @Version 3.426
  @Date    06 Jun 2026

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

Uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
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
  WinAPI.D2D1,
  Spring.Collections,
  SynEdit,
  System.Actions,
  System.ImageList,
  SynEditHighlighter,
  SynHighlighterGeneral,
  SynEditMiscClasses,
  GUITester.Interfaces, Vcl.ExtCtrls;

Type
  (** A record to pass to the ENUMWINDOW call back functions to send a Process ID and return a window
      handle. **)
  TGTProcessInfo = Record
    FProcessID : Cardinal;
    FWndHnd    : THandle;
  End;
  (** A pointer to the above structure. **)
  PGTProcessInfo = ^TGTProcessInfo;

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
    Type
      (** An enumerate to define the status of a statement. **)
      TGTTestStatus = (tsParsed, tsRunning, tsSuccessful, tsFailure);
  Strict Private
    FCurrentFile      : String;
    FGutterImageDict  : IDictionary<Integer, Integer>;
    FProcessInfo      : TProcessInformation;
    FTopLvlWindowHnd  : THandle;
    FLastCommandError : String;
    FExecutable       : String;
    FDirectory        : String;
    FCommandLine      : String;
  Strict Protected
    Procedure LoadSettings();
    Procedure SaveSettings();
    Function  INIFileName : String;
    Procedure OpenFile(Const strFileName : String);
    Procedure MarkLinesWithStatements(Const Statements : IGTStatements);
    Procedure ProcessStatements(Const Statements : IGTStatements);
    Procedure OutputEvent(Const strMsg : String; Const Args : Array Of Const);
    Procedure SetupStartupInfo(Var StartupInfo : TStartupInfo);
    Procedure CaptureCommaneLine(Const Statement : IGTStatement);
    Function  StartProcess(Const StartupInfo : TStartupInfo;
      Var GTProcessInfo : TGTProcessInfo) : TGTTestStatus;
    // Statements
    Function LaunchCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function WaitForIdleCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function WaitForWindowCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function WaitCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function CheckProcessEndCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function SendKeysCommand(Const Statement : IGTStatement) : TGTTestStatus;
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
  CodeSiteLogging,
  Spring,
  GUITester.Parser,
  SynDWrite;

Type
  (** A record to encapsulate functions that wrap windows functions and convert them to simple Object
      Pascal methods. **)
  TGTFunctions = Record
  Strict Private
  Public
    Class Function WindowClassName(Const wHnd: THandle): String; Static;
    Class Function WindowText(Const wHnd: THandle): String; Static;
  End;

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

  This method returns the windows class name for the given window handle.

  @precon  None.
  @postcon The window class name for the given window handle is returned.

  @param   wHnd as a THandle as a constant
  @return  a String

**)
Class Function TGTFunctions.WindowClassName(Const wHnd: THandle): String;

Const
  iBufferLen = 256;

Var
  iLen: Integer;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'WindowClassName', tmoTiming);{$ENDIF}
  Result := StringOfChar(#0, iBufferLen);
  iLen := GetClassName(WHnd, PChar(Result), iBufferLen);
  SetLength(Result, iLen);
End;

(**

  This method returns the windows text for the given window handle.

  @precon  None.
  @postcon The window text for the given window handle is returned.

  @param   wHnd as a THandle as a constant
  @return  a String

**)
Class Function TGTFunctions.WindowText(Const wHnd: THandle): String;

Const
  iBufferLen = 256;

Var
  iLen: Integer;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'WindowText', tmoTiming);{$ENDIF}
  Result := StringOfChar(#0, iBufferLen);
  iLen := GetWindowText(WHnd, PChar(Result), iBufferLen);
  SetLength(Result, iLen);
End;
(**

  This method gets the top level window handle for the process ID passed in the lParam record and
  returns the window handle in the same lParam record.

  @precon  lParam
  @postcon If the window is found it is returns in the record passed visa the lParam.

  @nocheck MissingCONSTInParam

  @param   hWnd   as a HWND
  @param   lParam as a LPARAM
  @return  a BOOL

**)
Function WindowTopLvlWindow(hWnd : HWND; lParam : LPARAM) : BOOL; StdCall;

Var
  iProcessID : DWORD;
  ProcessInfo : PGTProcessInfo;

Begin
  Result := True;
  ProcessInfo := Pointer(lParam);
  GetWindowThreadProcessId(hWnd, iProcessID);
  If (iProcessID = ProcessInfo.FProcessID) Then
    Begin
      //CodeSite.SendFmtMsg('Window Class: %s, Window Text: %s', [
      //  TGTFunctions.WindowClassName(hWnd),
      //  TGTFunctions.WindowText(hWnd)
      //]);
      If (GetWindow(hWNd, GW_OWNER) = 0) And (IsWindowVisible(hWnd)) Then
        Begin
          ProcessInfo.FWndHnd := hWnd;
          Result := False;
        End;
    End;
End;

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
  strException = '* Exception: %s';

Var
  Parser : IGTParser;
  Statements : IGTStatements;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'actFileParseAndRunExecute', tmoTiming);{$ENDIF}
  Try
    seCommands.Indicators.Clear;
    Parser := TGTParser.Create();
    Parser.Parse(seCommands.Lines.Text);
    If Parser.LastError <> '' Then
      Begin
        StatusBar1.Panels[1].Text := Parser.LastError;
        seCommands.CaretY := Parser.Line;
        seCommands.CaretX := Parser.Column;
      End Else
        StatusBar1.Panels[1].Text := strOkay;
    If Supports(Parser, IGTStatements, Statements) Then
      Begin
        MarkLinesWithStatements(Statements);
        If Parser.LastError <> '' Then
          Exit;
        ProcessStatements(Statements);
      End;
  Except
    On E : EGTException Do
      Begin
        OutputEvent('*'#13#10, []);
        OutputEvent(strException, [E.Message]);
        OutputEvent('*'#13#10, []);
      End;
  End;
End;

(**

  This method captures the Executable, Command Line and Directory from the given statement.

  @precon  Statement must be a valid instance.
  @postcon The Executable, Command Line and Directory captured else an exception is raised.

  @param   Statement as an IGTStatement as a constant

**)
Procedure TfrmTestGUIMainForm.CaptureCommaneLine(Const Statement : IGTStatement);

ResourceString
  strExeDoesNotExist = 'The executable file "%s" does not exist!';
  strDirDoesNotExist = 'The directory "%s" does not exist!';

Const
  iSecondParam = 2;
  iThirdParam = 3;

Var
  boolResult: Boolean;
  
Begin
  FExecutable := Statement.Parameter[0].DequoteString;
  boolResult := FileExists(FExecutable);
  If Not boolResult Then
    Raise EGTException.CreateFmt(strExeDoesNotExist, [FExecutable]);
  // Check Directory
  If Statement.ParameterCount >= iSecondParam Then
    Begin
      FDirectory := Statement.Parameter[1].DeQuoteString;
      boolResult := DirectoryExists(FDirectory);
      If Not boolResult Then
        Raise EGTException.CreateFmt(strDirDoesNotExist, [FDirectory]);
    End Else
      FDirectory := ExtractFilePath(FExecutable);
  // Get the Command Line
  If Statement.ParameterCount = iThirdParam Then
    FCommandLine := Statement.Parameter[iSecondParam].DeQuoteString;
End;

(**

  This method checks that the process has terminated.

  @precon  Statement must be a valid instance.
  @postcon Waits to test whether the process has terminated.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TfrmTestGUIMainForm.CheckProcessEndCommand(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strWaitFailed = 'Wait failed!';
  strWaitTimedOut = 'Wait timed out!';

Var
  iResult : Cardinal;
  
Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'CheckProcessEndCommand', tmoTiming);{$ENDIF}
  Result := tsRunning;
  FGutterImageDict[Statement.Line] := Integer(tsRunning);
  seCommands.InvalidateGutterLine(Statement.Line);
  seCommands.Update;
  iResult := WaitForSingleObject(FProcessInfo.hProcess, Statement.Parameter[0].AsInteger);
  If iResult = WAIT_OBJECT_0 Then
    Result := tsSuccessful
  Else If iResult = WAIT_TIMEOUT Then
    Begin
      Result := tsFailure;
      FLastCommandError := strWaitTimedOut;
    End
  Else If iResult = WAIT_FAILED Then
    Begin
      Result := tsFailure;
      FLastCommandError := strWaitFailed;
    End;
  FGutterImageDict[Statement.Line] := Integer(Result);
  seCommands.InvalidateGutterLine(Statement.Line);
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

  This method launches the application to be tested.

  @precon  Statement must be a valid instance.
  @postcon The application is launched.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TfrmTestGUIMainForm.LaunchCommand(Const Statement : IGTStatement) : TGTTestStatus;

ResourceString
  strTopLevelWindowHandle = 'Top Level Window Handle: %d';
  strTopLevelWindowClass = 'Top Level Window Class: %s';
  strTopLevelWindowText = 'Top Level Window Text: %s';
  strTopLevelWindowHandleNotFound = 'Top Level Window Handle not found!';

Var
  StartupInfo : TStartupInfo;
  GTProcessInfo : TGTProcessInfo;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'LaunchCommand', tmoTiming);{$ENDIF}
  Try
    FGutterImageDict[Statement.Line] := Integer(tsRunning);
    seCommands.InvalidateGutterLine(Statement.Line);
    seCommands.Update;
    SetupStartupInfo(StartupInfo);
    CaptureCommaneLine(Statement);
    Result := StartProcess(StartupInfo, GTProcessInfo);
    // Check we found the main window
    If GTProcessInfo.FWndHnd > 0 Then
      Begin
        Result := tsSuccessful;
        FTopLvlWindowHnd := GTPRocessInfo.FWndHnd;
        OutputEvent(strTopLevelWindowHandle, [FTopLvlWindowHnd]);
        OutputEvent(strTopLevelWindowClass, [TGTFunctions.WindowClassName(FTopLvlWindowHnd)]);
        OutputEvent(strTopLevelWindowText, [TGTFunctions.WindowText(FTopLvlWindowHnd)]);
      End Else
      Begin
        Result := tsFailure;
        FLastCommandError := strTopLevelWindowHandleNotFound;
      End;
  Except
    On E : EGTException Do
      Begin
        Result := tsFailure;
        FLastCommandError := E.Message;
      End;
  End;
  FGutterImageDict[Statement.Line] := Integer(Result);
  seCommands.InvalidateGutterLine(Statement.Line);
  seCommands.Update;
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

Var
  iLine: Integer;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'OutputEvent', tmoTiming);{$ENDIF}
  iLine := seOutput.Lines.Add(Format(strMsg, Args));
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
  strTestsCompleted = 'Tests completed!';

Var
  eResult : TGTTestStatus;
  i : Integer;
  Statement : IGTStatement;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'ProcessStatements', tmoTiming);{$ENDIF}
  seCommands.ReadOnly := True;
  Try
    For i := 0 To Statements.Count - 1 Do
      Begin
        Statement := Statements.Statement[i];
        seCommands.TopLine := Statement.Line - (seCommands.LinesInWindow Div 2);
        Case Statement.StatementType Of
          stLaunch:          eResult := LaunchCommand(Statement);
          stWaitForIdle:     eResult := WaitForIdleCommand(Statement);
          stWaitForWindow:   eResult := WaitForWindowCommand(Statement);
          stWait:            eResult := WaitCommand(Statement);
          stSendKeys:        eResult := SendKeysCommand(Statement);
          stCheckProcessEnd: eResult := CheckProcessEndCommand(Statement);
        Else
          eResult := tsFailure;
        End;
        If eResult = tsFailure Then
          Begin
            StatusBar1.Panels[1].Text := FLastCommandError;
            Exit;
          End;
      End;
    StatusBar1.Panels[1].Text := strTestsCompleted;
  Finally
    seCommands.ReadOnly := False;
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

(**

  This method sends a stream of characters to the applications input method.

  @precon  Statement must be a valid instance.
  @postcon The characters are sent to the window.

  @todo    Change to use SendMessageWithTimeOut()

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TfrmTestGUIMainForm.SendKeysCommand(Const Statement: IGTStatement): TGTTestStatus;

Const
  strCTRLKey = 'CTRL';
  strSHIFTKey = 'SHIFT';
  strALTKey = 'ALT';
  iLowByte = $00FF;

Var
  i: Integer;
  iParameter: Integer;
  iResult : Short;
  ShiftStates : TShiftState;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'SendKeysCommand', tmoTiming);{$ENDIF}
  FGutterImageDict[Statement.Line] := Integer(tsRunning);
  seCommands.InvalidateGutterLine(Statement.Line);
  seCommands.Update;
  ShiftStates := [];
  // Find Shift States - Start at 1 as parameter 0 is the text to output.
  For iParameter := 1 To Statement.ParameterCount -1 Do
    If CompareText(Statement.Parameter[iParameter].FText, strCTRLKey) = 0 Then
      Include(ShiftStates, ssCtrl)
    Else If CompareText(Statement.Parameter[iParameter].FText, strSHIFTKey) = 0 Then
      Include(ShiftStates, ssShift)
    Else If CompareText(Statement.Parameter[iParameter].FText, strALTKey) = 0 Then
      Include(ShiftStates, ssAlt);
  // Extended keys down
  If ssCtrl In ShiftStates Then
    keybd_event(VK_CONTROL, 0, 0, 0);
  If ssShift In ShiftStates Then
    keybd_event(VK_SHIFT, 0, 0, 0);
  If ssAlt In ShiftStates Then
    keybd_event(VK_MENU, 0, 0, 0);
  // Key strokes
  For i := 1 To Statement.Parameter[0].FText.Length Do
    Begin
      iResult := VkKeyScan(Statement.Parameter[0].FText[i]);
      If iResult > -1 Then
        Begin
          keybd_event(iResult And iLowByte, 0, 0, 0);
          keybd_event(iResult And iLowByte, 0, KEYEVENTF_KEYUP, 0);
        End;
    End;
  // Extended keys up
  If ssAlt In ShiftStates Then
    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
  If ssShift In ShiftStates Then
    keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, 0);
  If ssCtrl In ShiftStates Then
    keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
  Result := tsSuccessful;
  FGutterImageDict[Statement.Line] := Integer(Result);
  seCommands.InvalidateGutterLine(Statement.Line);
  seCommands.Update;
End;

(**

  This method initialises the the given StartUpInfo record so it can be used to create a process.

  @precon  None.
  @postcon The StartUpInfo record is initialised.

  @param   StartupInfo as a TStartupInfo as a reference

**)
Procedure TfrmTestGUIMainForm.SetupStartupInfo(Var StartupInfo : TStartupInfo);

Const
  iPipeBufferSize = 4096;

Var
  hRead, hWrite : THandle;
  
Begin
    Win32Check(CreatePipe(hRead, hWrite, Nil, iPipeBufferSize));
    FillChar(StartupInfo, SizeOf(TStartupInfo), 0);
    StartupInfo.cb := SizeOf(TStartupInfo);
    StartupInfo.dwFlags     := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
    StartupInfo.wShowWindow := SW_HIDE;
    StartupInfo.hStdOutput  := hWrite;
    StartupInfo.hStdError   := hWrite;
End;

(**

  This method starts the GUI Application process to be tested.

  @precon  None.
  @postcon The GUI Application is started and application main window attempted to be captured.

  @param   StartupInfo   as a TStartupInfo as a constant
  @param   GTProcessInfo as a TGTProcessInfo as a reference
  @return  a TGTTestStatus

**)
Function TfrmTestGUIMainForm.StartProcess(Const StartupInfo: TStartupInfo;
  Var GTProcessInfo : TGTProcessInfo) : TGTTestStatus;

ResourceString
  strProcessHandle = 'Process Handle: %d';
  strProcessID = 'Process ID: %d';
  strProcess = 'Process: %s';

Const
  iWaitLoopInterval = 250;
  iMaxWaitTimeForAppStartup = 10000;

Var
  boolResult : LongBool;
  Timer : TStopwatch;

Begin
  Result := tsRunning;
  boolResult := CreateProcess(
    PChar(FExecutable),  {Executable}
    PChar(FCommandLine), {Commandline}
    Nil,                 {ProcessAttr}
    Nil,                 {ThreadAttr}
    True,                {InheritHandle}
    0,                   {CreationFlags}
    Nil,                 {Environment}
    PChar(FDirectory),   {Directory}
    StartupInfo,         {StartupInfo}
    FProcessInfo         {ProcessInfo}
  );        
  WaitForInputIdle(FProcessInfo.hProcess, iMaxWaitTimeForAppStartup);
  OutputEvent(strProcessHandle, [FProcessInfo.hProcess]);
  OutputEvent(strProcessID, [FProcessInfo.dwProcessId]);
  OutputEvent(strProcess, [FExecutable]);
  If Not boolResult Then
    Begin
      Result := tsFailure;
      FLastCommandError := SysErrorMessage(GetLastError);
      EGTException.Create(FLastCommandError);
    End;
  // Try and find the Main Window for 5000 milliseconds
  GTProcessInfo.FProcessID := FProcessInfo.dwProcessId;
  GTProcessInfo.FWndHnd := 0;
  Timer := TStopwatch.Create;
  TIMer.Start;
  Repeat
    Sleep(iWaitLoopInterval);
    EnumWindows(@WindowTopLvlWindow, LPARAM(@GTProcessInfo));
  Until (GTProcessInfo.FWndHnd > 0) Or (Timer.ElapsedMilliseconds > iMaxWaitTimeForAppStartup);
  Timer.Stop;
End;

(**

  This method waits for the specified period of time in the statements first parameter in milliseconds.

  @precon  Statement must be a valid instance.
  @postcon The method waits a period of time in milliseconds.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TfrmTestGUIMainForm.WaitCommand(Const Statement: IGTStatement): TGTTestStatus;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'WaitCommand', tmoTiming);{$ENDIF}
  FGutterImageDict[Statement.Line] := Integer(tsRunning);
  seCommands.InvalidateGutterLine(Statement.Line);
  seCommands.Update;
  Sleep(Statement.Parameter[0].AsInteger);
  Result := tsSuccessful;
  FGutterImageDict[Statement.Line] := Integer(Result);
  seCommands.InvalidateGutterLine(Statement.Line);
  seCommands.Update;
End;

(**

  This method attempts to wait for the test application to become idle. This method uses the first
  parameter of the statement as a wait time in milliseconds.

  @precon  Statement must be a valid instance.
  @postcon The method waits for the process to be idle before continuing.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TfrmTestGUIMainForm.WaitForIdleCommand(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strWaitTimedOut = 'Wait timed out!';
  strWaitFailed = 'Wait Failed!';

Var
  iResult : Cardinal;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'WaitForIdleCommand', tmoTiming);{$ENDIF}
  Result := tsRunning;
  FGutterImageDict[Statement.Line] := Integer(tsRunning);
  seCommands.InvalidateGutterLine(Statement.Line);
  seCommands.Update;
  iResult := WaitForInputIdle(FProcessInfo.hProcess, Statement.Parameter[0].AsInteger);
  {
  EnumWindows([](HWND hWnd, LPARAM lParam) -> BOOL
  BEGIN
    DWORD pid = 0;
    GetWindowThreadProcessId(hWnd, &pid);
    if (pid == (DWORD)lParam && IsWindowVisible(hWnd) && GetWindow(hWnd, GW_OWNER) == NULL) THEN
      BEGIN
        // candidate for "main" window
      END
      return TRUE;
  END, (LPARAM)pi.dwProcessId);
  }
  If iResult = 0 Then
    Result := tsSuccessful
  Else If iResult = WAIT_TIMEOUT Then
    Begin
      Result := tsFailure;
      FLastCommandError := strWaitTimedOut;
    End
  Else If iResult = WAIT_FAILED Then
    Begin
      Result := tsFailure;
      FLastCommandError := strWaitFailed;
    End;
  FGutterImageDict[Statement.Line] := Integer(Result);
  seCommands.InvalidateGutterLine(Statement.Line);
  seCommands.Update;
End;

(**

  This method attempts to wait for a top level window with the name provided by the parameter of the
  given statement. It looks not only for the window but also that the window is either showing NORMAL or
  MAZIMIZED.

  @precon  Statement must be a valid statement with 2 parameters: first the window name and; second the
           wait time in milliseconds.
  @postcon The method attempts to find the window and wait for it to be displayed else returns as failed.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TfrmTestGUIMainForm.WaitForWindowCommand(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strWaitTimedOut = 'Wait timed out!';

Const
  iDefaultWaitInterval = 100;

Var
  iWnd : THandle;
  iStart : UINt64;
  WindowPLacement : TWindowPlacement;
  
Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'WaitForWindowCommand', tmoTiming);{$ENDIF}
  FGutterImageDict[Statement.Line] := Integer(tsRunning);
  seCommands.InvalidateGutterLine(Statement.Line);
  seCommands.Update;
  iStart := GetTickCount64;
  WindowPlacement.showCmd := SW_HIDE;
  Repeat
    iWnd := FindWindow(PChar(Statement.Parameter[0].FText.DeQuotedString), Nil);
    If iWnd > 0 Then
      GetWindowPlacement(iWnd, WindowPlacement);
    Sleep(iDefaultWaitInterval);
  Until ((iWnd > 0) And (WindowPlacement.showCmd In [SW_NORMAL, SW_MAXIMIZE])) Or
    (GetTickCount64 - iStart > Statement.Parameter[1].AsInteger);
  If iWnd > 0 Then
    Result := tsSuccessful
  Else
    Begin
      Result := tsFailure;
      FLastCommandError := strWaitTimedOut;
    End;
  FGutterImageDict[Statement.Line] := Integer(Result);
  seCommands.InvalidateGutterLine(Statement.Line);
  seCommands.Update;
End;

End.


