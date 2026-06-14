(**

  This module contains the implementation of the IGTStatement interfaces for managing the information
  associated with a single statement in the language.

  @Author  David Hoyle
  @Version 1.428
  @Date    14 Jun 2026

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
Unit GUITester.Statement;

Interface

uses
  GUITester.Interfaces,
  Spring.Collections;

Type
  (** A class to implement the IGTStatement interface. **)
  TGTStatement = Class(TInterfacedObject, IGTStatement)
  Strict Private
    FStatementType : TGTStatementType;
    FLine          : Integer;
    FParameters    : IList<IGTParameter>;
  Strict Protected
    // IGTStatement
    Function  GetStatementType : TGTStatementType;
    Function  GetParameterCount : Integer;
    Function  GetLine : Integer;
    Function  GetParameter(Const iIndex : Integer) : IGTParameter;
    Function  GetAsString : String;
    Procedure AddParameter(Const Parameter : TGTToken); Overload;
    Procedure AddParameter(Const Parameter : TArray<TGTToken>); Overload;
  Public
    Constructor Create(Const eStatementType : TGTStatementType; Const iLine : Integer);
  End;

Implementation

uses
  System.TypInfo,
  System.SysUtils,
  GUITester.Parameter;

(**

  This method adds a parameter to the statement consisting of an array of Tokens.

  @precon  None.
  @postcon A parameter is added consisting of an array of tokens.

  @param   Parameter as a TArray<TGTToken> as a constant

**)
Procedure TGTStatement.AddParameter(Const Parameter: TArray<TGTToken>);

Begin
  FParameters.Add(TGTParameter.Create(Parameter));
End;

(**

  This method adds a parameter to the list of parameters associated with the statement.

  @precon  None.
  @postcon The parameter token is added to the end of the list of parameters.

  @param   Parameter as a TGTToken as a constant

**)
Procedure TGTStatement.AddParameter(Const Parameter: TGTToken);

Begin
  FParameters.Add(TGTParameter.Create(Parameter));
End;

(**

  A constructor for the TGTStatement class.

  @precon  None.
  @postcon Initialises the statement.

  @param   eStatementType as a TGTStatementType as a constant
  @param   iLine          as an Integer as a constant

**)
Constructor TGTStatement.Create(Const eStatementType : TGTStatementType; Const iLine : Integer);

Begin
  FStatementType := eStatementType;
  FLine := iLine;
  FParameters := TCollections.CreateList<IGTParameter>;
End;

(**

  This is a getter method for the As String property.

  @precon  None.
  @postcon Returns a string representation of the statement.

  @return  a String

**)
Function TGTStatement.GetAsString: String;

Var
  i : Integer;
  strParameters : String;
  
Begin
  For i := 0 To FParameters.Count - 1 Do
    Begin
      If strParameters.Length > 0 Then
        strParameters := strParameters + ', ';
      strParameters := strParameters + FParameters[i].Text;
    End;
  Result := Format('%s(%s)',  [
    GetEnumName(TypeInfo(TGTStatementType), Ord(FStatementType)),
    strParameters
  ]);
End;

(**

  This is a getter method for the Line property.

  @precon  None.
  @postcon Returns the line number associated with the statement.

  @return  an Integer

**)
Function TGTStatement.GetLine: Integer;

Begin
  Result := FLine;
End;

(**

  This is a getter method for the Parameter property.

  @precon  iIndex must be a valid index between 0 and Count - 1.
  @postcon Returns the indexed parameter from the list.

  @param   iIndex as an Integer as a constant
  @return  a IGTParameter

**)
Function TGTStatement.GetParameter(Const iIndex: Integer): IGTParameter;

Begin
  Result := FParameters[iIndex];
End;

(**

  This is a getter method for the Count property.

  @precon  None.
  @postcon Returns the number of parameters in the statement.

  @return  an Integer

**)
Function TGTStatement.GetParameterCount: Integer;

Begin
  Result := FParameters.Count;
End;

(**

  This is a getter method for the Statement Type property.

  @precon  None.
  @postcon Returns the type associated with the statement.

  @return  a TGTStatementType

**)
Function TGTStatement.GetStatementType: TGTStatementType;

Begin
  Result := FStatementType;
End;

End.

