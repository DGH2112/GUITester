Unit GUITester.Interfaces;

Interface

uses
  System.SysUtils;

Type
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
  End;
  
  IGTParser = Interface
  ['{CAA751B6-BDD4-4658-BF6B-9FB010FC8A3B}']
    // Getter and Setters
    Function  GetLastError : String;
    Function  GetLine : Integer;
    Function  GetColumn : Integer;
    // Methods
    Function Parse(Const strSource : String) : Boolean;
    // Properties
    Property LastError : String Read GetLastError;
    Property Line : Integer Read GetLine;
    Property Column : Integer Read GetColumn;
  End;

  TGTStatementType = (
    stLaunch,
    stWaitForIdle,
    stSendKeys,
    stTestClass,
    stWaitForWindow,
    stWait,
    stCheckProcessEnd
  );

  IGTStatement = Interface
  ['{99029B50-CD45-47DC-ADE1-82971EFBD98B}']
    // Getter and Setters
    Function  GetStatementType : TGTStatementType;
    Function  GetCount : Integer;
    Function  GetLine : Integer;
    Function  GetParameter(Const iIndex : Integer) : TGTToken;
    Function  GetAsString : String;
    // Methods
    Procedure Add(Const Parameter : TGTToken);
    // Properties
    Property StatementType : TGTStatementType Read GetStatementType;
    Property ParameterCount : Integer Read GetCount;
    Property Parameter[Const iIndex : Integer] : TGTToken Read GetParameter; Default;
    Property Line : Integer Read GetLine;
    Property AsString : String Read GetAsString;
  End;

  IGTStatements = Interface
  ['{BEF89536-57F6-46FE-8A66-23106AA69D68}']
    // Getters and Setters
    Function  GetCount : Integer;
    Function  GetStatement(Const iIndex : Integer) : IGTStatement;
    // Methods
    Function  Add(Const eStatementType : TGTStatementType; Const iLine : Integer) : IGTStatement;
    // Properties
    Property Count : Integer Read GetCount;
    Property Statement[Const iIndex  :Integer] : IGTStatement Read GetStatement; Default;
  End;

  EGTException = Class(Exception);
  EGTParserException = Class(EGTException);

Implementation

uses
  System.TypInfo;

Function TGTToken.AsInteger: Integer;

Begin
  Result := FText.ToInteger;
End;

Function TGTToken.AsString(): String;

ResourceString
  strAsStringFmt = 'Text: "%s", Type: %s, Line: %d, Column: %d';

Begin
  Result := Format(strAsStringFmt, [FText,
    GetEnumName(TypeInfo(TGTTokenType), Ord(FTokenType)), FLine, FColumn]);
End;

Constructor TGTToken.Create(Const strText: String; Const eTokenType: TGTTokenType; Const iLine,
  iCOlumn: Integer);
  
Begin
  FText := strText;
  FTokenType := eTokenType;
  FLine := iLine;
  FColumn := iColumn;
End;

Function TGTToken.DeQuoteString: String;

Begin
  Result := FText.DeQuotedString;
End;

End.

