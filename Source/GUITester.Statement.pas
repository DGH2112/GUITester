Unit GUITester.Statement;

Interface

uses
  GUITester.Interfaces,
  Spring.Collections;

Type
  TGTStatement = Class(TInterfacedObject, IGTStatement)
  Strict Private
    FStatementType : TGTStatementType;
    FLine : Integer;
    FParameters    : IList<TGTToken>;
  Strict Protected
    // IGTStatement
    Function  GetStatementType : TGTStatementType;
    Function  GetCount : Integer;
    Function  GetLine : Integer;
    Function  GetParameter(Const iIndex : Integer) : TGTToken;
    Function  GetAsString : String;
    Procedure Add(Const Parameter : TGTToken);
  Public
    Constructor Create(Const eStatementType : TGTStatementType; Const iLine : Integer);
  End;

Implementation

uses
  System.TypInfo,
  System.SysUtils;

Procedure TGTStatement.Add(Const Parameter: TGTToken);

Begin
  FParameters.Add(Parameter);
End;

Constructor TGTStatement.Create(Const eStatementType : TGTStatementType; Const iLine : Integer);

Begin
  FStatementType := eStatementType;
  FLine := iLine;
  FParameters := TCollections.CreateList<TGTToken>;
End;

Function TGTStatement.GetAsString: String;

Var
  i : Integer;
  strParameters : String;
  
Begin
  For i := 0 To GetCount - 1 Do
    Begin
      If strParameters.Length > 0 Then
        strParameters := strParameters + ', ';
      strParameters := strParameters + GetParameter(i).FText;
    End;
  Result := Format('%s(%s)',  [
    GetEnumName(TypeInfo(TGTStatementType), Ord(FStatementType)),
    strParameters
  ]);
End;

Function TGTStatement.GetCount: Integer;

Begin
  Result := FParameters.Count;
End;

Function TGTStatement.GetLine: Integer;

Begin
  Result := FLine;
End;

Function TGTStatement.GetParameter(Const iIndex: Integer): TGTToken;

Begin
  Result := FParameters[iIndex];
End;

Function TGTStatement.GetStatementType: TGTStatementType;

Begin
  Result := FStatementType;
End;

End.

