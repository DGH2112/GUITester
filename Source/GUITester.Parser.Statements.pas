(**
  
  This module contains a class which encapsulates the parser statements that can be executed.

  @Version 6.476
  @Author  David Hoyle
  @Date    18 Jun 2026
  
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
Unit GUITester.Parser.Statements;

Interface

uses
  Winapi.Windows,
  System.RegularExpressions,
  Spring.Collections,
  GUITester.Interfaces,
  GUITester.Functions;

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
  (** A method signature for all statements which can be run. **)
  TGTStatementSignature = Function(Const Statement : IGTStatement) : TGTTestStatus Of Object;

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
    FStatements        : IDictionary<TGTStatementType, TGTStatementSignature>;
  Strict Protected
    // IGTParserStatements
    Function  RunStatement(Const Statement : IGTStatement) : TGTTestStatus;
    // Statements
    Function LaunchCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function WaitForIdleCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function WaitForWindowCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function WaitCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function CheckProcessEndCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function SendKeysCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function TestClassCommand(Const Statement : IGTStatement) : TGTTestStatus;
    Function BringToFront(Const Statement : IGTStatement) : TGTTestStatus;
    Function PositionWindow(Const Statement : IGTStatement) : TGTTestStatus;
    Function ListWindows(Const Statement : IGTStatement) : TGTTestStatus;
    Function ListAllChildWindows(Const Statement : IGTStatement) : TGTTestStatus;
    Function ListChildWindows(Const Statement : IGTStatement) : TGTTestStatus;
    Function ListTabOrder(Const Statement : IGTStatement) : TGTTestStatus;
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

uses
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.RegularExpressionsCore,
  System.TypInfo,
  System.Math,
  CodeSiteLogging;

ResourceString
  (** A resource string message for not being able to find a window with a specific class name. **)
  strWindowNotFound = 'Window with class name "%s" was not found!';

(**

  This method checks if the child window handle has either a class name or window text that matches
  the given regular expression.

  @precon  lParam must be a pointer to the PGTFindWindowRec record
  @postcon If there is a match the handle, class name and window text are output.

  @nocheck MissingCONSTInParam
  @nometric toxicity

  @param   hWnd   as a HWND
  @param   lParam as a LPARAM
  @return  a BOOL

**)
Function FindChildWindowsCallBack(hWnd : HWND; lParam : LPARAM) : BOOL; StdCall;

Var
  recRegExData : PGTFindWindowRec;

Begin
  Result := True;
  recRegExData := Pointer(lParam);
  If TGTFunctions.Match(recRegExData.FClassName, TGTFunctions.WindowClassName(hWnd)) And 
     TGTFunctions.Match(recRegExData.FWindowText, TGTFunctions.WindowText(hWnd)) Then
    Inc(recRegExData.FCounter);
End;

(**

  This method outputs the child window if a child.

  @precon  lParam must be a pointer to the PGTFindWindowRec record
  @postcon If there is a match the handle, class name and window text are output.

  @nocheck MissingCONSTInParam

  @param   hWnd   as a HWND
  @param   lParam as a LPARAM
  @return  a BOOL

**)
Function ListAllChildWindowCallBack(hWnd : HWND; lParam : LPARAM) : BOOL; StdCall;

Var
  iProcessID : DWORD;
  recChildData : PGTFindWindowRec;

Begin
  Result := True;
  recChildData := Pointer(lParam);
  If GetWindowThreadProcessId(hWnd, iProcessID) = 0 Then
    Exit;
  recChildData.FOutputEvent(TGTFunctions.WindowInfo(hWnd), []);
End;

(**

  This method outputs the child window info if an immediate child of the parent window.

  @precon  lParam must be a pointer to the PGTFindWindowRec record
  @postcon If there is a match the handle, class name and window text are output.

  @nocheck MissingCONSTInParam

  @param   hWnd   as a HWND
  @param   lParam as a LPARAM
  @return  a BOOL

**)
Function ListChildWindowCallBack(hWnd : HWND; lParam : LPARAM) : BOOL; StdCall;

Var
  iProcessID : DWORD;
  recChildData : PGTFindWindowRec;

Begin
  Result := True;
  recChildData := Pointer(lParam);
  If GetWindowThreadProcessId(hWnd, iProcessID) = 0 Then
    Exit;
  If recChildData.FParentWHnd = GetParent(hWnd) Then
    recChildData.FOutputEvent(TGTFunctions.WindowInfo(hWnd), []);
End;

(**

  This method checks if the top level window handle has either a class name or window text that matches
  the given regular expression.

  @precon  lParam must be a pointer to the PGTFindWindowRec record
  @postcon If there is a match the handle, class name and window text are output.

  @nocheck MissingCONSTInParam
  @nometric toxicity

  @param   hWnd   as a HWND
  @param   lParam as a LPARAM
  @return  a BOOL

**)
Function ListWindowCallBack(hWnd : HWND; lParam : LPARAM) : BOOL; StdCall;

Const
  iBufferLen = 1024;

Var
  hProcess : HINST;
  iLen: Integer;
  iProcessID : DWORD;
  recRegExData : PGTFindWindowRec;
  strClassName, strWindowText : String;
  strExecutable : String;

Begin
  Result := True;
  recRegExData := Pointer(lParam);
  strClassName := TGTFunctions.WindowClassName(hWnd);
  strWindowText := TGTFunctions.WindowText(hWnd);
  If TGTFunctions.Match(recRegExData.FClassName, strClassName) Or
     TGTFunctions.Match(recRegExData.FWindowText, strWindowText) Then
    Begin
      If GetWindowThreadProcessId(hWnd, iProcessID) = 0 Then
        Exit;
      strExecutable := StringOfChar(#0, iBufferLen);
      hProcess := OpenProcess(PROCESS_QUERY_INFORMATION Or PROCESS_VM_READ, False, iProcessID);
      Try
        iLen := GetModuleFileName(hProcess, PChar(strExecutable), iBufferLen);
        SetLength(strExecutable, iLen);
        If iLen = 0 Then
          strExecutable := SysErrorMessage(GetLastError);
      Finally
        CloseHandle(hProcess);
      End;
      recRegExData.FOutputEvent(TGTFunctions.WindowInfo(hWNd), []);
    End;
End;

(**

  This method gets the top level window handle for the process ID passed in the lParam record and
  returns the window handle in the same lParam record.

  @precon  lParam must be a pointer to a TGTProcessInfo record.
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

  This method finds the windows with the given window class name and brings it to the front.

  @precon  Statement must be a valid instance.
  @postcon The window  with the given class name it brought to the front.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.BringToFront(Const Statement: IGTStatement): TGTTestStatus;

Var
  iWnd: HWND;

Begin
  FEditorUpdateEvent(Statement.Line, tsRunning);
  iWnd := TGTFunctions.FindWindowByRegEx(Statement.Parameter[0].Text.DeQuotedString);
  If iWnd > 0 Then
    Begin
      Win32Check(BringWindowToTop(iWnd));
      Result := tsSuccessful;
    End Else
    Begin
      Result := tsFailure;
      FLastCommandError(Format(strWindowNotFound, [Statement.Parameter[0].Text.DeQuotedString]));
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
  FExecutable := Statement.Parameter[0].Text;
  boolResult := FileExists(FExecutable);
  If Not boolResult Then
    Raise EGTException.CreateFmt(strExeDoesNotExist, [FExecutable]);
  // Check Directory
  If Statement.ParameterCount >= iSecondParam Then
    Begin
      FDirectory := Statement.Parameter[1].Text;
      boolResult := DirectoryExists(FDirectory);
      If Not boolResult Then
        Raise EGTException.CreateFmt(strDirDoesNotExist, [FDirectory]);
    End Else
      FDirectory := ExtractFilePath(FExecutable);
  // Get the Command Line
  If Statement.ParameterCount = iThirdParam Then
    FCommandLine := Statement.Parameter[iSecondParam].Text;
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
  iResult := WaitForSingleObject(FProcessInfo.hProcess, Statement.Parameter[0].Integer);
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
  FStatements := TCollections.CreateDictionary<TGTStatementType, TGTStatementSignature>;
  FStatements.Add(stLaunch, LaunchCommand);
  FStatements.Add(stWaitForIdle, WaitForIdleCommand);
  FStatements.Add(stSendKeys, SendKeysCommand);
  FStatements.Add(stTestClass, TestClassCommand);
  FStatements.Add(stWaitForWindow, WaitForWindowCommand);
  FStatements.Add(stWait, WaitCommand);
  FStatements.Add(stCheckProcessEnd, CheckProcessEndCommand);
  FStatements.Add(stBringToFront, BringToFront);
  FStatements.Add(stPositionWindow, PositionWindow);
  FStatements.Add(stListWindows, ListWindows);
  FStatements.Add(stListAllChildWindows, ListAllChildWindows);
  FStatements.Add(stListChildWindows, ListChildWindows);
  FStatements.Add(stListTabOrder, ListTabOrder);
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

  This method list all child windows of the window the matches the given regular expression.

  @precon  Statement must be a valid instance.
  @postcon All child windows matching the window matching the regular expression are output.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.ListAllChildWindows(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strOutputtingChildWindows = 'Outputting ALL Child Windows of "%s":';

Var
  iWnd : HWND;
  recChildData : TGTFindWindowRec;
  
Begin
  FEditorUpdateEvent(Statement.Line, tsRunning);
  iWnd := TGTFunctions.FindWindowByRegEx(Statement.Parameter[0].Text);
  FOutputEvent(strOutputtingChildWindows, [TGTFunctions.WindowClassName(iWnd)]);
  recChildData.FParentWHnd := iWnd;
  recChildData.FOutputEvent := FOutputEvent;
  EnumChildWindows(iWnd, @ListAllChildWindowCallBack, LPARAM(@recChildData));
  Result := tsSuccessful;
  FEditorUpdateEvent(Statement.Line, Result);
End;

(**

  This method list immediate child windows of the window the matches the given regular expression.

  @precon  Statement must be a valid instance.
  @postcon Immediate child windows matching the window matching the regular expression are output.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.ListChildWindows(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strOutputtingChildWindows = 'Outputting Immediate Child Windows of "%s":';

Var
  iWnd : HWND;
  recChildData : TGTFindWindowRec;
  
Begin
  FEditorUpdateEvent(Statement.Line, tsRunning);
  iWnd := TGTFunctions.FindWindowByRegEx(Statement.Parameter[0].Text);
  FOutputEvent(strOutputtingChildWindows, [TGTFunctions.WindowClassName(iWnd)]);
  recChildData.FParentWHnd := iWnd;
  recChildData.FOutputEvent := FOutputEvent;
  EnumChildWindows(iWnd, @ListChildWindowCallBack, LPARAM(@recChildData));
  Result := tsSuccessful;
  FEditorUpdateEvent(Statement.Line, Result);
End;

(**

  This method attempts to output the list of child windows in tab order for either top level window or
  child window given in the statement.

  @precon  Statement must be a valid instance.
  @postcon Lists the child windows of the given window(s) in tab order.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.ListTabOrder(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strOutputTabOrder = 'Outputting Tab Order for Windows Matching "%s"';

Const
  iMainWindowIdx = 0;
  iChildWindowIdx = 1;

Var
  iWnd: HWND;
  iFirstCtrlWnd, iCtrlWnd : HWND;
  
Begin
  FEditorUpdateEvent(Statement.Line, tsRunning);
  Try
    iWnd := TGTFunctions.FindWindowByRegEx(Statement.Parameter[iMainWindowIdx].Text);
    If Statement.ParameterCount > iChildWindowIdx Then
      iWnd := TGTFunctions.FindChildWindowByRegEx(iWnd,
        Statement.Parameter[iChildWindowIdx].Text);
    FOutputEvent(strOutputTabOrder, [TGTFunctions.WindowClassName(iWnd)]);
    iCtrlWnd := GetNextDlgTabItem(iWnd, 0, False);
    iFirstCtrlWnd := iCtrlWnd;
    Repeat
      FOutputEvent(TGTFunctions.WindowInfo(iCtrlWnd), []);
      iCtrlWnd := GetNextDlgTabItem(iWnd, iCtrlWnd, False);
    Until iCtrlWnd = iFirstCtrlWnd;
    Result := tsSuccessful;
    FEditorUpdateEvent(Statement.Line, Result);
  Except
    On E : ERegularExpressionError Do
      Raise EGTException.Create(E.Message);
  End;
End;

(**

  This method list all windows with either a class name or window text that matches the given regular
  expression in the statement.

  @precon  Statement must be a valid instance.
  @postcon All top level windows matching the regular expression are output.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.ListWindows(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strOutputTopLvlWnd = 'Outputting Top Level Windows Matching "%s"';

Var
  recRegExData : TGTFindWindowRec;
  
Begin
  FEditorUpdateEvent(Statement.Line, tsRunning);
  Try
    FOutputEvent(strOutputTopLvlWnd, [Statement.Parameter[0].Text]);
    recRegExData.Create(Statement.Parameter[0].Text);
    recRegExData.FOutputEvent := FOutputEvent;
    EnumWindows(@ListWindowCallBack, LPARAM(@recRegExData));
    Result := tsSuccessful;
    FEditorUpdateEvent(Statement.Line, Result);
  Except
    On E : ERegularExpressionError Do
      Raise EGTException.Create(E.Message);
  End;
End;

(**

  This method positions the window with the given window class name.

  @precon  Statement must be a valid instance.
  @postcon If the window is found, it is positioned.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.PositionWindow(Const Statement: IGTStatement): TGTTestStatus;

Const
  iTopParam = 1;
  iLeftParam = 2;
  iWidthParam = 4;
  iHeightParam = 3;

Var
  iWnd: HWND;

Begin
  FEditorUpdateEvent(Statement.Line, tsRunning);
  iWnd := TGTFunctions.FindWindowByRegEx(Statement.Parameter[0].Text);
  If iWnd > 0 Then
    Begin
      Win32Check(MoveWindow(
        iWnd,
        Statement.Parameter[iLeftParam].Integer, // Left
        Statement.Parameter[iTopParam].Integer, // Top
        Statement.Parameter[iWidthParam].Integer, // Width
        Statement.Parameter[iHeightParam].Integer, // Height
        False
      ));
      Result := tsSuccessful;
    End Else
    Begin
      Result := tsFailure;
      FLastCommandError(Format(strWindowNotFound, [Statement.Parameter[0].Text]));
    End;
  FEditorUpdateEvent(Statement.Line, Result);
End;

(**

  This method attempts to run the given statement by looking up the statement type in the list of
  registered statement types.

  @precon  Statement must be a valid instance.
  @postcon The statement is run, else an exception is raised.

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.RunStatement(Const Statement: IGTStatement) : TGTTestStatus;

ResourceString
  strStmtTypeNotImpl = 'Statement type %s not implemented!';

Var
  StatementSign : TGTStatementSignature;
  
Begin
  If FStatements.TryGetValue(Statement.StatementType, StatementSign) Then
    Result := StatementSign(Statement)
  Else
    Raise EGTParserException.CreateFmt(strStmtTypeNotImpl, [
      GetEnumName(TypeInfo(TGTStatementType), Ord(Statement.StatementType))
    ]);
End;

(**

  This method sends a stream of characters to the applications input method.

  @precon  Statement must be a valid instance.
  @postcon The characters are sent to the window.

  @nometric cyclometriccomplexity toxicity

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.SendKeysCommand(Const Statement: IGTStatement): TGTTestStatus;

  (**

    This method returns true of the given Virtual Key requires the extended flag.

    @precon  None.
    @postcon Returns true of the given Virtual Key requires the extended flag.

    @param   iKey as a WORD as a constant
    @return  a Boolean

  **)
  Function RequiresExtended(Const iKey : WORD) : Boolean;

  Const
    aiExtendedVKeys = [VK_RIGHT, VK_LEFT, VK_UP, VK_DOWN, VK_INSERT, VK_DELETE, VK_HOME, VK_END];

  Var
    i : WORD;
    
  Begin
    Result := False;
    For i In aiExtendedVKeys Do
      If i = iKey Then
        Begin
          Result := True;
          Break;
        End;
  End;

  (**

    This procedure performs the sending of the input to the top most window which has input.

    @precon  Msg must be either WM_KEYDOWN and WM_KEYUP.
    @postcon The key is sent to the top most window as input.

    @param   iWnd             as a HWND as a constant
    @param   Msg              as an UINT as a constant
    @param   wParam           as a WPARAM as a constant
    @param   boolIsVirtualKey as a Boolean as a constant

  **)
  Procedure SendKeys(Const iWnd : HWND; Const Msg : UINT; Const wParam : WPARAM;
    Const boolIsVirtualKey : Boolean = False);

  ResourceString
    strDoesNotHaveInput = 'The window "%s" does not have input ("%s" has input)!';

  Var
    Inputs: TInput;

  Begin
    If GetForegroundWindow <> iWnd Then
      Raise EGTException.CreateFmt(strDoesNotHaveInput, [Statement.Parameter[0].Text,
        TGTFunctions.WindowClassName(GetForegroundWindow)]);
    ZeroMemory(@Inputs, SizeOf(Inputs));
    Inputs.Itype := INPUT_KEYBOARD;
    Inputs.ki.wVk := wParam;
    Inputs.ki.wScan := wParam;
    Case Msg Of
      WM_KEYDOWN: Inputs.ki.dwFlags := 0;
      WM_KEYUP:   Inputs.ki.dwFlags := KEYEVENTF_KEYUP;
    End;
    If boolIsVirtualKey Then
      If RequiresExtended(Inputs.ki.wVk) Then
        Inputs.ki.dwFlags := Inputs.ki.dwFlags Or KEYEVENTF_EXTENDEDKEY;
    SendInput(1, Inputs, SizeOf(TInput));
  End;

Const
  strCTRLKey = 'CTRL';
  strSHIFTKey = 'SHIFT';
  strALTKey = 'ALT';
  iLowByte = $00FF;
  iClassNameIdx = 0;
  iExtendedKeysIdx = 1;
  iTextVKeysIdx = 2;
  iWaitTimeIdx = 3;

Var
  i: Integer;
  iWnd : HWND;
  iToken: Integer;
  iResult : Short;
  ShiftStates : TShiftState;
  strText : String;
  P : IGTParameter;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'SendKeysCommand', tmoTiming);{$ENDIF}
  FEditorUpdateEvent(Statement.Line, tsRunning);
  ShiftStates := [];
  iWnd := TGTFunctions.FindWindowByRegEx(Statement.Parameter[iClassNameIdx].Text);
  If iWnd > 0 Then
    Begin
      // Find Shift States - Start at 1 as parameter 0 is the text to output.
      P := Statement.Parameter[iExtendedKeysIdx];
      For iToken := 0 To P.Count - 1 Do
        If CompareText(P.Token[iToken].FText, strCTRLKey) = 0 Then
          Include(ShiftStates, ssCtrl)
        Else If CompareText(P.Token[iToken].FText, strSHIFTKey) = 0 Then
          Include(ShiftStates, ssShift)
        Else If CompareText(P.Token[iToken].FText, strALTKey) = 0 Then
          Include(ShiftStates, ssAlt);
      // Extended keys down
      If ssCtrl In ShiftStates Then
        SendKeys(iWnd, WM_KEYDOWN, VK_CONTROL);
      If ssShift In ShiftStates Then
        SendKeys(iWnd, WM_KEYDOWN, VK_SHIFT);
      If ssAlt In ShiftStates Then
        SendKeys(iWnd, WM_KEYDOWN, VK_MENU);
      // Key strokes
      Case Statement.Parameter[iTextVKeysIdx].TokenType Of
        ttIntegerNumber:
          Begin
            P := Statement.Parameter[iTextVKeysIdx];
            For iToken := 0 To P.Count - 1 Do
              Begin
                iResult := P.Token[iToken].AsInteger;
                SendKeys(iWnd, WM_KEYDOWN, iResult And iLowByte, True);
                SendKeys(iWnd, WM_KEYUP, iResult And iLowByte, True);
              End;
          End
      Else
        strText := Statement.Parameter[iTextVKeysIdx].Text;
        For i := 1 To strText.Length Do
          Begin
            iResult := VkKeyScan(strText[i]);
            If iResult > -1 Then
              Begin
                SendKeys(iWnd, WM_KEYDOWN, iResult And iLowByte);
                SendKeys(iWnd, WM_KEYUP, iResult And iLowByte);
              End;
          End;
      End;
      // Extended keys up
      If ssAlt In ShiftStates Then
        SendKeys(iWnd, WM_KEYUP, VK_MENU);
      If ssShift In ShiftStates Then
        SendKeys(iWnd, WM_KEYUP, VK_SHIFT);
      If ssCtrl In ShiftStates Then
        SendKeys(iWnd, WM_KEYUP, VK_CONTROL);
      Sleep(Statement.Parameter[iWaitTimeIdx].Integer);
      Result := tsSuccessful;
    End Else
    Begin
      Result := tsFailure;
      FLastCommandError(Format(strWindowNotFound, [Statement.Parameter[0].Text]));
    End;
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
    PChar(Format('"%s" %s', [FExecutable, FCommandLine])), {Commandline}
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

  This method counts the number of child windows matching the second parameter of the statement.

  @precon  Statement must be a valid instance.
  @postcon Outputs success if 1 or more windows are found else failure..

  @param   Statement as an IGTStatement as a constant
  @return  a TGTTestStatus

**)
Function TGTParserStatements.TestClassCommand(Const Statement: IGTStatement): TGTTestStatus;

ResourceString
  strFoundChildWindowsMatching = 'Found %d child windows matching "%s->%s"';
  strExpectingCount = 'Expecting a count of %d but found a count of %d!';

Const
  iMainWindowIdx = 0;
  iIntCountIdx = 2;
  iChildWindowIdx = 1;

Var
  iWnd : HWND;
  recRegExData : TGTFindWindowRec;
  
Begin
  FEditorUpdateEvent(Statement.Line, tsRunning);
  iWnd := TGTFunctions.FindWindowByRegEx(Statement.Parameter[iMainWindowIdx].Text);
  Try
    recRegExData.Create(Statement.Parameter[iChildWindowIdx].Text);
    recRegExData.FOutputEvent := FOutputEvent;
    recRegExData.FCounter := 0;
    EnumChildWindows(iWnd, @FindChildWindowsCallBack, LPARAM(@recRegExData));
    If recRegExData.FCounter = Statement.Parameter[iIntCountIdx].Integer Then
      Begin
        Result := tsSuccessful;
        FOutputEvent(strFoundChildWindowsMatching, [
          recRegExData.FCounter,
          Statement.Parameter[iMainWindowIdx].Text,
          Statement.Parameter[iChildWindowIdx].Text
        ])
      End Else
      Begin
        Result := tsFailure;
        FLastCommandError(Format(strExpectingCount, [
          Statement.Parameter[iIntCountIdx].Integer,
          recRegExData.FCounter
        ]));
      End;
    FEditorUpdateEvent(Statement.Line, Result);
  Except
    On E : ERegularExpressionError Do
      Raise EGTException.Create(E.Message);
  End;
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
  Sleep(Statement.Parameter[0].Integer);
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
  iResult := WaitForInputIdle(FProcessInfo.hProcess, Statement.Parameter[0].Integer);
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
    iWnd := TGTFunctions.FindWindowByRegEx(Statement.Parameter[0].Text);
    If iWnd > 0 Then
      GetWindowPlacement(iWnd, WindowPlacement);
    Sleep(iDefaultWaitInterval);
  Until ((iWnd > 0) And (WindowPlacement.showCmd In [SW_NORMAL, SW_MAXIMIZE])) Or
    (GetTickCount64 - iStart > Statement.Parameter[1].Integer);
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

