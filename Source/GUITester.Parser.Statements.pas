(**
  
  This module contains a class which encapsulates the parser statements that can be executed.

  @Version 1.731
  @Author  David Hoyle
  @Date    06 Jun 2026
  
**)
Unit GUITester.Parser.Statements;

Interface

Uses
  Winapi.Windows,
  GUITester.Interfaces;

Type
  (** A record to pass to the ENUMWINDOW call back functions to send a Process ID and return a window
      handle. **)
  TGTProcessInfo = Record
    FProcessID : Cardinal;
    FWndHnd    : THandle;
  End;
  (** A pointer to the above structure. **)
  PGTProcessInfo = ^TGTProcessInfo;

  (** An event signature for updating the editor gutter status. **)
  TGTEditorUpdateEvent = Procedure(Const iLine : Integer; Const eStatus : TGTTestStatus) Of Object;
  (** An event signature for feeding back the last command error. **)
  TGTLastCommandError = Procedure(Const strMsg : String) of Object;
  (** An event signature for outputting event information to the main application. **)
  TGTOutputEvent = Procedure(Const strMsg : String; Const Args : Array Of Const) Of Object;
  
  (** A class which implements the IGTParserStatements interface. **)
  TGTParserStatements = Class(TInterfacedObject, IGTParserStatements)
  Strict Private
    FProcessInfo       : TProcessInformation;
    FExecutable        : String;
    FDirectory         : String;
    FCommandLine       : String;
    FTopLvlWindowHnd   : THandle;
    FEditorUpdateEvent : TGTEditorUpdateEvent;
    FLastCommandError  : TGTLastCommandError;
    FOutputEvent       : TGTOutputEvent;
  Strict Protected
    // IGTParserStatements
    Function LaunchCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function WaitForIdleCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function WaitForWindowCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function WaitCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function CheckProcessEndCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function SendKeysCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function BringToFront(Const Statement : IGTStatement) : TGTTestStatus;
    Function PositionWindow(Const Statement : IGTStatement) : TGTTestStatus;
    // General Methods
    Procedure CaptureCommaneLine(Const Statement : IGTStatement);
    Procedure SetupStartupInfo(Var StartupInfo : TStartupInfo);
    Procedure StartProcess(Const StartupInfo : TStartupInfo; Var GTProcessInfo : TGTProcessInfo);
  Public
    Constructor Create(
      Const EditorUpdateEvent : TGTEditorUpdateEvent;
      Const LastCommandError : TGTLastCommandError;
      Const OutputEvent : TGTOutputEvent
    );
  End;

Implementation

Uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  GUITester.Functions;

