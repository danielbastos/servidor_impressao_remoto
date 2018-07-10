Program PrinterHttpServer;

Uses
{$IFDEF UNIX}{$IFDEF UseCThreads}
  CThreads,
{$ENDIF}{$ENDIF}
  DaemonApp, lazdaemonapp, OSPrinters, dmapper, daemon_printer_server
  { add your units here };

begin
  Application.Initialize;
  Application.Run;
end.
