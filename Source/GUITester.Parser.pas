(**

  This module contains the implementation of the IGTParser interfaces for parsing the statements and
  building a list of statements to execute.

  @Author  David Hoyle
  @Version 3.371
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
Unit GUITester.Parser;

Interface

Uses
  Spring.Collections,
  GUITester.Interfaces;

Type
  (** A class to implement the recursive descent parser. **)
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
    Function  Parse(Const strSource : String) : Boolean;
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
    Procedure CheckSymbol(Const strSymbol : String);
    Procedure CheckInteger();
    Procedure CheckString();
    Function  BringToFront() : Boolean;
    Function  PositionWindow() : Boolean;
    Function  ListWindows() : Boolean;
    Function  ListChildWindows() : Boolean;
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

{.$DEFINE CODESITE}

(**

  This method create a new statement in the statement list and returns a reference to be populated.

  @precon  None.
  @postcon Create a new statement in the statement list and returns a reference to be populated.

  @param   eStatementType as a TGTStatementType as a constant
  @param   iLine          as an Integer as a constant
  @return  an IGTStatement

**)
Function TGTParser.Add(Const eStatementType: TGTStatementType; Const iLine : Integer): IGTStatement;

Begin
  Result := TGTStatement.Create(eStatementType, iLIne);
  FStatements.Add(Result);
End;

(**

  This method parses the BringToFront element of the grammar.

  @precon  None.
  @postcon The bring to front grammar is parses and a statement generated else an exception is raised.

  @return  a Boolean

**)
Function TGTParser.BringToFront: Boolean;

Const
  strBRINGTOFRONT = 'BRINGTOFRONT';

Var
  Statement: IGTStatement;
  T: TGTToken;
  WindowClass: TGTToken;

Begin
  Result := CompareText(strBRINGTOFRONT, Token.FText) = 0;
  If Not Result Then
    Exit;
  T := Token;
  MoveToNextNonCommentToken();
  CheckSymbol('(');
  MoveToNextNonCommentToken();
  CheckString();
  WindowClass := Token();
  MoveToNextNonCommentToken();
  CheckSymbol(')');
  Statement := Add(stBringToFront, T.Fline);
  Statement.AddParameter(WindowClass);
End;

(**

  This method returns a token type enumerate for the given character.

  @precon  None.
  @postcon Returns a token type enumerate for the given character.

  @nometric toxicity nestedIFdepth

  @param   C as a Char as a constant
  @return  a TGTTokenType

**)
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

(**

  This method checks that the current token is an integer else it raises an exception.

  @precon  None.
  @postcon Checks that the current token is as integer else it raises an exception.

**)
Procedure TGTParser.CheckInteger();

ResourceString
  strExpectedIntegerButFound = 'Expected an integer number but found "%s"! [%d:%d]';

Begin
  If Token.FTokenType <> ttIntegerNumber Then
    RaiseParserException(strExpectedIntegerButFound, [Token.FText, Token.FLine, Token.FColumn]);
End;

(**

  This method parses the CHECKPROCESSEND statement in the grammar.

  @precon  None.
  @postcon The grammar for CHECKPROCESSEND is parse and a statement pushed onto the statement list else
           if the parsing fails, a parser exception is raised.

  @return  a Boolean

**)
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
  CheckSymbol('(');
  MoveToNextNonCommentToken();
  CheckInteger();
  WaitTime := Token();
  MoveToNextNonCommentToken();
  CheckSymbol(')');
  Statement := Add(stCheckProcessEnd, T.Fline);
  Statement.AddParameter(WaitTime);
End;

(**

  This method checks that the current token is a string else it raises an exception.

  @precon  None.
  @postcon Checks that the current token is a string else it raises an exception.

**)
Procedure TGTParser.CheckString;

ResourceString
  strExpectedStringButFound = 'Expected a string literal but found "%s"! [%d:%d]';

Begin
  If Token.FTokenType <> ttString Then
    RaiseParserException(strExpectedStringButFound, [Token.FText, Token.FLine,
      Token.FColumn]);
End;

(**

  This method checks that the current token is the same as the given symbol string else it raises an
  exception.

  @precon  None.
  @postcon Checks that the current token is the same as the given symbol string else it raises an
           exception.

  @param   strSymbol as a String as a constant

**)
Procedure TGTParser.CheckSymbol(Const strSymbol : String);

ResourceString
  strExpectedButFound = 'Expected "%s" but found "%s"! [%d:%d]';

Begin
  If CompareText(strSymbol, Token.FText) <> 0 Then
    RaiseParserException(strExpectedButFound, [strSymbol, Token.FText, Token.FLine, Token.FColumn]);
End;

(**

  A constructor for the TGTParser class.

  @precon  None.
  @postcon Creates the Token and Statement lists.

**)
Constructor TGTParser.Create();

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'Create', tmoTiming);{$ENDIF}
  FTokens := TCollections.CreateList<TGTToken>;
  FTokenPos := 1;
  FLine := 1;
  FColumn := 1;
  FStatements := TCollections.CreateList<IGTStatement>;
