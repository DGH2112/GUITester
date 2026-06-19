(**

  This module contains the interfaces and simple type for use throughout the application.

  @Author  David Hoyle
  @Version 2.196
  @Date    19 Jun 2026

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
Unit GUITester.Interfaces;

Interface

uses
  System.SysUtils;

Type
  (** A enumerate to define the types of token that the parser can interpret. **)
  TGTTokenType = (
    ttUnknown,
    ttKeyword,
    ttIdentifier,
    ttSymbol,
    ttString,
    ttComment,
    ttLineBreak,
    ttWhiteSpace,
    ttIntegerNumber
  );

  (** A record to describe the information required to understand a token within the language. **)
  TGTToken = Record
    FText      : String;
    FTokenType : TGTTokenType;
    FLine      : Integer;
    FColumn    : Integer;
    Constructor Create(Const strText : String; Const eTokenType : TGTTokenType; Const iLine,
      iCOlumn : Integer);
    Function AsString() : String;
    Function DeQuoteString : String;
    Function AsInteger : Integer;
    Function DeQuote() : TGTToken;
  End;
  
  (** An interface to define the attribute of the parser. **)
  IGTParser = Interface
  ['{CAA751B6-BDD4-4658-BF6B-9FB010FC8A3B}']
    // Getter and Setters
    Function  GetLastError : String;
    Function  GetLine : Integer;
    Function  GetColumn : Integer;
    // Methods
    Function Parse(Const strSource : String) : Boolean;
    // Properties
    (**
      This property returns the text of the last error the parser found.
      @precon  None.
      @postcon returns the text of the last error the parser found.
      @return  a String
    **)
    Property LastError : String Read GetLastError;
    (**
      This property returns the line number of the token that caused the last parser error.
      @precon  None.
      @postcon Returns the line number of the token that caused the last parser error.
      @return  an Integer
    **)
    Property Line : Integer Read GetLine;
    (**
      This property returns the column of the token that caused the last parser error.
      @precon  None.
      @postcon Returns the column of the token that caused the last parser error.
      @return  an Integer
    **)
    Property Column : Integer Read GetColumn;
  End;

  (** An enumerate of all the Statements types that the language supports. This may be removed and
      replaced if this list gets too long. *)
  TGTStatementType = (
    stLaunch,
    stWaitForIdle,
    stSendKeys,
    stCheckCount,
    stWaitForWindow,
    stWaitForChildWindow,
    stWait,
    stCheckProcessEnd,
    stBringToFront,
    stPositionWindow,
    stListWindows,
    stListAllChildWindows,
    stListChildWindows,
    stListTabOrder
  );

  (** An interface to define the behaviour of a parameter (single or multiple tokens) **)
  IGTParameter = Interface
  ['{AD95ACC4-030F-4A34-A095-62971573D185}']
    // Getter and Setters
    Function  GetText : String;
    Function  GetInteger : Integer;
    Function  GetTokenType : TGTTokenType;
    Function  GetCount : Integer;
    Function  GetToken(Const iIndex : Integer) : TGTToken;
    // Methods
    // Properties
    (**
      This property returns the text of the first token in the parameter.
      @precon  None.
      @postcon Returns the text of the first token in the parameter.
      @return  a String
    **)
    Property Text : String Read GetText;
    (**
      This property returns the first token converted to an Integer.
      @precon  None.
      @postcon Returns the first token converted to an Integer.
      @return  an Integer
    **)
    Property Integer : Integer Read GetInteger;
    (**
      This property returns the token type of the first token.
      @precon  None.
      @postcon Returns the token type of the first token.
      @return  a TGTTokenType
    **)
    Property TokenType : TGTTokenType Read GetTokenType;
    (**
      This property returns the number of token in the parameter.
      @precon  None.
      @postcon Returns the number of token in the parameter.
      @return  an Integer
    **)
    Property Count : Integer Read GetCount;
    (**
      This property returns the indexed token in the parameter.
      @precon  iIndex must be a valid index between 0 and Count - 1.
      @postcon Returns the indexed token in the parameter.
      @param   iIndex as an Integer as a constant
      @return  a TGTToken
    **)
    Property Token[Const iIndex : Integer] : TGTToken Read GetToken; Default;
  End;

  (** An interface to define the attributes of a statement. **)
  IGTStatement = Interface
  ['{99029B50-CD45-47DC-ADE1-82971EFBD98B}']
    // Getter and Setters
    Function  GetStatementType : TGTStatementType;
    Function  GetParameterCount : Integer;
    Function  GetLine : Integer;
    Function  GetParameter(Const iIndex : Integer) : IGTParameter;
    Function  GetAsString : String;
    // Methods
    Procedure AddParameter(Const Parameter : TGTToken); Overload;
    Procedure AddParameter(Const Parameter : TArray<TGTToken>); Overload;
    // Properties
    (**
      This property returns the statement type associated with the statement.
      @precon  None.
      @postcon Returns the statement type associated with the statement.
      @return  a TGTStatementType
    **)
    Property StatementType : TGTStatementType Read GetStatementType;
    (**
      This property returns the number of parameters that are associated with the statement.
      @precon  None.
      @postcon Returns the number of parameters that are associated with the statement.
      @return  an Integer
    **)
    Property ParameterCount : Integer Read GetParameterCount;
    (**
      This property returns the token representing the indexed parameter.
      @precon  iIndex must be a valid index between 0 and ParameterCount - 1.
      @postcon Returns the token representing the indexed parameter.
      @param   iIndex as an Integer as a constant
      @return  a IGTParameter
    **)
    Property Parameter[Const iIndex : Integer] : IGTParameter Read GetParameter; Default;
    (**
      This property returns the starting line number of the Statement in the editor.
      @precon  None.
      @postcon Returns the starting line number of the Statement in the editor.
      @return  an Integer
    **)
    Property Line : Integer Read GetLine;
    (**
      This property returns a string representation of the statement for debugging output.
      @precon  None.
      @postcon Returns a string representation of the statement for debugging output.
      @return  a String
    **)
    Property AsString : String Read GetAsString;
  End;

  (** An interface to define a collection/list of statements to be processed. **)
  IGTStatements = Interface
  ['{BEF89536-57F6-46FE-8A66-23106AA69D68}']
    // Getters and Setters
    Function  GetCount : Integer;
    Function  GetStatement(Const iIndex : Integer) : IGTStatement;
    // Methods
    Function  Add(Const eStatementType : TGTStatementType; Const iLine : Integer) : IGTStatement;
    // Properties
    (**
      This property returns the number of statements in the collection.
      @precon  None.
      @postcon Returns the number of statements in the collection.
      @return  an Integer
    **)
    Property Count : Integer Read GetCount;
    (**
      This property returns a reference to the indexed statement.
      @precon  iIndex must be a valid index between 0 and Count - 1.
      @postcon Returns a reference to the indexed statement.
      @param   iIndex as an Integer as a constant
      @return  an IGTStatement
    **)
    Property Statement[Const iIndex  :Integer] : IGTStatement Read GetStatement; Default;
  End;

  (** An enumerate to define the status of a statement. **)
  TGTTestStatus = (tsParsed, tsRunning, tsSuccessful, tsFailure);

  (** An interface for the statements that the GUI Tester can execute. **)
  IGTParserStatements = Interface
  ['{EAA95898-3E8E-4264-A627-75034F762CDF}']
    // Getters and Setters
    // Methods
    Function  RunStatement(Const Statement : IGTStatement) : TGTTestStatus;
    // Properties
  End;

  (** A root exception for all exceptions raised by the application. **)
  EGTException = Class(Exception);
  (** An exception raised duration parsing the statements in the editor. **)
  EGTParserException = Class(EGTException);

Implementation

uses
  System.TypInfo;

(**

  This method returns the token as an integer.

  @precon  None.
  @postcon Returns the token as an integer.

  @return  an Integer

**)
Function TGTToken.AsInteger: Integer;

Begin
  Result := FText.ToInteger;
End;

(**

  This method returns a string representation of the token for debugging.

  @precon  None.
  @postcon Returns a string representation of the token for debugging.

  @return  a String

**)
Function TGTToken.AsString(): String;

ResourceString
  strAsStringFmt = '"%s", %s, %d:%d';

Begin
  Result := Format(strAsStringFmt, [FText,
    GetEnumName(TypeInfo(TGTTokenType), Ord(FTokenType)), FLine, FColumn]);
End;

(**

  A constructor for the TGTToken class.

  @precon  None.
  @postcon Initialises the token.

  @param   strText    as a String as a constant
  @param   eTokenType as a TGTTokenType as a constant
  @param   iLine      as an Integer as a constant
  @param   iCOlumn    as an Integer as a constant

**)
Constructor TGTToken.Create(Const strText: String; Const eTokenType: TGTTokenType; Const iLine,
  iCOlumn: Integer);
  
Begin
  FText := strText;
  FTokenType := eTokenType;
  FLine := iLine;
  FColumn := iColumn;
End;

(**

  This method returns a copy of the token with the all quotes removed from the text.

  @precon  None.
  @postcon Returns a copy of the token with the all quotes removed from the text.

  @return  a TGTToken

**)
Function TGTToken.DeQuote: TGTToken;

Begin
  Result.Create(FText.DeQuotedString, FTokenType, FLine, FColumn);
End;

(**

  This method returns the text of the token without starting and ending quotes.

  @precon  None.
  @postcon Returns the text of the token without starting and ending quotes.

  @return  a String

**)
Function TGTToken.DeQuoteString: String;

Begin
  Result := FText.DeQuotedString;
End;

End.

