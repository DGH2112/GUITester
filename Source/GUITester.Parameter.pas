(**
  
  This module contains a class which implements the IGTParameter interface for managing parameters of
  statements.

  @Author  David Hoyle
  @Version 1.349
  @Date    04 Jul 2026
  
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
Unit GUITester.Parameter;

Interface

Uses
  GUITester.Interfaces;

Type
  (** A class which implements the IGTParameter interface for managing parameter token(s). **)
  TGTParameter = Class(TInterfacedObject, IGTParameter)
  Strict Private
    FTokens : TArray<TGTToken>;
  Strict Protected
    // IGTParameter
    Function  GetText : String;
    Function  GetInteger : Integer;
    Function  GetTokenType : TGTTokenType;
    Function  GetCount : Integer;
    Function  GetToken(Const iIndex : Integer) : TGTToken;
  Public
    Constructor Create(Const Token : TGTToken); Overload;
    Constructor Create(Const Token : TArray<TGTToken>); Overload;
  End;

Implementation

ResourceString
  (** A resource string for an exception message is there are no tokens. **)
  strTokenEmpty = 'The token is empty!';

(**

  A constructor for the TGTParameter class.

  @precon  None.
  @postcon Creates a parameter from an array of tokens.

  @param   Token as a TArray<TGTToken> as a constant

**)
Constructor TGTParameter.Create(Const Token: TArray<TGTToken>);

Var
  iToken : Integer;
  
Begin
  SetLength(FTokens, Length(Token));
  For iToken := Low(Token) To High(Token) Do
    FTokens[iToken] := Token[iToken];
End;

(**

  A constructor for the TGTParameter class.

  @precon  None.
  @postcon Creates a parameter from a single token.

  @param   Token as a TGTToken as a constant

**)
Constructor TGTParameter.Create(Const Token: TGTToken);

Begin
  SetLength(FTokens, 1);
  FTokens[0] := Token;
End;

(**

  This is a getter method for the Count property.

  @precon  None.
  @postcon Returns the number of tokens in the parameter.

  @return  an Integer

**)
Function TGTParameter.GetCount: Integer;

Begin
  Result := Length(FTokens);
End;

(**

  This is a getter method for the Integer property.

  @precon  None.
  @postcon Returns the first token converted to an integer.

  @return  an Integer

**)
Function TGTParameter.GetInteger: Integer;

Begin
  If Length(FTokens) = 0 Then
    Raise EGTException.Create(strTokenEmpty);
  Result := FTokens[0].AsInteger;
End;

(**

  This is a getter method for the Text property.

  @precon  None.
  @postcon Returns the first token text.

  @return  a String

**)
Function TGTParameter.GetText: String;

Begin
  Result := '';
  If Length(FTokens) > 0 Then
    Result := FTokens[0].FText;
End;

(**

  This is a getter method for the Token property.

  @precon  iIndex must be a valid index between 0 and Count - 1.
  @postcon Returns the indexed token from the parameter.

  @param   iIndex as an Integer as a constant
  @return  a TGTToken

**)
Function TGTParameter.GetToken(Const iIndex: Integer): TGTToken;

Begin
  Result := FTokens[iIndex];
End;

(**

  This is a getter method for the Token Type property.

  @precon  None.
  @postcon Returns the token type of the first token.

  @return  a TGTTokenType

**)
Function TGTParameter.GetTokenType: TGTTokenType;

Begin
  If Length(FTokens) = 0 Then
    Raise EGTException.Create(strTokenEmpty);
  Result := FTokens[0].FTokenType;
End;

End.

