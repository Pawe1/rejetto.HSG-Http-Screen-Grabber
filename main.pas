{
Copyright (C) 2002  Massimo Melina <rejetto (at) tin.it>

This file is part of Http Screen Grabber (HSG).

    HSG is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    HSG is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with HSG; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

{$I-}
unit main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, jpeg, HSlib, ComCtrls, ToolWin, ExtCtrls, Clipbrd,
  Spin, Menus;

const
  CRLF=#13#10;
  version = '0.4';
  GRAB_FULL = 0;
  GRAB_ACTIVE = 1;
  GRAB_CLIPBOARD = 2;
  GRAB_MEMORY = 3;
  copyright =
'HSG version '+version+
', Copyright (C) 2002  Massimo Melina <rejetto (at) tin.it>'+CRLF+
'HSG comes with ABSOLUTELY NO WARRANTY; for details see the file license.txt'+
CRLF+
'This is free software, and you are welcome to redistribute it'+CRLF+
'under certain conditions.';

type
  TmainFrm = class(TForm)
    outBox: TMemo;
    ToolBar1: TToolBar;
    Label2: TLabel;
    grabBox: TComboBox;
    Label1: TLabel;
    portBox: TEdit;
    activeBtn: TToolButton;
    ToolButton2: TToolButton;
    qualitySpin: TSpinEdit;
    Label3: TLabel;
    urlBox: TEdit;
    ToolButton5: TToolButton;
    Label4: TLabel;
    ToolButton6: TToolButton;
    menuBtn: TToolButton;
    ToolButton9: TToolButton;
    menu: TPopupMenu;
    savecfg1: TMenuItem;
    savepic1: TMenuItem;
    ToolButton7: TToolButton;
    beepChk: TMenuItem;
    logheaderChk: TMenuItem;
    refresh1: TMenuItem;
    none1: TMenuItem;
    everyminute1: TMenuItem;
    every45seconds1: TMenuItem;
    every30seconds1: TMenuItem;
    every15seconds1: TMenuItem;
    everysecond1: TMenuItem;
    logtimeChk: TMenuItem;
    logdateChk: TMenuItem;
    about1: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure activeBtnClick(Sender: TObject);
    procedure portBoxChange(Sender: TObject);
    procedure grabBoxDropDown(Sender: TObject);
    procedure grabBoxSelect(Sender: TObject);
    procedure savecfg1Click(Sender: TObject);
    procedure savepic1Click(Sender: TObject);
    procedure none1Click(Sender: TObject);
    procedure everyminute1Click(Sender: TObject);
    procedure every45seconds1Click(Sender: TObject);
    procedure every30seconds1Click(Sender: TObject);
    procedure every15seconds1Click(Sender: TObject);
    procedure everysecond1Click(Sender: TObject);
    procedure about1Click(Sender: TObject);
  public
    procedure httpEvent(eventID:ThttpEventID; client:ThttpCln);
    procedure refreshGrabList;
    procedure savecfg;
    procedure loadcfg;
  end;

var
  mainFrm :TmainFrm;

implementation

uses
  strutils;

{$R *.dfm}

var
  topwindows :array of record idx, hnd:integer; title:string end;
  grabbing :boolean;
  lastreply :string;
  refreshPic :integer;
  httpsrv :ThttpSrv;
  memory :Tbitmap=NIL;
  lastItemIndex :integer;

function loadFile(fn:string):string;
var
  f:file;
begin
result:='';
IOresult;
assignFile(f,fn);
reset(f,1);
if IOresult <> 0 then exit;
setLength(result, fileSize(f));
blockRead(f, result[1], length(result));
closeFile(f);
end; // loadFile

function saveFile(fn:string; data:string):boolean;
var
  f:file;
begin
result:=FALSE;
IOresult;
assignFile(f,fn);
rewrite(f,1);
if IOresult <> 0 then exit;
blockWrite(f, data[1], length(data));
if IOresult <> 0 then exit;
closeFile(f);
result:=TRUE;
end; // saveFile

function topwindows_idx2hnd(idx:integer):integer;
var
  i:integer;
begin
result:=0;
for i:=0 to length(topwindows)-1 do
  if topwindows[i].idx = idx then
    begin
    result:=topwindows[i].hnd;
    exit;
    end;
end; // topwindows_idx2hnd

function EnumWindowsFunc(Handle: THandle; niente:integer): boolean ; stdcall;

  function findByTitle(s:string):integer;
  begin
  for result:=0 to length(topwindows)-1 do
    if topwindows[result].title = s then
      break;
  result:=-1;
  end;

var
  title:array [0..256] of char;
  i:integer;
begin
Result :=True;
if IsWindowVisible(handle) and (0<>GetWindowText(Handle, title, sizeOf(title)-1)) then
  begin
  i:=findByTitle(title);
  if i<0 then
    begin
    setlength(topwindows, length(topwindows)+1);
    i:=length(topwindows)-1;
    end;
  topwindows[i].title:=title;
  topwindows[i].hnd:=handle;
  end;
end;

procedure refreshTopWindows;
begin
setlength(topwindows,0);
EnumWindows(@EnumWindowsFunc, 0);
end;

function onlyDigits(s:string):string;
var
  i:integer;
begin
for i:=1 to length(s) do
 if not (s[i] in ['0'..'9']) then
   delete(s,i,1);
result:=s;
end; // onlydigits

procedure grabWindow(hnd:Thandle; result:Tbitmap; dx:integer=0; dy:integer=0);
var
  Rsrc:Trect;
  sx,sy:integer;
begin
getwindowrect(hnd, Rsrc);
sx:=Rsrc.right-Rsrc.left;
sy:=Rsrc.bottom-Rsrc.top;
if (dx = 0) or (dx > sx) then dx:=sx;
if (dy = 0) or (dy > sy) then dy:=sy;
result.width:=dx;
result.Height:=dy;
bitblt(result.canvas.Handle, 0,0, sx,sy, getwindowdc(hnd), 0,0, SRCCOPY);
end; // grabWindow

function grabInJPG:Tjpegimage;
var
  bmp:Tbitmap;
  hnd:integer;
begin
result:=Tjpegimage.create;
result.CompressionQuality:=trunc(mainfrm.qualitySpin.value);
hnd:=0;
case mainfrm.grabBox.itemindex of
  GRAB_FULL: hnd:=GetDesktopWindow;
  GRAB_ACTIVE: hnd:=GetForegroundWindow;
  GRAB_MEMORY: bmp:=memory;
  GRAB_CLIPBOARD:
    try
      bmp:=Tbitmap.create;
      bmp.LoadFromClipBoardFormat(cf_BitMap,ClipBoard.GetAsHandle(cf_Bitmap),0);
    except
      freeAndNIL(bmp);
    end;
  else
    hnd:=topwindows_idx2hnd(mainfrm.grabBox.itemindex);
  end;
if hnd > 0 then
  begin
  bmp:=Tbitmap.create;
  grabwindow(hnd,bmp);
  end;
if assigned(bmp) then
  begin
  result.assign(bmp);
  if hnd > 0 then bmp.free;
  end
else
  freeAndNIL(result);
end; // grabInJPG

procedure log(s:string);
var
  h:string;
begin
h:='';
if mainfrm.logtimeChk.checked then h:=TimeToStr(now)+h;
if mainfrm.logdateChk.checked then
  begin
  if h > '' then h:=' '+h;
  h:=DateToStr(now)+h;
  end;
if h > '' then h:='['+h+'] ';
mainfrm.outBox.Lines.add(h+s);
end;

procedure startServer;
var
  ips:string;
begin
httpsrv.port:=strToInt(mainfrm.portBox.text);
httpsrv.onEvent:=mainfrm.HTTPevent;
if not httpsrv.start then
  begin
  mainfrm.activeBtn.down:=FALSE;
  mainfrm.activeBtn.caption:='OFF';
  MessageDlg('can''t open port',mtError,[],0);
  exit;
  end;
mainfrm.portbox.enabled:=FALSE;
mainfrm.activeBtn.down:=TRUE;
mainfrm.activeBtn.caption:='ON';
log('listening on');
ips:=httpsrv.getIPs;
while ips>'' do
  log('http://'+trim(chop(#13#10,ips))+
    ifThen(httpsrv.port<>80, ':'+intToStr(httpsrv.port)));
log('waiting for connections...');
end; // startServer

procedure stopServer;
begin
mainfrm.portbox.enabled:=TRUE;
httpsrv.stop;
log('server stopped');
mainfrm.activeBtn.down:=FALSE;
mainfrm.activeBtn.caption:='OFF';
end;

procedure toggleServer;
begin if httpsrv.active then stopServer else startServer end;

procedure Tmainfrm.savecfg;
const
  yesno:array [boolean] of string=('no','yes');
var
  s:string;
begin
s:='HSG '+version+CRLF
+'active='+yesno[httpsrv.active]+CRLF
+'port='+portBox.text+CRLF
+'quality='+qualitySpin.Text+CRLF
+'beep='+yesno[beepChk.checked]+CRLF
+'log-header='+yesno[logheaderChk.checked]+CRLF
+'log-time='+yesno[logtimeChk.checked]+CRLF
+'log-date='+yesno[logdateChk.checked]+CRLF
+'url='+urlBox.Text+CRLF
+'grab='+intToStr(grabBox.ItemIndex)+CRLF
+'refresh='+intToStr(refreshPic)+CRLF
;
savefile('hsg.ini',s);
end; // savecfg

procedure Tmainfrm.loadcfg;
var
  s,l,h:string;
  active:boolean;

  function yes:boolean;
  begin result:=l='yes' end;

begin
active:=httpSrv.active;
s:=loadfile('hsg.ini');
while s > '' do
  begin
  l:=chop(CRLF,s);
  h:=chop('=',l);
  try
    if h = 'active' then active:=yes;
    if h = 'port' then portBox.Text:=l;
    if h = 'quality' then qualitySpin.Text:=l;
    if h = 'beep' then beepChk.checked:=yes;
    if h = 'log-header' then logheaderChk.checked:=yes;
    if h = 'url' then urlBox.Text:=l;
    if h = 'grab' then grabBox.ItemIndex:=strToInt(l);
    if h = 'log-time' then logtimeChk.Checked:=yes;
    if h = 'log-date' then logdateChk.Checked:=yes;
    if h = 'refresh' then
      begin
      refreshPic:=strToInt(l);
      case refreshPic of
        0: none1.Checked:=TRUE;
        60: everyminute1.checked:=TRUE;
        45: every45seconds1.checked:=TRUE;
        30: every30seconds1.checked:=TRUE;
        15: every15seconds1.checked:=TRUE;
        1: everysecond1.checked:=TRUE;
        end;
      end;
  except end;
  end;
if httpSrv.active<>active then
  toggleServer;
end; // loadcfg

procedure Tmainfrm.refreshGrabList;
var
  bak:string;
//  i:integer;
begin
if grabbox.ItemIndex < 0 then
  bak:=''
else
  bak:=grabBox.Text;
refreshTopWindows;
{
while grabbox.items.count > 3 do
  grabbox.items.Delete(3);
for i:=0 to length(topwindows)-1 do
  topwindows[i].idx:=grabbox.Items.Add('"'+topwindows[i].title+'"');
  }
if bak > '' then
  grabbox.ItemIndex:=grabbox.Items.IndexOf(bak)
else
  grabbox.ItemIndex:=0;
end; // refreshGrabList

procedure TmainFrm.httpEvent(eventID:ThttpEventID; client:ThttpCln);

  procedure replyWithScreen;
  var
    jpg:Tjpegimage;
    stream:TStringStream;
  begin
  grabbing:=TRUE;
  jpg:=grabInJPG;
  if assigned(jpg) then
    begin
    stream:=TStringStream.create('');
    jpg.SaveToStream(stream);
    jpg.free;
    lastreply:=stream.DataString;
    stream.free;
    end
  else
    lastreply:='';
  grabbing:=FALSE;
  end; // replyWithScreen

  procedure serveIt;
  var
    s:string;
  begin
  if beepChk.Checked then beep;
  flashWindow(application.handle,TRUE);
  if logheaderChk.Checked then
    begin
    s:=client.request.full;
    while s>'' do
      log('> '+chop(#13#10, s));
    end;

  client.reply.mode:=_close; // by default
  if not (client.request.method in [HM_GET,HM_HEAD]) then
    begin
    log('bad method '+client.address);
    exit;
    end;
  if client.request.url <> '/'+urlbox.Text then
    begin
    log('bad url '+client.address);
    exit;
    end;
  if not grabbing then replyWithScreen;
  case client.request.method of
    HM_GET: client.reply.mode:=_reply;
    HM_HEAD: client.reply.mode:=_reply_wo_body;
    end;
  client.reply.bodyMode:=_string;
  if lastreply='' then
    begin
    client.reply.contentType:='text/plain';
    client.reply.body:='INTERNAL ERROR';
    log('error sent to '+client.address);
    end
  else
    begin
    client.reply.contentType:='image/jpeg';
    client.reply.body:=lastreply;
    if refreshPic > 0 then
      client.reply.additionalHeaders:=format('Refresh: %d',[refreshPic]);
    log(format('serving '+client.address+' (%dKb)', [length(client.reply.body) div 1024]));
    end
  end; // serveIt

begin
case eventID of
  HE_CONNECTED: log('connected '+client.address);
  HE_REQUESTED: serveIt;
  HE_REPLIED: log(format('served '+client.address+' (%dKb)', [client.bsent_body div 1024]));
  HE_DISCONNECTED: log('disconnected '+client.address);
  end;
end; // httpEvent

procedure TmainFrm.FormCreate(Sender: TObject);
begin
caption:='Http Screen Grabber '+version;
application.Title:='HSG'+version;
refreshGrabList;
loadcfg;
end;

procedure TmainFrm.activeBtnClick(Sender: TObject);
begin toggleServer end;

procedure TmainFrm.portBoxChange(Sender: TObject);
begin portbox.text:=onlydigits(portbox.text) end;

procedure TmainFrm.grabBoxDropDown(Sender: TObject);
begin refreshGrabList end;

procedure TmainFrm.grabBoxSelect(Sender: TObject);
begin
if grabbox.ItemIndex = GRAB_MEMORY then
  try
    if not assigned(memory) then memory:=Tbitmap.create;
    memory.LoadFromClipBoardFormat(cf_BitMap,ClipBoard.GetAsHandle(cf_Bitmap),0);
    messageDlg('Now the clipboard has been copied into a buffer. This will be sent to each request. You can safely change the clipboard content.',mtInformation,[mbOk],0);
  except
    freeandnil(memory);
    grabbox.itemindex:=lastItemIndex;
    messageDlg('The clipboard does not contain a valid image.',mtError,[mbOk],0);
    exit;
  end;
lastItemIndex:=grabbox.itemindex;
end;

procedure TmainFrm.savecfg1Click(Sender: TObject);
begin savecfg end;

procedure TmainFrm.savepic1Click(Sender: TObject);
var
  dlg:TSaveDialog;
  pic:TJPEGImage;
begin
dlg:=Tsavedialog.create(self);
dlg.Filter:='JPEG image|*.jpg';
dlg.DefaultExt:='jpg';
if dlg.Execute then
  begin
  pic:=grabInJPG;
  pic.SaveToFile(dlg.FileName);
  pic.Free;
  end;
dlg.Free;
end;

procedure TmainFrm.none1Click(Sender: TObject);
begin refreshPic:=0 end;

procedure TmainFrm.everyminute1Click(Sender: TObject);
begin refreshPic:=60 end;

procedure TmainFrm.every45seconds1Click(Sender: TObject);
begin refreshPic:=45 end;

procedure TmainFrm.every30seconds1Click(Sender: TObject);
begin refreshPic:=30 end;

procedure TmainFrm.every15seconds1Click(Sender: TObject);
begin refreshPic:=15 end;

procedure TmainFrm.everysecond1Click(Sender: TObject);
begin refreshPic:=1 end;

procedure TmainFrm.about1Click(Sender: TObject);
begin MessageDlg(copyright, mtInformation, [mbOk], 0) end;

initialization
httpsrv:=ThttpSrv.create;

finalization
httpsrv.free;

end.


