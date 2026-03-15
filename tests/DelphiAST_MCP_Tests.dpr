program DelphiAST_MCP_Tests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF }
  DUnitX.TestFramework,
  MCP.TestHelper in 'MCP.TestHelper.pas',
  MCP.TestServer in 'MCP.TestServer.pas',
  Tests.Errors in 'Tests.Errors.pas',
  Tests.Example in 'Tests.Example.pas',
  Tests.FindReferences in 'Tests.FindReferences.pas',
  Tests.FindUsages in 'Tests.FindUsages.pas',
  Tests.GetCallGraph in 'Tests.GetCallGraph.pas',
  Tests.GetMethodBody in 'Tests.GetMethodBody.pas',
  Tests.GetSource in 'Tests.GetSource.pas',
  Tests.GetSyntaxTree in 'Tests.GetSyntaxTree.pas',
  Tests.GetTypeDetail in 'Tests.GetTypeDetail.pas',
  Tests.GetUsesGraph in 'Tests.GetUsesGraph.pas',
  Tests.ListFiles in 'Tests.ListFiles.pas',
  Tests.ParseUnit in 'Tests.ParseUnit.pas',
  Tests.ResolveInheritance in 'Tests.ResolveInheritance.pas',
  Tests.SetProject in 'Tests.SetProject.pas',
  Tests.Status in 'Tests.Status.pas',
  Tests.SymbolAtPosition in 'Tests.SymbolAtPosition.pas',
  Tests.DelphiASTInvestigation in 'Tests.DelphiASTInvestigation.pas',
  Tests.DirectTools.ListFiles in 'Tests.DirectTools.ListFiles.pas',
  Tests.DirectTools.ParseUnit in 'Tests.DirectTools.ParseUnit.pas',
  Tests.DirectTools.GetTypeDetail in 'Tests.DirectTools.GetTypeDetail.pas',
  Tests.DirectTools.GetMethodBody in 'Tests.DirectTools.GetMethodBody.pas',
  Tests.DirectTools.FindReferences in 'Tests.DirectTools.FindReferences.pas',
  Tests.DirectTools.GetUsesGraph in 'Tests.DirectTools.GetUsesGraph.pas',
  Tests.DirectTools.GetSyntaxTree in 'Tests.DirectTools.GetSyntaxTree.pas',
  Tests.DirectTools.FindUsages in 'Tests.DirectTools.FindUsages.pas',
  Tests.DirectTools.GetSource in 'Tests.DirectTools.GetSource.pas',
  Tests.DirectTools.SymbolAtPosition in 'Tests.DirectTools.SymbolAtPosition.pas',
  Tests.DirectTools.ResolveInheritance in 'Tests.DirectTools.ResolveInheritance.pas',
  Tests.DirectTools.GetCallGraph in 'Tests.DirectTools.GetCallGraph.pas',
  Tests.DirectTools.GetStatus in 'Tests.DirectTools.GetStatus.pas',
  Tests.DirectTools.SetProject in 'Tests.DirectTools.SetProject.pas',
  AST.Parser in '..\AST.Parser.pas',
  MCP.Tools in '..\MCP.Tools.pas',
  AST.Watcher in '..\AST.Watcher.pas',
  AST.Serialize in '..\AST.Serialize.pas',
  AST.Query in '..\AST.Query.pas';

{ keep comment here to protect the following conditional from being removed by the IDE when adding a unit }
{$IFNDEF TESTINSIGHT}
var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
  nunitLogger : ITestLogger;
  ProjectPath: string;
  TestServer: TMCPTestServer;
{$ENDIF}
begin
  ProjectPath := ExtractFilePath(ParamStr(0)) + '..\tests\test-project';

  // Start the MCP test server
  TestServer := TMCPTestServer.Create(ProjectPath, 3099);
  TestServer.Instance := TestServer; // Store for restoration by individual test fixtures
  try
    TestServer.Start;
    // Register the helper with the server instance
    TMCPTestHelper.SetServer(TestServer);

  {$IFDEF TESTINSIGHT}
    TestInsight.DUnitX.RunRegisteredTests;
  {$ELSE}
    try
      //Check command line options, will exit if invalid
      TDUnitX.CheckCommandLine;
      //Create the test runner
      runner := TDUnitX.CreateRunner;
      //Tell the runner to use RTTI to find Fixtures
      runner.UseRTTI := True;
      //When true, Assertions must be made during tests;
      runner.FailsOnNoAsserts := False;

      //tell the runner how we will log things
      //Log to the console window if desired
      if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
      begin
        logger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
        runner.AddLogger(logger);
      end;
      //Generate an NUnit compatible XML File
      nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
      runner.AddLogger(nunitLogger);

      //Run tests
      results := runner.Execute;
      if not results.AllPassed then
        System.ExitCode := EXIT_ERRORS;

      {$IFNDEF CI}
      //We don't want this happening when running under CI.
      if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
      begin
        System.Write('Done.. press <Enter> key to quit.');
        System.Readln;
      end;
      {$ENDIF}
    except
      on E: Exception do
        System.Writeln(E.ClassName, ': ', E.Message);
    end;
  {$ENDIF}
  finally
    TestServer.Free;
  end;
end.
