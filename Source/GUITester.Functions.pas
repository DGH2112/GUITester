(**
  
  This module contains a record to encapsulate methods that call windows API functions where the data
  is converted to Object Pascal types.

  @Version 2.894
  @Author  David Hoyle
  @Date    14 Jun 2026
  
**)
Unit GUITester.Functions;

Interface

Uses
  System.RegularExpressions,
  WinApi.Windows;

Type
  (** A record to encapsulate functions that wrap windows functions and convert them to simple Object
      Pascal methods. **)
  TGTFunctions = Record
  Strict Private
  Public
    Class Function WindowClassName(Const wHnd: THandle): String; Static;
    Class Function WindowText(Const wHnd: THandle): String; Static;
    Class Function WindowModule(Const wHnd : HWND) : String; Static;
    Class Function FindWindowByRegEx(Const strRegExText : String) : HWND; Static;
    Class Function FindChildWindowByRegEx(Const iWnd : HWND; Const strRegExText : String) : HWND; Static;
    Class Function WindowInfo(Const hWNd : HWND) : String; Static;
    Class Function Match(Const RegEx : TRegEx; Const strText : String) : Boolean; Static;
  End;

  (** An event signature for outputting event information to the main application. **)
  TGTOutputEvent = Procedure(Const strMsg : String; Const Args : Array Of Const) Of Object;

  (** A record to allow the passing of regular expressions to the call back methods for the
      FindWindowByRegEx method. **)
  TGTFindWindowRec = Record
    FClassName   : TRegEx;
    FWindowText  : TRegEx;
    FWindowHnd   : HWND;
    FCounter     : Integer;
    FOutputEvent : TGTOutputEvent;
    FParentWHnd  : HWND;
    Constructor Create(Const strClassNameWindowTextRegEx : String);
  End;
  (** A pointer to the above record. **)
  PGTFindWindowRec = ^TGTFindWindowRec;

Implementation

uses
  Winapi.PsAPI,
  System.RegularExpressionsCore,
  System.SysUtils,
  GUITester.Interfaces;

(**

  This method is called for each top level window and test whether the window matches the given
  class name and window text regular expressions. If so the window handle is set and the function returns
  false to stop the iterations.

  @precon  lParam
  @postcon If the window is found its handle is returns in the record passed via the lParam.

  @nocheck MissingCONSTInParam

  @param   hWnd   as a HWND
  @param   lParam as a LPARAM
  @return  a BOOL

**)
Function FindWindowByRegExCallBack(hWnd : HWND; lParam : LPARAM) : BOOL; StdCall;

Var
  recFindWindow : PGTFindWindowRec;
  strClassName : String;
  strWindowText : String;

Begin
  Result := True;
  recFindWindow := Pointer(lParam);
  strClassName := TGTFunctions.WindowClassName(hWnd);
  strWindowtext := TGTFunctions.WindowText(hWnd);
  If TGTFunctions.Match(recFindWindow.FClassName, strClassName) Then
    If TGTFunctions.Match(recFindWindow.FWindowText, strWindowText) Then
      Begin
        recFindWindow.FWindowHnd := hWnd;
        Result := False;
      End;
End;

Constructor TGTFindWindowRec.Create(Const strClassNameWindowTextRegEx: String);

ResourceString
  strCannotBeEmpty = 'The regular expression cannot be empty!';
  strClassNameCannotBeEmpty = 'The Class Name regular expression cannot be empty!';
  strWindowTextCannotBeEmpty = 'The Window Text regular expression cannot be empty!';

Const
  iClassNameIdx = 1;
  iWindowTextIdx = 2;

Var
  RE : TRegEx;
  M : TMatch;
  
Begin
  If strClassNameWindowTextRegEx.Length = 0 Then
    Raise EGTException.Create(strCannotBeEmpty);
  RE := TRegEx.Create('(?<!&)&(?!&)', [roIgnoreCase, roCompiled, roSingleLine]);
  M := RE.Match(strClassNameWindowTextRegEx);
  If M.Success Then
    Begin
      If M.Groups[iClassNameIdx].Value.Length = 0 Then
        Raise EGTException.Create(strClassNameCannotBeEmpty);
      FClassName := TRegEx.Create(M.Groups[iClassNameIdx].Value,
        [roIgnoreCase, roCompiled, roSingleLine]);
      If M.Groups[iWindowTextIdx].Value.Length = 0 Then
        Raise EGTException.Create(strWindowTextCannotBeEmpty);
      FWindowText := TRegEx.Create(M.Groups[iWindowTextIdx].Value,
        [roIgnoreCase, roCompiled, roSingleLine]);
    End Else
    Begin
      FClassName := TRegEx.Create(
        StringReplace(strClassNameWindowTextRegEx, '&&', '&', [rfReplaceAll]),
        [roIgnoreCase, roCompiled, roSingleLine]);
      FWindowText := TRegEx.Create('.', [roIgnoreCase, roCompiled, roSingleLine]);
    End;
  FWindowHnd := 0;
  FCounter := 0;
  FOutputEvent := Nil;
  FParentWHnd := 0;
