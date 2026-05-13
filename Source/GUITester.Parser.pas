Unit GUITester.Parser;

Interface

Uses
  Spring.Collections,
  GUITester.Interfaces;

Type
  TGTParser = Class(TInterfacedObject, IGTParser, IGTStatements)
  Strict Private
    FSource     : String;
    FTokenPos   : Integer;
    FTokens     : IList<TGTToken>;
    FLine       : Integer;
    FColumn     : Integer;
    FStatements : IList<IGTStatement>;
    FLastError  : String;
  Strict Protected
    // IGTParser
    Function Parse(Const strSource : String) : Boolean;
    Function  GetLastError : String;
    Function  GetLine : Integer;
    Function  GetColumn : Integer;
    // IGTStatements
    Function  GetCount : Integer;
    Function  GetStatement(Const iIndex : Integer) : IGTStatement;
    Function  Add(Const eStatementType : TGTStatementType; Const iLine : Integer) : IGTStatement;
    // Parser Methods
    Procedure Goal;
    Procedure Statements();
    Function  Statement() : Boolean;
    Function  Launch() : Boolean;
    Function  GetNextToken : TGTToken;
    Function  CharType(Const C : Char) : TGTTokenType;
    Procedure RaiseParserException(Const strMsg : String; Const Args : Array Of Const);
    Procedure EatWhiteSpace();
    Function  WaitForIdle() : Boolean;
    Function  Token : TGTToken;
    Procedure MoveToNextNonCommentToken();
    Function  TestClass() : Boolean;
    Function  SendKeys() : Boolean;
    Function  IsTokenIn(Const astrText : TArray<String>) : Boolean;
    Function  WaitForWindow() : Boolean;
    Function  Wait() : Boolean;
    Function  CheckProcessEnd() : Boolean;
  Public
    Constructor Create();
    Destructor Destroy(); Override;
  End;

Implementation

uses
  System.SysUtils,
  System.TypInfo,
  CodeSiteLogging,
  GUITester.Statement;

ResourceString
  strExpectedButFound = 'Expected "%s" but found "%s"! [%d:%d]';
  strExpectedStringButFound = 'Expected a string literal but found "%s"! [%d:%d]';
  strExpectedIntegerButFound = 'Expected an integer number but found "%s"! [%d:%d]';
  strUnexpectedEndFile = 'Unexpected end of file stream!';
  strUnexpectedTokenFound = 'Unexpected Token found "%s"! [%d,%d]';

{.$DEFINE CODESITE}

Function TGTParser.Add(Const eStatementType: TGTStatementType; Const iLine : Integer): IGTStatement;

Begin
  Result := TGTStatement.Create(eStatementType, iLIne);
  FStatements.Add(Result);
End;