(**

  This method finds the windows with the given window class name and brings it to the front.

  @precon  Statement must be a valid instance.
  @postcon The window  with the given class name it brought to the front.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.BringToFront(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strWindowNotFound = 'Window "%S" not found!';

Var
  iWnd: HWND;

Begin
  FEditorUpdateEvent(Statement.Line, tsRunning);
  iWnd := TGTFunctions.FindWindowByRegEx(Statement.Parameter[0].FText.DeQuotedString, '');
  If iWnd > 0 Then
    Begin
      Win32Check(BringWindowToTop(iWnd));
      Result := tsSuccessful;
    End Else
    Begin
      Result := tsFailure;
      FLastCommandError(Format(strWindowNotFound, [Statement.Parameter[0].FText.DeQuotedString]));
    End;
  FEditorUpdateEvent(Statement.Line, Result);
End;

(**

  This method captures the Executable, Command Line and Directory from the given statement.

  @precon  Statement must be a valid instance.
  @postcon The Executable, Command Line and Directory captured else an exception is raised.

  @param   Statement as an IGTStatement as a constant

**)
Procedure TGTParserStatements.CaptureCommaneLine(Const Statement : IGTStatement);

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
Function TGTParserStatements.CheckProcessEndCommand(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strWaitFailed = 'Wait failed!';
  strWaitTimedOut = 'Wait timed out!';

Var
  iResult : Cardinal;
  
Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'CheckProcessEndCommand', tmoTiming);{$ENDIF}
  Result := tsRunning;
  FEditorUpdateEvent(Statement.Line, tsRunning);
  iResult := WaitForSingleObject(FProcessInfo.hProcess, Statement.Parameter[0].AsInteger);
  If iResult = WAIT_OBJECT_0 Then
    Result := tsSuccessful
  Else If iResult = WAIT_TIMEOUT Then
    Begin
      Result := tsFailure;
      FLastCommandError(strWaitTimedOut);
    End
  Else If iResult = WAIT_FAILED Then
    Begin
      Result := tsFailure;
      FLastCommandError(strWaitFailed);
    End;
  FEditorUpdateEvent(Statement.Line, Result);
End;

(**

  A constructor for the TGTParserStatements class.

  @precon  None.
  @postcon Stores the feedback events.

  @param   EditorUpdateEvent as a TGTEditorUpdateEvent as a constant
  @param   LastCommandError  as a TGTLastCommandError as a constant
  @param   OutputEvent       as a TGTOutputEvent as a constant

**)
Constructor TGTParserStatements.Create(
              Const EditorUpdateEvent : TGTEditorUpdateEvent;
              Const LastCommandError  : TGTLastCommandError;
              Const OutputEvent : TGTOutputEvent
            );

Begin
  FEditorUpdateEvent := EditorUpdateEvent;
  FLastCommandError := LastCommandError;
  FOutputEvent := OutputEvent;
End;

(**

  This method launches the application to be tested.

  @precon  Statement must be a valid instance.
  @postcon The application is launched.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.LaunchCommand(Const Statement : IGTStatement) : TGTTestStatus;

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
    FEditorUpdateEvent(Statement.Line, tsRunning);
    SetupStartupInfo(StartupInfo);
    CaptureCommaneLine(Statement);
    StartProcess(StartupInfo, GTProcessInfo);
    // Check we found the main window
    If GTProcessInfo.FWndHnd > 0 Then
      Begin
        Result := tsSuccessful;
        FTopLvlWindowHnd := GTPRocessInfo.FWndHnd;
        FOutputEvent(strTopLevelWindowHandle, [FTopLvlWindowHnd]);
        FOutputEvent(strTopLevelWindowClass, [TGTFunctions.WindowClassName(FTopLvlWindowHnd)]);
        FOutputEvent(strTopLevelWindowText, [TGTFunctions.WindowText(FTopLvlWindowHnd)]);
      End Else
      Begin
        Result := tsFailure;
        FLastCommandError(strTopLevelWindowHandleNotFound);
      End;
  Except
    On E : EGTException Do
      Begin
        Result := tsFailure;
        FLastCommandError(E.Message);
      End;
  End;
  FEditorUpdateEvent(Statement.Line, Result);
End;

(**

  This method positions the window with the given window class name.

  @precon  Statement must be a valid instance.
  @postcon If the window is found, it is positioned.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.PositionWindow(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strWindowNotFound = 'Window "%S" not found!';

Const
  iTopParam = 1;
  iLeftParam = 2;
  iWidthParam = 4;
  iHeightParam = 3;

Var
  iWnd: HWND;

Begin
  FEditorUpdateEvent(Statement.Line, tsRunning);
  iWnd := TGTFunctions.FindWindowByRegEx(Statement.Parameter[0].FText.DeQuotedString, '');
  If iWnd > 0 Then
    Begin
      Win32Check(MoveWindow(
        iWnd,
        Statement.Parameter[iLeftParam].AsInteger, // Left
        Statement.Parameter[iTopParam].AsInteger, // Top
        Statement.Parameter[iWidthParam].AsInteger, // Width
        Statement.Parameter[iHeightParam].AsInteger, // Height
        False
      ));
      Result := tsSuccessful;
    End Else
    Begin
      Result := tsFailure;
      FLastCommandError(Format(strWindowNotFound, [Statement.Parameter[0].FText.DeQuotedString]));
    End;
  FEditorUpdateEvent(Statement.Line, Result);
End;

(**

  This method sends a stream of characters to the applications input method.

  @precon  Statement must be a valid instance.
  @postcon The characters are sent to the window.

  @todo    Change to use SendMessageWithTimeOut()

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.SendKeysCommand(Const Statement: IGTStatement): TGTTestStatus;

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
  FEditorUpdateEvent(Statement.Line, tsRunning);
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
  FEditorUpdateEvent(Statement.Line, Result);
End;

(**

  This method initialises the the given StartUpInfo record so it can be used to create a process.

  @precon  None.
  @postcon The StartUpInfo record is initialised.

  @param   StartupInfo as a TStartupInfo as a reference

**)
Procedure TGTParserStatements.SetupStartupInfo(Var StartupInfo : TStartupInfo);

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

  This method gets the top level window handle for the process ID passed in the lParam record and
  returns the window handle in the same lParam record.

  @precon  lParam
  @postcon If the window is found it is returns in the record passed via the lParam.

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

  This method starts the GUI Application process to be tested.

  @precon  None.
  @postcon The GUI Application is started and application main window attempted to be captured.

  @param   StartupInfo   as a TStartupInfo as a constant
  @param   GTProcessInfo as a TGTProcessInfo as a reference

**)
Procedure TGTParserStatements.StartProcess(Const StartupInfo: TStartupInfo;
  Var GTProcessInfo : TGTProcessInfo);

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
  FOutputEvent(strProcessHandle, [FProcessInfo.hProcess]);
  FOutputEvent(strProcessID, [FProcessInfo.dwProcessId]);
  FOutputEvent(strProcess, [FExecutable]);
  If Not boolResult Then
    EGTException.Create(SysErrorMessage(GetLastError));
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
Function TGTParserStatements.WaitCommand(Const Statement: IGTStatement): TGTTestStatus;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'WaitCommand', tmoTiming);{$ENDIF}
  FEditorUpdateEvent(Statement.Line, tsRunning);
  Sleep(Statement.Parameter[0].AsInteger);
  Result := tsSuccessful;
  FEditorUpdateEvent(Statement.Line, Result);
End;

(**

  This method attempts to wait for the test application to become idle. This method uses the first
  parameter of the statement as a wait time in milliseconds.

  @precon  Statement must be a valid instance.
  @postcon The method waits for the process to be idle before continuing.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.WaitForIdleCommand(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strWaitTimedOut = 'Wait timed out!';
  strWaitFailed = 'Wait Failed!';

Var
  iResult : Cardinal;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'WaitForIdleCommand', tmoTiming);{$ENDIF}
  Result := tsRunning;
  FEditorUpdateEvent(Statement.Line, tsRunning);
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
      FLastCommandError(strWaitTimedOut);
    End
  Else If iResult = WAIT_FAILED Then
    Begin
      Result := tsFailure;
      FLastCommandError(strWaitFailed);
    End;
  FEditorUpdateEvent(Statement.Line, Result);
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
Function TGTParserStatements.WaitForWindowCommand(Const Statement: IGTStatement): TGTTestStatus;

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
  FEditorUpdateEvent(Statement.Line, tsRunning);
  iStart := GetTickCount64;
  WindowPlacement.showCmd := SW_HIDE;
  Repeat
    iWnd := TGTFunctions.FindWindowByRegEx(Statement.Parameter[0].FText.DeQuotedString, '');
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
      FLastCommandError(strWaitTimedOut);
    End;
  FEditorUpdateEvent(Statement.Line, Result);
End;

End.

