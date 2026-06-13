(**
  
  This module contains a record to encapsulate methods that call windows API functions where the data
  is converted to Object Pascal types.

  @Version 1.636
  @Author  David Hoyle
  @Date    06 Jun 2026
  
**)
Unit GUITester.Functions;

Interface

Uses
  WinApi.Windows;

Type
  (** A record to encapsulate functions that wrap windows functions and convert them to simple Object
      Pascal methods. **)
  TGTFunctions = Record
  Strict Private
  Public
    Class Function WindowClassName(Const wHnd: THandle): String; Static;
    Class Function WindowText(Const wHnd: THandle): String; Static;
    Class Function FindWindowByRegEx(Const strClassName, strWindowText : String) : HWND; Static;
    Class Function WindowModule(Const wHnd : HWND) : String; Static;
    Class Function WindowInfo(Const hWNd : HWND) : String; Static;
  End;

Implementation

uses
  System.RegularExpressions,
  System.RegularExpressionsCore,
  System.SysUtils,
  GUITester.Interfaces;

Type
  (** A record to allow the passing of regular expressions to the call back methods for the
      FindWindowByRegEx method. **)
  TGTFindWindowRec = Record
    FClassName  : TRegEx;
    FWindowText : TRegEx;
    FWindowHnd  : HWND;
  End;
  (** A pointer to the above record. **)
  PGTFindWindowRec = ^TGTFindWindowRec;

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
  If recFindWindow.FClassName.IsMatch(strClassName) And
     recFindWindow.FWindowText.IsMatch(strWindowText) Then
    Begin
      recFindWindow.FWindowHnd := hWnd;
      Result := False;
    End;
End;

(**

  This method attempts to find a top level window that matches the class name and window text regular
  expressions passed.

  @precon  None.
  @postcon The window handle is returned if found else an exception is raised.

  @param   strClassName  as a String as a constant
  @param   strWindowText as a String as a constant
  @return  a HWND

**)
Class Function TGTFunctions.FindWindowByRegEx(Const strClassName, strWindowText: String): HWND;

ResourceString
  strFindWindowByRegExFailed = 'FindWindowByRegEx failed (%s, %s)';

Var
  recFindWindow : TGTFindWindowRec;
  
Begin
  Try
    If strClassName.Length > 0 Then
      recFindWindow.FClassName := TRegEx.Create(strClassName, [roIgnoreCase, roSingleLine, roCompiled])
    Else
      recFindWindow.FClassName := TRegEx.Create('.', [roIgnoreCase, roSingleLine, roCompiled]);
    If strWindowText.Length > 0 Then
      recFindWindow.FWindowText := TRegEx.Create(strWindowText, [roIgnoreCase, roSingleLine, roCompiled])
    Else
      recFindWindow.FWindowText := TRegEx.Create('.', [roIgnoreCase, roSingleLine, roCompiled]);
    recFindWindow.FWindowHnd := 0;
    EnumWindows(@FindWindowByRegExCallBack, LPARAM(@recFindWindow));
    Result := recFindWindow.FWindowHnd;
    If Result = 0 Then
      Raise EGTException.CreateFmt(strFindWindowByRegExFailed, [strClassName, strWindowText]);
  Except
    On E : ERegularExpressionError Do
      Raise EGTException.Create(E.Message);
  End;
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

