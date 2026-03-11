unit Tests.DelphiASTInvestigation;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TDelphiASTInvestigationTests = class
  public
    [Test]
    procedure CompareIAnimalVsTAnimalChildren;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.Json,
  DelphiAST, DelphiAST.Classes, DelphiAST.Consts;

{ Helper function to get node type name }
function NodeTypeName(Node: TSyntaxNode): string;
begin
  Result := SyntaxNodeNames[Node.Typ];
end;

{ Helper function to get node name }
function NodeName(Node: TSyntaxNode): string;
begin
  Result := Node.GetAttribute(anName);
  if (Result = '') and (Node is TValuedSyntaxNode) then
    Result := TValuedSyntaxNode(Node).Value;
end;

procedure TDelphiASTInvestigationTests.CompareIAnimalVsTAnimalChildren;
var
  FileName: string;
  Tree, TypeDecl, TypeNode, Child: TSyntaxNode;
  Output: TStringList;
  TypName: string;
  NamName: string;
  I: Integer;
begin
  FileName := ExtractFilePath(ParamStr(0)) + '..\tests\test-project\Animals.pas';

  Tree := TPasSyntaxTreeBuilder.Run(FileName, False, nil);
  try
    Assert.IsNotNull(Tree, 'Tree should not be nil');

    Output := TStringList.Create;
    try
      Output.Add('=== Comparing IAnimal vs TAnimal type node children ===');

      // Find both IAnimal and TAnimal
      for TypeDecl in Tree.ChildNodes do
      begin
        if TypeDecl.Typ = ntTypeDecl then
        begin
          var TypeName := NodeName(TypeDecl);

          if SameText(TypeName, 'IAnimal') or SameText(TypeName, 'TAnimal') then
          begin
            Output.Add(Format('=== %s ===', [TypeName]));

            // Get the inner type node
            TypeNode := TypeDecl.FindNode(ntType);
            if Assigned(TypeNode) then
            begin
              Output.Add(Format('Type node name: "%s"', [NodeName(TypeNode)]));
              Output.Add(Format('Children of Type node (%d):', [Length(TypeNode.ChildNodes)]));
              for Child in TypeNode.ChildNodes do
              begin
                TypName := NodeTypeName(Child);
                NamName := NodeName(Child);
                Output.Add(Format('  - [%s] name="%s"', [TypName, NamName]));
              end;
            end;
            Output.Add('');
          end;
        end;
      end;

      // Write to console
      for I := 0 to Output.Count - 1 do
        System.Writeln(Output[I]);

    finally
      Output.Free;
    end;
  finally
    Tree.Free;
  end;
end;

end.