End;

(**

  A destructor for the TGTParser class.

  @precon  None.
  @postcon Does nothing at the moment.

**)
Destructor TGTParser.Destroy();

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'Destroy', tmoTiming);{$ENDIF}
  Inherited Destroy;
End;

(**

  This method moves to the next token in the stream.

  @precon  None.
  @postcon The token stream moves along by one else a parser exception is raised.

**)
Procedure TGTParser.EatWhiteSpace;

Begin
  GetNextToken;
End;

(**

  This is a getter method for the Column property.

  @precon  None.
  @postcon Returns the column of the last error.

  @return  an Integer

**)
Function TGTParser.GetColumn: Integer;

Begin
  Result := FColumn;
End;

(**

  This is a getter method for the Count property.

  @precon  None.
  @postcon Returns the number of statements in the statement list.
  @return  an Integer

**)
Function TGTParser.GetCount: Integer;

Begin
  Result := FStatements.Count;
End;

(**

  This is a getter method for the Last Error property.

  @precon  None.
  @postcon Returns the error message associated with the last parser error or run-time error.

  @return  a String

**)
Function TGTParser.GetLastError: String;

Begin
  Result := FLastError;
End;

(**

  This is a getter method for the Line property.

  @precon  None.
  @postcon Returns the line number of the last exception.

  @return  an Integer

**)
Function TGTParser.GetLine: Integer;

Begin
  Result := Fline;
End;

(**

  This method parses the current stream position for the next token in the stream of text and puts it on
  the token list else raises a parsing exception.

  @precon  None.
  @postcon Returns the next token in the stream and also adds it to the end of the  token list.

  @nometric cyclometriccomplexity toxicity

  @return  a TGTToken

**)
Function TGTParser.GetNextToken(): TGTToken;

