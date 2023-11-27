﻿unit uSubProcess;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, LMessages,
  uCEFChromium, uCEFWindowParent, uCEFConstants, uCEFTypes, uCEFInterfaces,
  uCEFChromiumEvents, uCEFLinkedWindowParent;

const
  CEF_SETFOCUS = 1;

type
  { TForm1 }
  TForm1 = class(TForm)
    AddressEdt: TEdit;
    CEFLinkedWindowParent1: TCEFLinkedWindowParent;
    GoBtn: TButton;
    Chromium1: TChromium;
    AddressPnl: TPanel;
    Timer1: TTimer;

    procedure Chromium1AfterCreated(Sender: TObject; const browser: ICefBrowser);
    procedure Chromium1BeforeClose(Sender: TObject; const browser: ICefBrowser);
    procedure Chromium1Close(Sender: TObject; const browser: ICefBrowser; var aAction: TCefCloseBrowserAction);    
    procedure Chromium1BeforePopup(Sender: TObject; const browser: ICefBrowser; const frame: ICefFrame; const targetUrl, targetFrameName: ustring; targetDisposition: TCefWindowOpenDisposition; userGesture: Boolean; const popupFeatures: TCefPopupFeatures; var windowInfo: TCefWindowInfo; var client: ICefClient; var settings: TCefBrowserSettings; var extra_info: ICefDictionaryValue; var noJavascriptAccess: Boolean; var Result: Boolean);
    procedure Chromium1GotFocus(Sender: TObject; const browser: ICefBrowser);
    procedure Chromium1OpenUrlFromTab(Sender: TObject; const browser: ICefBrowser; const frame: ICefFrame; const targetUrl: ustring; targetDisposition: TCefWindowOpenDisposition; userGesture: Boolean; out Result: Boolean);

    procedure FormCreate(Sender: TObject);   
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);

    procedure GoBtnClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);  

    procedure CEFLinkedWindowParent1Enter(Sender: TObject);
    procedure CEFLinkedWindowParent1Exit(Sender: TObject);
  private
                 
  protected
    // Variables to control when can we destroy the form safely
    FCanClose  : boolean;  // Set to True in TChromium.OnBeforeClose
    FClosing   : boolean;  // Set to True in the CloseQuery event.

    // CEF needs to handle these messages to call TChromium.NotifyMoveOrResizeStarted
    procedure WMMove(var Message: TLMMove); message LM_MOVE;
    procedure WMSize(var Message: TLMSize); message LM_SIZE;
    procedure WMWindowPosChanged(var Message: TLMWindowPosChanged); message LM_WINDOWPOSCHANGED;

    procedure SendCompMessage(aMsg : cardinal);

    procedure BrowserCreatedMsg(Data: PtrInt);
    procedure BrowserCloseFormMsg(Data: PtrInt);
    procedure BrowserSetFocusMsg(Data: PtrInt);
  public

  end;

var
  Form1: TForm1;

procedure CreateGlobalCEFApp;

implementation

{$R *.lfm}

// This is a demo based on the SimpleBrowser2 demo but it uses a different
// executable for the Chromium subprocesses.

// Before running this demo you need to build the "SubProcess_sp.lpr" project.

// Destruction steps
// =================
// 1. FormCloseQuery sets CanClose to FALSE calls TChromium.CloseBrowser which triggers the TChromium.OnClose event.
// 2. TChromium.OnClose sets aAction to cbaClose to destroy the browser, which triggers the TChromium.OnBeforeClose event.
// 3. TChromium.OnBeforeClose sets FCanClose := True and sends CEF_BEFORECLOSE to close the form.

uses
  uCEFApplication;

{ TForm1 }


procedure CreateGlobalCEFApp;
begin
  GlobalCEFApp                       := TCefApplication.Create;
  GlobalCEFApp.BrowserSubprocessPath := 'SubProcess_sp';    // This is the name of the executable used by CEF for the Chromium subprocesses
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FCanClose   := False;
  FClosing    := False;

  Chromium1.DefaultURL := UTF8Decode(AddressEdt.Text);
end;

procedure TForm1.GoBtnClick(Sender: TObject);
begin
  Chromium1.LoadURL(UTF8Decode(AddressEdt.Text));
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := False;
  if not(Chromium1.CreateBrowser(CEFLinkedWindowParent1.Handle, CEFLinkedWindowParent1.BoundsRect)) and
     not(Chromium1.Initialized) then
    Timer1.Enabled := True;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose := FCanClose;

  if not(FClosing) then
    begin
      FClosing := True;
      Visible  := False;
      Chromium1.CloseBrowser(True);
    end;
end;

procedure TForm1.Chromium1BeforePopup(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame; const targetUrl,
  targetFrameName: ustring; targetDisposition: TCefWindowOpenDisposition;
  userGesture: Boolean; const popupFeatures: TCefPopupFeatures;
  var windowInfo: TCefWindowInfo; var client: ICefClient;
  var settings: TCefBrowserSettings; var extra_info: ICefDictionaryValue;
  var noJavascriptAccess: Boolean; var Result: Boolean);
