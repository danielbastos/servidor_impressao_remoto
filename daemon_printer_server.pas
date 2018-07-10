unit daemon_printer_server;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, DaemonApp, server_thread, fphttpserver, printers, fpjson, jsonparser;

type
  { TPrinterServer }

  TPrinterServer = class(TDaemon)
    procedure DataModuleContinue(Sender: TCustomDaemon; var OK: Boolean);
    procedure DataModulePause(Sender: TCustomDaemon; var OK: Boolean);
    procedure DataModuleStart(Sender: TCustomDaemon; var OK: Boolean);
    procedure DataModuleStop(Sender: TCustomDaemon; var OK: Boolean);
  private
    FServer : THTTPServerThread;
    procedure ReceiveRequest(Sender: TObject; Var ARequest: TFPHTTPConnectionRequest; Var AResponse : TFPHTTPConnectionResponse);

    procedure listPrinters(var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);
    procedure print(var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);
    procedure status(var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);

    function translateCodes(str : string) : string;

  public
    { public declarations }
  end;

var
  PrinterServer: TPrinterServer;

implementation

procedure RegisterDaemon;
begin
  RegisterDaemonClass(TPrinterServer);
end;

{$R *.lfm}

{ TPrinterServer }

procedure TPrinterServer.DataModuleContinue(Sender: TCustomDaemon; var OK: Boolean);
begin
  FServer.Start;
  OK := true;
end;

procedure TPrinterServer.DataModulePause(Sender: TCustomDaemon; var OK: Boolean);
begin
  FServer.Suspend;
  OK := true;
end;

procedure TPrinterServer.DataModuleStart(Sender: TCustomDaemon; var OK: Boolean);
begin
  Logger.Info('Start service ...');
  FServer := THTTPServerThread.Create(9123, @ReceiveRequest, false);

//  FThread.OnTerminate:=@ThreadStopped;
  FServer.FreeOnTerminate := true;
  FServer.Start;
  OK := true;
end;

procedure TPrinterServer.DataModuleStop(Sender: TCustomDaemon; var OK: Boolean);
begin
  Logger.Info('Stop service ...');
  FServer.Terminate;
  OK := true;
end;

procedure TPrinterServer.ReceiveRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);
begin
  AResponse.Code := 404;
  AResponse.ContentType := 'application/json';
  AResponse.SetCustomHeader('X-Powered-By', 'LivePDV Server');
  AResponse.SetCustomHeader('X-Server-Version', '0');

  AResponse.SetCustomHeader('Access-Control-Allow-Credentials', 'true');
  AResponse.SetCustomHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS');
  AResponse.SetCustomHeader('Access-Control-Allow-Origin', '*');
  AResponse.SetCustomHeader('Access-Control-Allow-Headers', 'origin, content-type, Content-Type, accept, Access-Control-Allow-Headers');
  AResponse.SetCustomHeader('Connection', 'keep-alive');

  if (ARequest.Method = 'GET') and (ARequest.URI = '/printers') then self.listPrinters(ARequest, AResponse);
  if (ARequest.Method = 'POST') and (ARequest.URI = '/print') then self.print(ARequest, AResponse);
  if (ARequest.Method = 'GET') and (ARequest.URI = '/status') then self.status(ARequest, AResponse);

  if (ARequest.Method = 'OPTIONS') then
    AResponse.Code := 200;

  if (AResponse.Code <> 200) and (AResponse.Code <> 202) then
    Logger.Error('URI: '+ARequest.URI+' errorcode: '+IntToStr(AResponse.Code));

end;

procedure TPrinterServer.listPrinters(var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);
var
  i : integer;
  data : string;

begin
  status(ARequest, AResponse);
  if (AResponse.Code = 500) then exit;

  try
    data := '[';
    for i := 0 to Printer.Printers.Count-1 do
      data := data + '"'+Printer.Printers[i]+'"' +', ';
    data := copy(data, 1, length(data)-2) + ']';

    AResponse.Code := 202;
    AResponse.Content := '{"data": '+data+'}';

  except
    on e : Exception do
    begin
      AResponse.Code := 500;
      AResponse.Content := '{"message":"'+ e.Message+'", "code":"005"}';
    end;
  end;
end;

procedure TPrinterServer.print(var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);
var
  data : TJSONObject;
  printerContent : AnsiString;

begin
  status(ARequest, AResponse);
  if (AResponse.Code <> 200) then exit;

  try
    data := TJSONObject(GetJSON(ARequest.Content));

    Printer.Title := 'Impressao de cupons';
    Printer.RawMode := True;

    Printer.SetPrinter(String(data.Get('printer')));

    printerContent := data.Get('content');
    //+ LineEnding + String(data.Get('content')) + LineEnding + data.Get('content');

    Printer.BeginDoc;
    Printer.Write(translateCodes(printerContent));
    Printer.Write(LineEnding);
    Printer.Write(LineEnding);
    Printer.EndDoc;
    AResponse.Code := 202;
    //AResponse.Content:='{"res":"'+translateCodes(printerContent)+'"}';

  except
    on e: Exception do
    begin
      AResponse.Code := 500;
      AResponse.Content := '{"message":"'+ e.Message+'", "code":"004"}';
    end;
  end;
end;

procedure TPrinterServer.status(var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);
begin
  if not Assigned(Printer) then
  begin
    AResponse.Code := 500;
    AResponse.Content := '{"message":"Impressoras não iniciadas", "code":"001"}';
    exit;
  end;

  try
    Printer.Printers;
  except
    on e: Exception do
    begin
      AResponse.Code := 500;
      AResponse.Content := '{"message":"Erro na instanciação das impressoras", "code":"003"}';
      exit;
    end;
  end;

  if not Assigned(Printer.Printers) then
  begin
    Logger.Info('TPrinterServer.status 4');
    AResponse.Code := 500;
    AResponse.Content := '{"message":"Lista de impressoras não iniciadas", "code":"002"}';
    exit;
  end;
  Logger.Info('TPrinterServer.status 5');
  AResponse.Code := 200;
end;

function TPrinterServer.translateCodes(str: string): string;
var
  i : integer;

begin
  result := str;

  for i := 0 to 256 do
    result := StringReplace(result, '['+FormatFloat('00', i)+']', Char(i), [rfReplaceAll]);
end;

initialization
  RegisterDaemon;
end.