//: @nometric toxicity nestedifdepth
Function TGTParser.CharType(Const C: Char): TGTTokenType;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'CharType', tmoTiming);{$ENDIF}
  If CharInSet(C, ['a'..'z', 'A'..'Z', '_']) Then
    Result := ttIdentifier
  Else If CharInSet(C, ['(', ')', ':', '=', ',', '[', ']', ';', '#']) Then
    Result := ttSymbol
  Else If CharInSet(C, ['''']) Then
    Result := ttString
  Else If CharInSet(C, ['{', '}']) Then
    Result := ttComment
  Else If CharInSet(C, [#10, #13]) Then
    Result := ttLineBreak
  Else If CharInSet(C, [#9, #32]) Then
    Result := ttWhiteSpace
  Else If CharInSet(C, ['0'..'9']) Then
    Result := ttIntegerNumber
  Else
    Result := ttUnknown;
End;

Function TGTParser.CheckProcessEnd: Boolean;

Const
  strCHECKPROCESSEND = 'CHECKPROCESSEND';

var
  Statement: IGTStatement;
  T: TGTToken;
  WaitTime: TGTToken;
Begin
  Result := CompareText(strCHECKPROCESSEND, Token.FText) = 0;
  If Not Result Then
    Exit;
  T := Token;
  MoveToNextNonCommentToken();
  If CompareText('(', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, ['(', Token.FText, Token.FLine, Token.FColumn]);
  MoveToNextNonCommentToken();
  WaitTime := Token();
  If WaitTime.FTokenType <> ttIntegerNumber Then
    RaiseParserException(strExpectedIntegerButFound, [WaitTime.FText, WaitTime.FLine, WaitTime.FColumn]);
  MoveToNextNonCommentToken();
  If CompareText(')', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, [')', Token.FText, Token.FLine, Token.FColumn]);
  Statement := Add(stCheckProcessEnd, T.Fline);
  Statement.Add(WaitTime);
End;

Constructor TGTParser.Create();

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'Create', tmoTiming);{$ENDIF}
  FTokens := TCollections.CreateList<TGTToken>;
  FTokenPos := 1;
  FLine := 1;
  FColumn := 1;
  FStatements := TCollections.CreateList<IGTStatement>;
End;

Destructor TGTParser.Destroy();

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'Destroy', tmoTiming);{$ENDIF}
  Inherited Destroy;
End;

Procedure TGTParser.EatWhiteSpace;

Begin
  GetNextToken;
End;

Function TGTParser.GetColumn: Integer;

Begin
  Result := FColumn;
End;

Function TGTParser.GetCount: Integer;

Begin
  Result := FStatements.Count;
End;

Function TGTParser.GetLastError: String;

Begin
  Result := FLastError;
End;

Function TGTParser.GetLine: Integer;

Begin
  Result := Fline;
End;

//: @nometric cyclometriccomplexity
Function TGTParser.GetNextToken(): TGTToken;

Type
  TGTBlock = (blString, blComment);
  TGTBlocks = Set of TGTBlock;

  Procedure SwitchBlock(Var setBlocks : TGTBlocks; Const eBlock : TGTBlock);

  Begin
    If eBlock In setBlocks Then
      Exclude(setBlocks, eBlock)
    Else
      Include(setBlocks, eBlock);
  End;

Const
  iCAPACITY = 50;

Var
  iLen : Integer;
  eTokenType : TGTTokenType;
  eLastTokenType : TGTTokenType;
  setBlocks : TGTBlocks;
  strToken : String;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'GetNextToken', tmoTiming);{$ENDIF}
  Result := TGTToken.Create('', ttUnknown, 0, 0);
  If FTokenPos > Length(FSource) Then
    Exit;
  eLastTokenType := CharType(FSource[FTokenPos]);
  iLen := 0;
  strToken := StringOfChar(#0, iCAPACITY);
  setBlocks := [];
  Repeat
    eTokenType := CharType(FSource[FTokenPos]);
    If (eTokenType <> eLastTokenType) And (setBlocks = []) Then
      Break;
    If (FSource[FTokenPos] = '''') And (setBlocks * [blComment] = []) Then
      SwitchBlock(setBlocks, blString);
    If CharInSet(FSource[FTokenPos], ['{', '}']) And (setBlocks * [blString] = []) Then
      SwitchBlock(setBlocks, blComment);
    Inc(iLen);
    If iLen > strToken.Length Then
      strToken := strToken + StringOfChar(#0, iCAPACITY);
    strToken[iLen] := FSource[FTokenPos];    
    eLastTokenType := eTokenType;
    If FSource[FTokenPos] <> #13 Then
      Inc(FColumn);
    If FSource[FTokenPos] = #10 Then
      Begin
        Inc(FLine);
        FColumn := 1;
      End;
    Inc(FTokenPos);
  Until (FTokenPos > FSource.Length) Or ((eLastTokenType = ttSymbol) And (setBlocks = []));
  SetLength(strToken, iLen);
  Result := TGTToken.Create(strToken, eLastTokenType, FLine, FColumn - strToken.Length);
  FTokens.Add(Result);
End;

Function TGTParser.GetStatement(Const iIndex: Integer): IGTStatement;

Begin
  Result := FStatements[iIndex];
End;

Procedure TGTParser.Goal();

ResourceString
  strParsingFailed = 'Parsing Failed';

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'Goal', tmoTiming);{$ENDIF}
  Try
    MoveToNextNonCommentToken();
    Statements();
  Except
    On E : EGTParserException Do
      Begin
        FLastError := E.Message;
        CodeSite.Send(csmError, strParsingFailed, FLastError);
      End;
  End;
End;

Function TGTParser.IsTokenIn(Const astrText: TArray<String>): Boolean;

Var 
  strText : String;
  
Begin
  Result := False;
  For strText In astrText Do
    If CompareText(Token.FText, strText) = 0 Then
      Begin
        Result := True;
        Break;
      End;
End;

Function TGTParser.Launch: Boolean;

Const
  strLAUNCH = 'LAUNCH';

Var
  CommandLine: TGTToken;
  EXEFileName : TGTToken;
  Statement : IGTStatement;
  T: TGTToken;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'Launch', tmoTiming);{$ENDIF}
  Result := CompareText(strLAUNCH, Token.FText) = 0;
  If Not Result Then
    Exit;
  T := Token;
  MoveToNextNonCommentToken();;
  If CompareText('(', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, ['(', Token.FText, Token.FLine, Token.FColumn]);
  MoveToNextNonCommentToken();
  EXEFileName := Token;
  If EXEFileName.FTokenType <> ttString Then
    RaiseParserException(strExpectedStringButFound, [EXEFileName.FText, EXEFileName.FLine,
      EXEFileName.FColumn]);
  MoveToNextNonCommentToken();
  If Token.FText = ',' Then
    Begin
      MoveToNextNonCommentToken();
      CommandLine := Token;
      If Commandline.FTokenType <> ttString Then
        RaiseParserException(strExpectedStringButFound, [Commandline.FText, Commandline.FLine,
          Commandline.FColumn]);
      MoveToNextNonCommentToken();
    End Else
      CommandLine.Create('', ttUnknown, 0, 0);
  If CompareText(')', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, [')', Token.FText, Token.FLine, Token.FColumn]);
  Statement := Add(stLaunch, T.FLine);
  Statement.Add(EXEFileName);
  If CommandLine.FTokenType = ttString Then
    Statement.Add(CommandLine);
End;

Procedure TGTParser.MoveToNextNonCommentToken;

Begin
  // Check for uninitialised token stream
  GetNextToken();
  While (FTokenPos <= FSource.Length) And (Token.FTokenType In [ttComment, ttWhiteSpace, ttLineBreak]) Do
    GetNextToken();
End;

Function TGTParser.Parse(Const strSource: String): Boolean;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'Parse', tmoTiming);{$ENDIF}
  Result := False;
  FSource := strSource;
  Goal();
