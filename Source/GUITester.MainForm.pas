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
  GUITester.Interfaces;

Type
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
      TGTTestStatus = (tsParsed, tsRunning, tsSuccessful, tsFailure);
  Strict Private
    FCurrentFile      : String;
    FGutterImageDict  : IDictionary<Integer, Integer>;
    FProcessInfo      : TProcessInformation;
    FLastCommandError : String;
  Strict Protected
    Procedure LoadSettings();
    Procedure SaveSettings();
    Function  INIFileName : String;
    Procedure OpenFile(Const strFileName : String);
    Procedure MarkLinesWithStatements(Const Statements : IGTStatements);
    Procedure ProcessStatements(Const Statements : IGTStatements);
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

Const
  strSetupINISection = 'Setup';
  strLeftINIKey = 'Left';
  strTopINIKey = 'Top';
  strWidthINIKey = 'Width';
  strHeightINIKey = 'Height';
  strCurrentFileINIKey = 'Current File';

{$R *.dfm}

Procedure TfrmTestGUIMainForm.actFileOpenExecute(Sender: TObject);

Begin
  If dlgOpen.Execute(Self.Handle) Then
    OpenFile(dlgOpen.FileName);
End;

Procedure TfrmTestGUIMainForm.actFileParseAndRunExecute(Sender: TObject);

ResourceString
  strOkay = 'Okay';

Var
  Parser : IGTParser;
  Statements : IGTStatements;

Begin
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
End;

Function TfrmTestGUIMainForm.CheckProcessEndCommand(Const Statement: IGTStatement): TGTTestStatus;

Var
  iResult : Cardinal;
  
Begin
  Result := tsRunning;
  FGutterImageDict[Statement.Line] := Integer(tsRunning);
  seCommands.InvalidateGutterLine(Statement.Line);
  Application.ProcessMessages;
  iResult := WaitForSingleObject(FProcessInfo.hProcess, Statement.Parameter[0].AsInteger);
  If iResult = WAIT_OBJECT_0 Then
    Result := tsSuccessful
  Else If iResult = WAIT_TIMEOUT Then
    Begin
      Result := tsFailure;
      FLastCommandError := 'Wait timed out!';
    End
  Else If iResult = WAIT_FAILED Then
    Begin
      Result := tsFailure;
      FLastCommandError := 'Wait failed!';
    End;
  FGutterImageDict[Statement.Line] := Integer(Result);
  seCommands.InvalidateGutterLine(Statement.Line);
  Application.ProcessMessages;
End;

procedure TfrmTestGUIMainForm.FormCreate(Sender: TObject);

Const
  iLightGreen = $C0FFC0;
  iLightRed = $C0C0FF;
  iLightPurple = $FFC080;
  iLightBlue = $FFC0C0;

begin
  FGutterImageDict := TCollections.CreateDictionary<Integer, Integer>;
  shGeneral.KeyAttri.Foreground := TColors.LightYellow;
  shGeneral.SymbolAttri.Foreground := iLightGreen;
  shGeneral.NumberAttri.Foreground := iLightRed;
  shGeneral.StringAttri.Foreground := iLightPurple;
  shGeneral.CommentAttri.Foreground := iLightBlue;
  LoadSettings();
  seCommandsStatusChange(Self, [scAll]);
end;

procedure TfrmTestGUIMainForm.FormDestroy(Sender: TObject);

begin
  SaveSettings();
end;

Function TfrmTestGUIMainForm.INIFileName: String;

Const
  strINIFileName = '\Season''s Fall\GUITester\GUITester.ini';
  strAppDataEnvVar = 'appdata';

Begin
  Result := GetEnvironmentVariable(strAppDataEnvVar) + strINIFileName;
  If Not DirectoryExists(ExtractFilePath(Result)) Then
    ForceDirectories(ExtractFilePath(Result));    
End;

Function TfrmTestGUIMainForm.LaunchCommand(Const Statement : IGTStatement) : TGTTestStatus;

Var
  hWrite : THandle;
  StartupInfo : TStartupInfo;
  boolResult : LongBool;
  strCommandLine : String;