begin
  // For simplicity, this demo blocks all popup windows and new tabs
  Result := (targetDisposition in [WOD_NEW_FOREGROUND_TAB, WOD_NEW_BACKGROUND_TAB, WOD_NEW_POPUP, WOD_NEW_WINDOW]);
end;

procedure TForm1.Chromium1OpenUrlFromTab(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame; const targetUrl: ustring;
  targetDisposition: TCefWindowOpenDisposition; userGesture: Boolean; out
  Result: Boolean);
begin
  // For simplicity, this demo blocks all popup windows and new tabs
  Result := (targetDisposition in [WOD_NEW_FOREGROUND_TAB, WOD_NEW_BACKGROUND_TAB, WOD_NEW_POPUP, WOD_NEW_WINDOW]);
end;

procedure TForm1.FormActivate(Sender: TObject);
begin
  // You *MUST* call CreateBrowser to create and initialize the browser.
  // This will trigger the AfterCreated event when the browser is fully
  // initialized and ready to receive commands.

  // GlobalCEFApp.GlobalContextInitialized has to be TRUE before creating any browser
  // If it's not initialized yet, we use a simple timer to create the browser later.

  // Linux needs a visible form to create a browser so we need to use the
  // TForm.OnActivate event instead of the TForm.OnShow event

  if not(Chromium1.Initialized) and                                     
     not(Chromium1.CreateBrowser(CEFLinkedWindowParent1.Handle, CEFLinkedWindowParent1.BoundsRect)) then
    Timer1.Enabled := True;
end;

procedure TForm1.Chromium1Close(Sender: TObject; const browser: ICefBrowser; var aAction: TCefCloseBrowserAction);
begin
  // continue closing the browser
  aAction := cbaClose;
end;

procedure TForm1.Chromium1BeforeClose(Sender: TObject; const browser: ICefBrowser);
begin
  // We must wait until all browsers trigger the TChromium.OnBeforeClose event
  // in order to close the application safely or we will have shutdown issues.
  FCanClose := True;
  SendCompMessage(CEF_BEFORECLOSE);
end;

procedure TForm1.Chromium1AfterCreated(Sender: TObject; const browser: ICefBrowser);
begin
  // Now the browser is fully initialized we can initialize the UI.
  SendCompMessage(CEF_AFTERCREATED);
end;

// This is a workaround for the CEF issue #2026
// https://bitbucket.org/chromiumembedded/cef/issues/2026/multiple-major-keyboard-focus-issues-on
// We use CEFLinkedWindowParent1.OnEnter, CEFLinkedWindowParent1.OnExit and
// TChromium.OnGotFocus to avoid most of the focus issues.
// CEFLinkedWindowParent1.TabStop must be TRUE.
procedure TForm1.CEFLinkedWindowParent1Exit(Sender: TObject);
begin
  if not(csDesigning in ComponentState) then
    Chromium1.SendCaptureLostEvent;
end;

procedure TForm1.CEFLinkedWindowParent1Enter(Sender: TObject);
begin
  if not(csDesigning in ComponentState) and
     Chromium1.Initialized and
     not(Chromium1.FrameIsFocused) then
    Chromium1.SetFocus(True);
end;

procedure TForm1.Chromium1GotFocus(Sender: TObject; const browser: ICefBrowser);
begin
  SendCompMessage(CEF_SETFOCUS);
end;

procedure TForm1.BrowserCreatedMsg(Data: PtrInt);
begin
  Caption            := 'SubProcess Browser';
  AddressPnl.Enabled := True;
end;

procedure TForm1.BrowserCloseFormMsg(Data: PtrInt);
begin
  Close;
end;

procedure TForm1.BrowserSetFocusMsg(Data: PtrInt);
begin
  CEFLinkedWindowParent1.SetFocus;
end;

procedure TForm1.SendCompMessage(aMsg : cardinal);
begin
  case aMsg of                                       
    CEF_AFTERCREATED : Application.QueueAsyncCall(@BrowserCreatedMsg, 0);
    CEF_BEFORECLOSE  : Application.QueueAsyncCall(@BrowserCloseFormMsg, 0);
    CEF_SETFOCUS     : Application.QueueAsyncCall(@BrowserSetFocusMsg, 0);
  end;
end;

procedure TForm1.WMMove(var Message: TLMMove);
begin
  inherited;
  Chromium1.NotifyMoveOrResizeStarted;
end;

procedure TForm1.WMSize(var Message: TLMSize);       
begin
  inherited;
  Chromium1.NotifyMoveOrResizeStarted;
end;

procedure TForm1.WMWindowPosChanged(var Message: TLMWindowPosChanged);
begin
  inherited;
  Chromium1.NotifyMoveOrResizeStarted;
end;


end.