End;

Procedure TGTParser.RaiseParserException(Const strMsg : String; Const Args : Array Of Const);

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'RaiseParserException', tmoTiming);{$ENDIF}
  Raise EGTParserException.CreateFmt(strMsg, Args)
End;

//: @nometric toxicity
Function TGTParser.SendKeys: Boolean;

Const
  strSENDKEYS = 'SENDKEYS';
  strExtendedKeys : TArray<String> = [ 'ALT', 'CTRL', 'SHIFT' ];

Var
  SendKeysString: TGTToken;
  Statement: IGTStatement;
  ExtendedKeys : IList<TGTToken>;
  T: TGTToken;

Begin
  Result := CompareText(strSENDKEYS, Token.FText) = 0;
  If Not Result Then
    Exit;
  T := Token;
  ExtendedKeys := TCollections.CreateList<TGTToken>;
  MoveToNextNonCommentToken();;
  If CompareText('(', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, ['(', Token.FText, Token.FLine, Token.FColumn]);
  MoveToNextNonCommentToken();
  If CompareText('[', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, ['[', Token.FText, Token.FLine, Token.FColumn]);
  MoveToNextNonCommentToken();
  While IsTokenIn(strExtendedKeys) Do
    Begin
      ExtendedKeys.Add(Token);
      MoveToNextNonCommentToken();
      If Token.FText <> ',' Then
        Break;
      MoveToNextNonCommentToken();
    End;
  If CompareText(']', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, [']', Token.FText, Token.FLine, Token.FColumn]);
  MoveToNextNonCommentToken();
  If CompareText(',', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, [',', Token.FText, Token.FLine, Token.FColumn]);
  MoveToNextNonCommentToken();
  SendKeysString := Token;
  If SendKeysString.FText = '#' Then
    Begin
      MoveToNextNonCommentToken();
      SendKeysString.Create(Char(Token.AsInteger), ttString, Token.FLine, Token.FColumn);
    End;
  If SendKeysString.FTokenType <> ttString Then
    RaiseParserException(strExpectedStringButFound, [SendKeysString.FText, SendKeysString.FLine,
      SendKeysString.FColumn]);
  MoveToNextNonCommentToken();
  If CompareText(')', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, [')', Token.FText, Token.FLine, Token.FColumn]);
  Statement := Add(stSendKeys, T.FLine);
  Statement.Add(SendKeysString);
  For T In ExtendedKeys Do
    Statement.Add(T);
End;

Function TGTParser.Statement: Boolean;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'Statement', tmoTiming);{$ENDIF}
  Result := Launch;
End;

Procedure TGTParser.Statements;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'Statements', tmoTiming);{$ENDIF}
  While Statement() Or WaitForIdle() Or TestClass() Or SendKeys() Or WaitForWindow() Or Wait() Or
    CheckProcessEnd() Do
    Begin
      MoveToNextNonCommentToken();
      If Comparetext(';', Token.FText) <> 0 Then
        RaiseParserException(strExpectedButFound, [';', Token.FText, Token.FLine, Token.FColumn]);
      MoveToNextNonCommentToken();
    End;
  If FTokenPos <= FSource.Length Then
    Begin
      FLine := Token.FLine;
      FColumn := Token.FColumn;
      RaiseParserException(strUnexpectedTokenFound, [Token.FText, Token.FLine, Token.FColumn]);
    End;
End;

Function TGTParser.TestClass: Boolean;