Begin
  Result := tsRunning;
  FGutterImageDict[Statement.Line] := Integer(tsRunning);
  seCommands.InvalidateGutterLine(Statement.Line);
  Application.ProcessMessages;
  FillChar(StartupInfo, SizeOf(TStartupInfo), 0);
  StartupInfo.cb := SizeOf(TStartupInfo);
  StartupInfo.dwFlags     := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
  StartupInfo.wShowWindow := SW_HIDE;
  StartupInfo.hStdOutput  := hWrite;
  StartupInfo.hStdError   := hWrite;
  strCommandLine := '';
  If Statement.ParameterCount = 2 Then
    strCommandLine := Statement.Parameter[1].DeQuoteString;
  boolResult := CreateProcess(
    PChar(Statement.Parameter[0].DequoteString),
    PChar(strCommandLine), {Commandline}
    Nil,                   {ProcessAttr}
    Nil,                   {ThreadAttr}
    True,                  {InheritHandle}
    0,                     {CreationFlags}
    Nil,                   {Environment}
    Nil,                   {Directory}
    StartupInfo,           {StartupInfo}
    FProcessInfo           {ProcessInfo}
  );        
  If Not boolResult Then
    Begin
      Result := tsFailure;
      FLastCommandError := SysErrorMessage(GetLastError);
    End Else
      Result := tsSuccessful;
  FGutterImageDict[Statement.Line] := Integer(Result);
  seCommands.InvalidateGutterLine(Statement.Line);
  Application.ProcessMessages;
End;

Procedure TfrmTestGUIMainForm.LoadSettings;

Var
  iniFile : IShared<TMemIniFile>;

Begin
  iniFile := Shared.Make(TMemIniFile.Create(INIFileName));
  Left := iniFile.ReadInteger(strSetupINISection, strLeftINIKey, Left);
  Top := iniFile.ReadInteger(strSetupINISection, strTopINIKey, Top);
  Width := iniFile.ReadInteger(strSetupINISection, strWidthINIKey, Width);
  Height := iniFile.ReadInteger(strSetupINISection, strHeightINIKey, Height);
  FCurrentFile := iniFile.ReadString(strSetupINISection, strCurrentFileINIKey, '');
  If FileExists(FCurrentFile) Then
    OpenFile(FCurrentFile);
End;

Procedure TfrmTestGUIMainForm.MarkLinesWithStatements(Const Statements : IGTStatements);

Var
  i : Integer;
  Statement: IGTStatement;
  
Begin
  FGutterImageDict.Clear;
  For i := 0 To Statements.Count - 1 Do
    Begin
      Statement := Statements.Statement[i];
      //CodeSite.Send(Statement.AsString);
      FGutterImageDict[Statement.Line] := Integer(tsParsed);
    End;
  seCommands.InvalidateGutter;
  Application.ProcessMessages;
End;

Procedure TfrmTestGUIMainForm.OpenFile(Const strFileName: String);

ResourceString
  strErrorMsg = 'The file "%s" does not exists!';

Begin
  If seCommands.Modified And FileExists(FCurrentFile) Then
    seCommands.Lines.SaveToFile(FCurrentFile);
  If Not FileExists(strFileName) Then
    TaskMessageDlg(Application.Title, Format(strErrorMsg, [strFileName]), mtError, [mbOK], 0);
  FCurrentFile := strFileName;
  seCommands.Lines.LoadFromFile(FCurrentFile);
  seCommands.Modified := False;
  seCommands.ClearTrackChanges;
End;

Procedure TfrmTestGUIMainForm.ProcessStatements(Const Statements: IGTStatements);

Var
  eResult : TGTTestStatus;
  i : Integer;
  Statement : IGTStatement;

Begin
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
    StatusBar1.Panels[1].Text := 'Tests completed!';
  Finally
    seCommands.ReadOnly := False;
  End;
End;

Procedure TfrmTestGUIMainForm.SaveSettings;

Var
  iniFile : IShared<TMemIniFile>;

Begin
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

Procedure TfrmTestGUIMainForm.seCommandsChange(Sender: TObject);

Begin
  If seCommands.Modified Then
    Begin
      FGutterImageDict.Clear;
      seCommands.InvalidateGutter();
    End;
End;

Procedure TfrmTestGUIMainForm.seCommandsStatusChange(Sender: TObject; Changes: TSynStatusChanges);