Type
  TGTBlock = (blString, blBraceComment, blSlashComment, blFullComment);
  TGTBlocks = Set of TGTBlock;

  (**

    This procedure switch blocks on and off. Used to understand whether we are in comments, string
    literals, etc.

    @precon  None.
    @postcon The given enumerate is either added or removed from the given set based on whether it was
             there already (toggle).

    @param   setBlocks as a TGTBlocks as a reference
    @param   eBlock    as a TGTBlock as a constant

  **)
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
  cLastChar : Char;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'GetNextToken', tmoTiming);{$ENDIF}
  Result := TGTToken.Create('', ttUnknown, 0, 0);
  If FTokenPos > Length(FSource) Then
    Exit;
  eLastTokenType := CharType(FSource[FTokenPos]);
  cLastChar := #0;
  iLen := 0;
  strToken := StringOfChar(#0, iCAPACITY);
  setBlocks := [];
  Repeat
    // Terminate Slash Comments if we see a #13 charactcer
    If (FSource[FTokenPos] = #13) And (blSlashComment In setBlocks) Then
      Begin
        setBlocks := [];
        eLastTokenType := ttComment;
      End;
    // Terminate Full Comments if we see a *) charactcers
    //If (cLastChar = '*') And (FSource[FTokenPos] = ')') And (blFullComment In setBlocks) Then
    //  Begin
    //    setBlocks := [];
    //    eLastTokenType := ttComment;
    //  End;
    // Get Token Type and BREAK if different
    eTokenType := CharType(FSource[FTokenPos]);
    If (eTokenType <> eLastTokenType) And (setBlocks = []) Then
      Break;
    // String Literals
    If (FSource[FTokenPos] = '''') And ((setBlocks = []) Or (setBlocks = [blString])) Then
      SwitchBlock(setBlocks, blString);
    // Brace Comment
    If CharInSet(FSource[FTokenPos], ['{', '}']) And ((setBlocks = []) Or (setBlocks = [blBraceComment])) Then
      SwitchBlock(setBlocks, blBraceComment);
    // Double Slash Comment
    If (FSource[FTokenPos] = '/') And (cLastChar = '/') And (setBlocks = []) Then
      SwitchBlock(setBlocks, blSlashComment);
    //: Full Comment @BUG DOES NOT WORK AS ( IS A SYMBOL
    //If (FSource[FTokenPos] = '*') And (cLastChar = '(') And (setBlocks = []) Then
    //  SwitchBlock(setBlocks, blFullComment);
    // Add character to Token
    Inc(iLen);
    If iLen > strToken.Length Then
      strToken := strToken + StringOfChar(#0, iCAPACITY);
    strToken[iLen] := FSource[FTokenPos];    
    eLastTokenType := eTokenType;
    cLastChar := strToken[iLen];
    // Increment Line and Column where necessary
    If FSource[FTokenPos] <> #13 Then
      Inc(FColumn);
    If FSource[FTokenPos] = #10 Then
      Begin
        Inc(FLine);
        FColumn := 1;
      End;
    Inc(FTokenPos);
  Until (FTokenPos > FSource.Length) Or ((eLastTokenType = ttSymbol) And (setBlocks = []));
  // Output/Store Token
  SetLength(strToken, iLen);
  Result := TGTToken.Create(strToken, eLastTokenType, FLine, FColumn - strToken.Length);
  FTokens.Add(Result);
End;

(**

  This is a getter method for the Statement property.

  @precon  None.
  @postcon Returns the indexed statement from the list.

  @param   iIndex as an Integer as a constant
  @return  an IGTStatement

**)
Function TGTParser.GetStatement(Const iIndex: Integer): IGTStatement;

Begin
  Result := FStatements[iIndex];
End;

(**

  This method begins the parsing of the source text and captures any parser exceptions.

  @precon  None.
  @postcon The source text is parsed else an parser exceptions are captured.

**)
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

(**

  This method returns true of the current token is in the given array of strings.

  @precon  None.
  @postcon Returns true of the current token is in the given array of strings.

  @param   astrText as a TArray<String> as a constant
  @return  a Boolean

**)
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

(**

  This method parses the LAUNCH statement in the grammar.

  @precon  None.
  @postcon The grammar for LAUNCH is parse and a statement pushed onto the statement list else
           if the parsing fails, a parser exception is raised.

  @return  a Boolean

**)
Function TGTParser.Launch: Boolean;

Const
  strLAUNCH = 'LAUNCH';

Var
  CommandLine: TGTToken;
  Directory : TGTToken;
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
  CheckSymbol('(');
  MoveToNextNonCommentToken();
  CheckString();
  EXEFileName := Token;
  MoveToNextNonCommentToken();
  If Token.FText = ',' Then
    Begin
      MoveToNextNonCommentToken();
      CheckString();
      Directory := Token;
      MoveToNextNonCommentToken();
      If Token.FText = ',' Then
        Begin
          MoveToNextNonCommentToken();
          CheckString();
          CommandLine := Token;
          MoveToNextNonCommentToken();
        End Else
          CommandLine.Create('', ttUnknown, 0, 0);
    End Else
      Directory.Create('', ttUnknown, 0, 0);
  CheckSymbol(')');
  Statement := Add(stLaunch, T.FLine);
  Statement.AddParameter(EXEFileName);
  If Directory.FTokenType = ttString Then
    Statement.AddParameter(Directory);
  If CommandLine.FTokenType = ttString Then
    Statement.AddParameter(CommandLine);
End;

(**

  This method parses the ListChildWindows element of the grammar.

  @precon  None.
  @postcon The lists all the child windows that match the window with the given regular expression.

  @return  a Boolean

**)
Function TGTParser.ListChildWindows: Boolean;

Const
  strLISTCHILDWINDOWS = 'LISTCHILDWINDOWS';

var
  Statement: IGTStatement;
Begin
  Result := CompareText(strLISTCHILDWINDOWS, Token.FText) = 0;
  If Not Result Then
    Exit;
  Statement := Add(stListChildWindows, Token.Fline);
  MoveToNextNonCommentToken();
  CheckSymbol('(');
  MoveToNextNonCommentToken();
  CheckString();
  Statement.AddParameter(Token());
  MoveToNextNonCommentToken();
  CheckSymbol(')');
End;

(**

  This method parses the ListWindows element of the grammar.

  @precon  None.
  @postcon The lists all the top level windows that match the given regular expression.

  @return  a Boolean

**)
Function TGTParser.ListWindows: Boolean;

Const
  strLISTWINDOWS = 'LISTWINDOWS';

Var
  Statement: IGTStatement;
  
Begin
  Result := CompareText(strLISTWINDOWS, Token.FText) = 0;
  If Not Result Then
    Exit;
  Statement := Add(stListWindows, Token.Fline);
  MoveToNextNonCommentToken();
  CheckSymbol('(');
  MoveToNextNonCommentToken();
  CheckString();
  Statement.AddParameter(Token());
  MoveToNextNonCommentToken();
  CheckSymbol(')');
End;

(**

  This method moves to the next non comment token in the stream of text.

  @precon  None.
  @postcon The current token is moved to the next non-comment/whitespace token else a parser exception is
           raised.

**)
Procedure TGTParser.MoveToNextNonCommentToken;

Begin
  // Check for uninitialised token stream
  GetNextToken();
  While (FTokenPos <= FSource.Length) And (Token.FTokenType In [ttComment, ttWhiteSpace, ttLineBreak]) Do
    GetNextToken();
End;

(**

  This method starts the parsing of the given source text.

  @precon  None.
  @postcon The given source is parsed and if there are any issues parser errors are raised.

  @param   strSource as a String as a constant
  @return  a Boolean

**)
Function TGTParser.Parse(Const strSource: String): Boolean;

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'Parse', tmoTiming);{$ENDIF}
  Result := False;
  FSource := strSource;
  Goal();
End;

(**

  This method parses the PositionWindow element of the grammar.

  @precon  None.
  @postcon Find the window and positions with the given coordinates.

  @return  a Boolean

**)
Function TGTParser.PositionWindow: Boolean;

Const
  strPOSITIONWINDOW = 'POSITIONWINDOW';

Var
  Statement: IGTStatement;
  
Begin
  Result := CompareText(strPOSITIONWINDOW, Token.FText) = 0;
  If Not Result Then
    Exit;
  Statement := Add(stPositionWindow, Token().Fline);
  MoveToNextNonCommentToken();
  CheckSymbol('(');
  MoveToNextNonCommentToken();
  // Window Class
  CheckString();
  Statement.AddParameter(Token());
  MoveToNextNonCommentToken();
  CheckSymbol(',');
  MoveToNextNonCommentToken();
  // Top
  CheckInteger();
  Statement.AddParameter(Token());
  MoveToNextNonCommentToken();
  CheckSymbol(',');
  MoveToNextNonCommentToken();
  // Left
  CheckInteger();
  Statement.AddParameter(Token());
  MoveToNextNonCommentToken();
  CheckSymbol(',');
  MoveToNextNonCommentToken();
  // Height
  CheckInteger();
  Statement.AddParameter(Token());
  MoveToNextNonCommentToken();
  CheckSymbol(',');
  MoveToNextNonCommentToken();
  // Width
  CheckInteger();
  Statement.AddParameter(Token());
  MoveToNextNonCommentToken();
  CheckSymbol(')');
End;

(**

  This method raises a parser exception with the given message expanded with the given constant
  arguments.

  @precon  None.
  @postcon A parser exception is raised.

  @param   strMsg as a String as a constant
  @param   Args   as an Array Of Const as a constant

**)
Procedure TGTParser.RaiseParserException(Const strMsg : String; Const Args : Array Of Const);

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'RaiseParserException', tmoTiming);{$ENDIF}
  Raise EGTParserException.CreateFmt(strMsg, Args)
End;

(**

  This method parses the SENDKEYS statement in the grammar.

  @precon  None.
  @postcon The grammar for SENDKEYS is parse and a statement pushed onto the statement list else
           if the parsing fails, a parser exception is raised.

  @return  a Boolean

**)
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
  Statement := Add(stSendKeys, Token().FLine);
  ExtendedKeys := TCollections.CreateList<TGTToken>;
  MoveToNextNonCommentToken();;
  CheckSymbol('(');
  MoveToNextNonCommentToken();
  // Class Name
  CheckString();
  Statement.AddParameter(Token());
  MoveToNextNonCommentToken();
  CheckSymbol(',');
  MoveToNextNonCommentToken();
  // Extended Keys
  CheckSymbol('[');
  MoveToNextNonCommentToken();
  While IsTokenIn(strExtendedKeys) Do
    Begin
      ExtendedKeys.Add(Token);
      MoveToNextNonCommentToken();
      If Token.FText <> ',' Then
        Break;
      MoveToNextNonCommentToken();
    End;
  CheckSymbol(']');
  MoveToNextNonCommentToken();
  CheckSymbol(',');
  MoveToNextNonCommentToken();
  // Text or a Character
  SendKeysString := Token;
  If SendKeysString.FText = '#' Then
    Begin
      MoveToNextNonCommentToken();
      SendKeysString.Create(Char(Token.AsInteger), ttString, Token.FLine, Token.FColumn);
    End Else
      CheckString();
  MoveToNextNonCommentToken();
  CheckSymbol(')');
  Statement.AddParameter(SendKeysString);
  For T In ExtendedKeys Do
    Statement.AddParameter(T);
End;

(**

  This method parses the STAEMENTS statement in the grammar.

  @precon  None.
  @postcon The grammar for STATEMENTS is parse and a statement pushed onto the statement list else
           if the parsing fails, a parser exception is raised.

  @nometric cyclometriccomplexity

**)
Procedure TGTParser.Statements;

ResourceString
  strUnexpectedTokenFound = 'Unexpected Token found "%s"! [%d,%d]';

Begin
  {$IFDEF CODESITE}CodeSite.TraceMethod(Self, 'Statements', tmoTiming);{$ENDIF}
  While (
      Launch() Or
      WaitForIdle() Or
      TestClass() Or
      SendKeys() Or
      WaitForWindow() Or
      Wait() Or
      CheckProcessEnd() Or
      BringToFront() Or
      PositionWindow() Or
      ListWindows() Or
      ListChildWindows()
    ) Do
    Begin
      MoveToNextNonCommentToken();
      CheckSymbol(';');
      MoveToNextNonCommentToken();
    End;
  If FTokenPos <= FSource.Length Then
    Begin
      FLine := Token.FLine;
      FColumn := Token.FColumn;
      RaiseParserException(strUnexpectedTokenFound, [Token.FText, Token.FLine, Token.FColumn]);
    End;
End;

(**

  This method parses the TESTCLASS statement in the grammar.

  @precon  None.
  @postcon The grammar for TESTCLASS is parse and a statement pushed onto the statement list else
           if the parsing fails, a parser exception is raised.

  @return  a Boolean

**)
Function TGTParser.TestClass: Boolean;

Const
  strTestClass = 'TestClass';

Var
  Statement: IGTStatement;

Begin
  Result := CompareText(strTestClass, Token.FText) = 0;
  If Not Result Then
    Exit;
  Statement := Add(stTestClass, Token().FLine);
  MoveToNextNonCommentToken();;
  CheckSymbol('(');
  MoveToNextNonCommentToken();
  CheckString();
  Statement.AddParameter(Token());
  MoveToNextNonCommentToken();
  CheckSymbol(',');
  MoveToNextNonCommentToken();
  CheckString();
  Statement.AddParameter(Token());
  MoveToNextNonCommentToken();
  CheckSymbol(')');
End;

(**

  This method returns the last token in the token list.

  @precon  None.
  @postcon If there are no tokens a parser exception is raised.

  @return  a TGTToken

**)
Function TGTParser.Token: TGTToken;

ResourceString
  strUnexpectedEndFile = 'Unexpected end of file stream!';

Begin
  If FTokens.Count = 0 Then
    RaiseParserException(strUnexpectedEndFile, []);
  Result := FTokens[FTokens.Count - 1];
End;

(**

  This method parses the WAIT statement in the grammar.

  @precon  None.
  @postcon The grammar for WAIT is parse and a statement pushed onto the statement list else
           if the parsing fails, a parser exception is raised.

  @return  a Boolean

**)
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
  CheckSymbol('(');
  MoveToNextNonCommentToken();
  CheckInteger();
  WaitTime := Token();
  MoveToNextNonCommentToken();
  CheckSymbol(')');
  Statement := Add(stWait, T.Fline);
  Statement.AddParameter(WaitTime);
End;

(**

  This method parses the WAITFORIDLE statement in the grammar.

  @precon  None.
  @postcon The grammar for WAITFORIDLE is parse and a statement pushed onto the statement list else
           if the parsing fails, a parser exception is raised.

  @return  a Boolean

**)
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
  CheckSymbol('(');
  MoveToNextNonCommentToken();
  CheckInteger();
  WaitTime := Token();
  MoveToNextNonCommentToken();
  CheckSymbol(')');
  Statement := Add(stWaitForIdle, T.Fline);
  Statement.AddParameter(WaitTime);
End;

(**

  This method parses the WAITFORWINDOW statement in the grammar.

  @precon  None.
  @postcon The grammar for WAITFORWINDOW is parse and a statement pushed onto the statement list else
           if the parsing fails, a parser exception is raised.

  @return  a Boolean

**)
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
  CheckSymbol('(');
  MoveToNextNonCommentToken();
  CheckString();
  WindowClass := Token();
  MoveToNextNonCommentToken();
  CheckSymbol(',');
  MoveToNextNonCommentToken();
  CheckInteger();
  WaitTime := Token();
  MoveToNextNonCommentToken();
  CheckSymbol(')');
  Statement := Add(stWaitForWindow, T.Fline);
  Statement.AddParameter(WindowClass);
  Statement.AddParameter(WaitTime);
End;

End.