Const
  strTestClass = 'TestClass';

Var
  ClassName: TGTToken;
  Statement: IGTStatement;
  T: TGTToken;

Begin
  Result := CompareText(strTestClass, Token.FText) = 0;
  If Not Result Then
    Exit;
  T := Token;
  MoveToNextNonCommentToken();;
  If CompareText('(', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, ['(', Token.FText, Token.FLine, Token.FColumn]);
  MoveToNextNonCommentToken();
  ClassName := Token;
  If ClassName.FTokenType <> ttString Then
    RaiseParserException(strExpectedStringButFound, [ClassName.FText, ClassName.FLine,
      ClassName.FColumn]);
  MoveToNextNonCommentToken();
  If CompareText(')', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, [')', Token.FText, Token.FLine, Token.FColumn]);
  Statement := Add(stTestClass, T.FLine);
  Statement.Add(ClassName);
End;

Function TGTParser.Token: TGTToken;

Begin
  If FTokens.Count = 0 Then
    RaiseParserException(strUnexpectedEndFile, []);
  Result := FTokens[FTokens.Count - 1];
End;

Function TGTParser.Wait: Boolean;

Const
  strWAIT = 'WAIT';

Var
  Statement: IGTStatement;
  T: TGTToken;
  WaitTime: TGTToken;

Begin
  Result := CompareText(strWAIT, Token.FText) = 0;
  If Not Result Then
    Exit;
  T := Token;
  MoveToNextNonCommentToken();
  If CompareText('(', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, ['(', Token.FText, Token.FLine, Token.FColumn]);
  MoveToNextNonCommentToken();
  WaitTime := Token();
  If WaitTime.FTokenType <> ttIntegerNumber Then
    RaiseParserException(strExpectedIntegerButFound, [WaitTime.FText, WaitTime.FLine, WaitTime.FColumn]);
  MoveToNextNonCommentToken();
  If CompareText(')', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, [')', Token.FText, Token.FLine, Token.FColumn]);
  Statement := Add(stWait, T.Fline);
  Statement.Add(WaitTime);
End;

Function TGTParser.WaitForIdle: Boolean;

Const
  strWAITFORIDLE = 'WAITFORIDLE';

Var
  Statement: IGTStatement;
  T: TGTToken;
  WaitTime: TGTToken;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'WaitForIdle', tmoTiming);{$ENDIF}
  Result := CompareText(strWAITFORIDLE, Token.FText) = 0;
  If Not Result Then
    Exit;
  T := Token;
  MoveToNextNonCommentToken();
  If CompareText('(', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, ['(', Token.FText, Token.FLine, Token.FColumn]);
  MoveToNextNonCommentToken();
  WaitTime := Token();
  If WaitTime.FTokenType <> ttIntegerNumber Then
    RaiseParserException(strExpectedIntegerButFound, [WaitTime.FText, WaitTime.FLine, WaitTime.FColumn]);
  MoveToNextNonCommentToken();
  If CompareText(')', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, [')', Token.FText, Token.FLine, Token.FColumn]);
  Statement := Add(stWaitForIdle, T.Fline);
  Statement.Add(WaitTime);
End;

Function TGTParser.WaitForWindow: Boolean;

Const
  strWAITFORWINDOW = 'WAITFORWINDOW';

var
  Statement: IGTStatement;
  T: TGTToken;
  WaitTime: TGTToken;
  WindowClass: TGTToken;
  
Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'WaitForWindow', tmoTiming);{$ENDIF}
  Result := CompareText(strWAITFORWINDOW, Token.FText) = 0;
  If Not Result Then
    Exit;
  T := Token;
  MoveToNextNonCommentToken();
  If CompareText('(', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, ['(', Token.FText, Token.FLine, Token.FColumn]);
  MoveToNextNonCommentToken();
  WindowClass := Token();
  If WindowClass.FTokenType <> ttString Then
    RaiseParserException(strExpectedStringButFound, [WindowClass.FText, WindowClass.FLine,
      WindowClass.FColumn]);
  MoveToNextNonCommentToken();
  If CompareText(',', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, [',', Token.FText, Token.FLine, Token.FColumn]);
  MoveToNextNonCommentToken();
  WaitTime := Token();
  If WaitTime.FTokenType <> ttIntegerNumber Then
    RaiseParserException(strExpectedIntegerButFound, [WaitTime.FText, WaitTime.FLine, WaitTime.FColumn]);
  MoveToNextNonCommentToken();
  If CompareText(')', Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, [')', Token.FText, Token.FLine, Token.FColumn]);
  Statement := Add(stWaitForWindow, T.Fline);
  Statement.Add(WindowClass);
  Statement.Add(WaitTime);
End;

End.