Begin
  StatusBar1.Panels[0].Text := Format('%d : %d', [seCommands.CaretY, seCommands.CaretX]);
End;

Procedure TfrmTestGUIMainForm.seCommandsTSynGutterBands5PaintLines(RT: ID2D1RenderTarget; ClipR: TRect;
  Const FirstRow, LastRow: Integer; Var DoDefaultPainting: Boolean);

Var
  iRow : Integer;
  iLine : Integer;
  iLineHeight : Integer;
  iY : Integer;
  iImgIndex : Integer;
  
Begin
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

Function TfrmTestGUIMainForm.SendKeysCommand(Const Statement: IGTStatement): TGTTestStatus;

Var
  i: Integer;
  iParameter: Integer;
  iResult : Short;
  ShiftStates : TShiftState;

Begin
  Result := tsRunning;
  FGutterImageDict[Statement.Line] := Integer(tsRunning);
  seCommands.InvalidateGutterLine(Statement.Line);
  Application.ProcessMessages;
  ShiftStates := [];
  // Find Shift States - Start at 1 as parameter 0 is the text to output.
  For iParameter := 1 To Statement.ParameterCount -1 Do
    If CompareText(Statement.Parameter[iParameter].FText, 'CTRL') = 0 Then
      Include(ShiftStates, ssCtrl)
    Else If CompareText(Statement.Parameter[iParameter].FText, 'SHIFT') = 0 Then
      Include(ShiftStates, ssShift)
    Else If CompareText(Statement.Parameter[iParameter].FText, 'ALT') = 0 Then
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
          keybd_event(iResult And $00FF, 0, 0, 0);
          keybd_event(iResult And $00FF, 0, KEYEVENTF_KEYUP, 0);
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
  Application.ProcessMessages;
End;

Function TfrmTestGUIMainForm.WaitCommand(Const Statement: IGTStatement): TGTTestStatus;

Begin
  Result := tsRunning;
  FGutterImageDict[Statement.Line] := Integer(tsRunning);
  seCommands.InvalidateGutterLine(Statement.Line);
  Application.ProcessMessages;
  Sleep(Statement.Parameter[0].AsInteger);
  Result := tsSuccessful;
  FGutterImageDict[Statement.Line] := Integer(Result);
  seCommands.InvalidateGutterLine(Statement.Line);
  Application.ProcessMessages;
End;

Function TfrmTestGUIMainForm.WaitForIdleCommand(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strWaitTimedOut = 'Wait timed out!';
  strWaitFailed = 'Wait Failed!';

Var
  iResult : Cardinal;

Begin
  Result := tsRunning;
  FGutterImageDict[Statement.Line] := Integer(tsRunning);
  seCommands.InvalidateGutterLine(Statement.Line);
  Application.ProcessMessages;
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
  Application.ProcessMessages;
End;

Function TfrmTestGUIMainForm.WaitForWindowCommand(Const Statement: IGTStatement): TGTTestStatus;

Var
  iWnd : THandle;
  iStart : UINt64;
  WindowPLacement : TWindowPlacement;
  
Begin
  Result := tsRunning;
  FGutterImageDict[Statement.Line] := Integer(tsRunning);
  seCommands.InvalidateGutterLine(Statement.Line);
  Application.ProcessMessages;
  iStart := GetTickCount64;
  WindowPlacement.showCmd := SW_HIDE;
  Repeat
    iWnd := FindWindow(PChar(Statement.Parameter[0].FText.DeQuotedString), Nil);
    If iWnd > 0 Then
      GetWindowPlacement(iWnd, WindowPlacement);
    Sleep(100);
  Until ((iWnd > 0) And (WindowPlacement.showCmd In [SW_NORMAL, SW_MAXIMIZE])) Or
    (GetTickCount64 - iStart > Statement.Parameter[1].AsInteger);
  If iWnd > 0 Then
    Result := tsSuccessful
  Else
    Begin
      Result := tsFailure;
      FLastCommandError := 'Wait timed out!';
    End;
  FGutterImageDict[Statement.Line] := Integer(Result);
  seCommands.InvalidateGutterLine(Statement.Line);
  Application.ProcessMessages;
End;

End.