End;

(**

  This method attempts to find a child level window of the given window handle that matches the class 
  name and window text regular expressions passed.

  @precon  None.
  @postcon The window handle is returned if found else an exception is raised.

  @param   iWnd         as a HWND as a constant
  @param   strRegExText as a String as a constant
  @return  a HWND

**)
Class Function TGTFunctions.FindChildWindowByRegEx(Const iWnd : HWND; Const strRegExText : String): HWND;

ResourceString
  strFindChildWindowByRegExFailed = 'FindChildWindowByRegEx failed (%d, %s)';

Var
  recFindWindow : TGTFindWindowRec;
  
Begin
  Try
    recFindWindow.Create(strRegExText);
    recFindWindow.FWindowHnd := 0;
    EnumChildWindows(iWnd, @FindWindowByRegExCallBack, LPARAM(@recFindWindow));
    Result := recFindWindow.FWindowHnd;
    If Result = 0 Then
      Raise EGTException.CreateFmt(strFindChildWindowByRegExFailed, [iWnd, strRegExText]);
  Except
    On E : ERegularExpressionError Do
      Raise EGTException.Create(E.Message);
  End;
End;

(**

  This method attempts to find a top level window that matches the class name and window text regular 
  expressions passed.

  @precon  None.
  @postcon The window handle is returned if found else an exception is raised.

  @param   strRegExText as a String as a constant
  @return  a HWND

**)
Class Function TGTFunctions.FindWindowByRegEx(Const strRegExText : String): HWND;

ResourceString
  strFindWindowByRegExFailed = 'FindWindowByRegEx failed (%s)';

Var
  recFindWindow : TGTFindWindowRec;
  
Begin
  Try
    recFindWindow.Create(strRegExText);
    recFindWindow.FWindowHnd := 0;
    EnumWindows(@FindWindowByRegExCallBack, LPARAM(@recFindWindow));
    Result := recFindWindow.FWindowHnd;
    If Result = 0 Then
      Raise EGTException.CreateFmt(strFindWindowByRegExFailed, [strRegExText]);
  Except
    On E : ERegularExpressionError Do
      Raise EGTException.Create(E.Message);
  End;
End;

(**

  This method returns true if the given text is not null and matches the regular expression or the given
  text is null (no match can be performed).

  @precon  RegEx must be a valid Regular Expression.
  @postcon If there is a match or the text is empty, true is returned.

  @param   RegEx   as a TRegEx as a constant
  @param   strText as a String as a constant
  @return  a Boolean

**)
Class Function TGTFunctions.Match(Const RegEx: TRegEx; Const strText: String): Boolean;

Begin
  Result := (
    ((strText.Length > 0) And RegEx.IsMatch(strText)) Or
    (strText.Length = 0)
    );
End;

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

  This method returns a formatted string containing the given Window Handle, the windows Class Name,
  Window text and Module Name.

  @precon  None.
  @postcon A formatted string is returned containing the handle, class Name, Window Text and Module Name.

  @param   hWNd as a HWND as a constant
  @return  a String

**)
Class Function TGTFunctions.WindowInfo(Const hWNd: HWND): String;

ResourceString
  strHndClassTextBinary = '  Handle: %1.0n, Class: "%s", Text: "%s", Binary: "%s"';

Begin
  Result := Format(
    strHndClassTextBinary,
    [
      Int(hWnd),
      WindowClassName(hWnd),
      WindowText(hWnd),
      WindowModule(hWnd)
    ]
  )
End;

(**

  This methods returns the module name for the given windows handle.

  @precon  None.
  @postcon The module name of the given windows handle is returned.

  @param   wHnd as a HWND as a constant
  @return  a String

**)
Class Function TGTFunctions.WindowModule(Const wHnd: HWND): String;

Var
  iLen: Integer;
  hProcess : HWND;
  iProcessID : DWORD;

Begin
  GetWindowThreadProcessId(wHnd, @iProcessID);
  hProcess := OpenProcess(PROCESS_QUERY_INFORMATION Or PROCESS_VM_READ, False, iProcessID);
  Try
    Result := StringOfChar(#0, MAX_PATH);
    iLen := GetModuleFileNameEx(hProcess, 0, PChar(Result), MAX_PATH);
    SetLength(Result, iLen);
    If iLen = 0 Then
      Result := SysErrorMessage(GetLastError);
  Finally
    CloseHandle(hProcess);
  End;
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

End.

