unit server_thread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpserver;

type
  THTTPServerThread = Class(TThread)
  Private
     FServer : TFPHTTPServer;
  Public
    constructor Create(APort : Word; const OnRequest : THTTPServerRequestHandler; const ParallelRequest : boolean);
    procedure Execute; override;
    procedure DoTerminate; override;
    property Server : TFPHTTPServer Read FServer;
  end;

implementation

constructor THTTPServerThread.Create(APort: Word; const OnRequest: THTTPServerRequestHandler; const ParallelRequest : boolean);
begin
  FServer           := TFPHTTPServer.Create(Nil);
  FServer.Port      := APort;
  FServer.Threaded  := ParallelRequest;
  FServer.OnRequest := OnRequest;
  Inherited Create(False);
end;

procedure THTTPServerThread.Execute;
begin
  try
    FServer.Active := True;
  finally
    FreeAndNil(FServer);
  end;
end;

procedure THTTPServerThread.DoTerminate;
begin
  inherited DoTerminate;
  FServer.Active:=False;
end;

end.

