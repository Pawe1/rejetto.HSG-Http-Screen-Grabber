{
Copyright (C) 2002  Massimo Melina <rejetto (at) tin.it>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

}
unit hslib;

interface

uses
  wsocket, classes;

type
  ThttpSrv=class;

  ThttpCln=class;

  ThttpMethod=(   // http method
    HM_UNK,
    HM_GET,
    HM_POST,
    HM_HEAD
  );

  ThttpEventID=(
    HE_CONNECTED,       // a client just connected
    HE_DISCONNECTED,    // communication terminated
    HE_GOT,             // other peer sent sth
    HE_SENT,            // we sent sth
    HE_REQUESTED,       // a full request has been submitted
    HE_REPLIED          // the reply has been sent
  );

  ThttpReply=record
    mode :(
      _reply,            // reply header+body
      _reply_wo_body,    // reply header (ideal for head requests)
      _deny,             // answer a deny code
      _not_found,        // answer a not-found code
      _bad_request,      // answer a bad-request code
      _internal_error,   // answer an internal-error code
      _close,            // close connection with no reply
      _ignore            // does nothing, connection remains open
    );
    header :string;            // full raw header (optional)
    contentType :string;       // ContentType header (optional)
    additionalHeaders :string; // these are appended to predefined headers (opt)
    body :string;    // specifies reply body according to bodySource
    bodyMode :(
      _file,         // variable body specifies a file
      _string        // variable body specifies byte content
    );
    firstByte, lastByte :integer;  // body interval for partial replies (206)
    end;

  ThttpRequest=record
    full :string;           // the raw request, byte by byte
    method :ThttpMethod;
    url :string;
    ver :string;
    headers :string;        // headers like If-Modified-Since, separated by CRLF
    end;

  ThttpCln=class
  private
    buffer :string;       // internal buffer for incoming data
    srv :ThttpSrv;        // reference to the server
    f :file;
    P_address :string;
    function  parseHeader:boolean;
    // event handlers
    procedure disconnected(Sender: TObject; Error: Word);
    procedure dataavailable(Sender: TObject; Error: Word);
    procedure senddata(sender:Tobject; bytes:integer);
    procedure datasent(sender:Tobject; error:word);
    function  totalBodySize:integer;
    function  openFileIfNeeded:boolean;
    procedure closeFileIfNeeded;
    function  getNextChunk:string;
  public
    sock :Twsocket;           // client-server communication socket
    state :(
      HCS_IDLE,               // just connected
      HCS_REQUESTING,         // getting request
      HCS_REPLYING_HEADER,    // sending header
      HCS_REPLYING_BODY,      // sending body
      HCS_DISCONNECTED        // disconnected
    );
    request :ThttpRequest;    // it requests
    reply :ThttpReply;        // we serve
    bsent :integer;           // byte sent to the client
    bsent_body :integer;      // byte sent to the client (body only)
    constructor create(server:ThttpSrv);
    destructor destroy; override;
    procedure disconnect;
    function  getHeader(h:string):string;  // extract the value associated to
                                           // the header from request.headers
    property address:string read P_address; // other peer ip address
    end;

  ThttpSrv=class
  private
    P_port :integer;
    procedure setPort(v:integer);
    function getActive():boolean;
    procedure setActive(v:boolean);
    procedure connected(Sender: TObject; Error: Word);
  public
    sock :Twsocket;   // listening socket
    clients :Tlist;   // full list of connected clients
    // this should be associated to your event handler
    onEvent :procedure(eventID:ThttpEventID; client:ThttpCln) of object;
    constructor create(); overload;
    destructor destroy(); override;
    property  active:boolean read getActive write setActive; // r we listening?
    property  port:integer read P_port write setPort;
    function  start:boolean;   // active:=true, returns true if all is ok
    procedure stop;
    function  getIP:string; virtual;   // an ip address where we are listening
    function  getIPs:string; virtual;  // ip addresses where we are listening
    end;

{ split S in position where SS is found, the first part is returned
  the second part following SS is left in S }
function chop(ss:string; var s:string):string; overload;
// same as before, but separator is I
function chop(i:integer; var s:string):string; overload;
// builds standard headers to be assigned to reply.header
function replyHeader_OK(contentLength:integer=-1; contentType:string=''):string;
function replyHeader_PARTIAL(firstByte,lastByte,totalByte :integer;
  contentType:string=''):string;

implementation

uses
  sysutils;
const
  CRLF=#13#10;
  chunkSize=16; // size of chunks, sending body (in kilobytes)

function replyHeader_code(code:integer):string;
begin
result:='HTTP/1.1 ';
case code of
  200:result:=result+'200 OK';
  400:result:=result+'400 BAD REQUEST';
  500:result:=result+'500 INTERNAL ERROR';
  404:result:=result+'404 NOT FOUND';
  403:result:=result+'403 FORBIDDEN';
  206:result:=result+'206 PARTIAL CONTENT';
  end;
result:=result+CRLF;
end; // replyHeader_code

function replyHeader_IntPositive(name:string; int:integer):string;
begin
result:='';
if int >= 0 then result:=name+': '+intToStr(int)+CRLF;
end;

function replyHeader_Str(name:string; str:string):string;
begin
result:='';
if str > '' then result:=name+': '+str+CRLF;
end;

function replyHeader_OK(contentLength:integer=-1; contentType:string=''):string;
begin
result:=
  replyheader_code(200)
  +replyHeader_IntPositive('Content-length',contentLength)
  +replyHeader_Str('Content-type',contentType)
end; // replyHeader_OK

function replyHeader_PARTIAL(firstByte,lastByte,totalByte:integer; contentType:string=''):string;
begin
result:=
  replyheader_code(206)
  +format('Content-range: bytes %d-%d/%d'+CRLF+'Content-length: %d'+CRLF,
        [firstByte,lastByte,totalByte,lastByte-firstByte+1])
  +replyHeader_Str('Content-type',contentType)
end; // replyheader_PARTIAL

function chop(ss:string; var s:string):string;
var
  i:integer;
begin
i:=pos(ss,s);
if i=0 then
  begin
  result:=s;
  s:='';
  end
else
  begin
  result:=copy(s,1,i-1);
  delete(s,1,i+length(ss)-1);
  end;
end; // chop

function chop(i:integer; var s:string):string;
begin
result:=copy(s,1,i-1);
delete(s,1,i);
end; // chop

/////// SERVER

function ThttpSrv.start:boolean;
begin
result:=TRUE;
sock.addr:='0.0.0.0';
sock.port:=intToStr(port);
sock.proto:='tcp';
sock.OnSessionAvailable:=connected;
try sock.Listen except result:=FALSE end
end; // start

procedure ThttpSrv.stop;
begin sock.Close end;

procedure ThttpSrv.connected(Sender: TObject; Error: Word);
begin if error=0 then ThttpCln.create(self) end;

constructor ThttpSrv.create();
begin
inherited;
sock:=TWSocket.create(NIL);
clients:=Tlist.create;
Port:=80;
end; // create

destructor ThttpSrv.destroy();
begin
sock.free;
while clients.count > 0 do
  ThttpCln(clients[0]).free;
end; // destroy

function Thttpsrv.getActive():boolean;
begin result:=sock.State=wsListening end;

procedure ThttpSrv.setActive(v:boolean);
begin
if v=active then exit;
if v then start else stop
end; // setactive

procedure ThttpSrv.setPort(v:integer);
begin
if active then
  raise Exception.Create('ThttpSrv: cannot change port while active');
P_port:=v
end; // setPort

function ThttpSrv.getIPs:string;
begin result:=localIPlist.text end;

function ThttpSrv.getIP:string;
var
  i:integer;
  ips:Tstrings;
begin
ips:=LocalIPlist;
case ips.count of
  0: result:='';
  1: result:=ips[0];
  else
    i:=0;
    while (i < ips.count) and (pos('10.',ips[i])+pos('192.168.',ips[i])=1) do
      inc(i);
    result:=ips[i];
  end;
end; // getIP

////////// CLIENT

constructor ThttpCln.create(server:ThttpSrv);
begin
// init socket
sock:=Twsocket.create(NIL);
sock.Dup(server.sock.Accept);
sock.OnDataAvailable:=dataavailable;
sock.OnSessionClosed:=disconnected;
sock.onSendData:=senddata;
sock.onDataSent:=datasent;
sock.LineMode:=FALSE;
sock.flushtimeout:=0;

P_address:=sock.GetPeerAddr;
state:=HCS_IDLE;
srv:=server;
srv.clients.Add(self);
// notify
if assigned(srv.onEvent) then
  srv.onEvent(HE_CONNECTED, self);
end;

destructor ThttpCln.destroy;
begin
srv.clients.remove(self);
sock.free;
inherited;
end; // destroy

function ThttpCln.parseHeader:boolean;
var
  r,s:string;
  i:integer;
begin
result:=FALSE;
r:=request.full;

for i:=1 to 10 do
  if i > length(r) then exit
  else if r[i]=' ' then break;
request.method:=HM_UNK;
s:=uppercase(chop(i, r));
if s='GET' then request.method:=HM_GET else
if s='POST' then request.method:=HM_POST else
if s='HEAD' then request.method:=HM_HEAD else
exit;

request.url:=chop(' ', r);

request.ver:='';
s:=uppercase(chop(CRLF, r));
// if HTTP/ is not found, chop returns S
if chop('HTTP/',s) = '' then request.ver:=s;

request.headers:=r;
result:=TRUE;
end; // parse

procedure ThttpCln.disconnected(Sender: TObject; Error: Word);
begin
state:=HCS_disconnected;
if assigned(srv.onEvent) then srv.onEvent(HE_DISCONNECTED, self);
free;
end; // disconnected
                                                      
function ThttpCln.getHeader(h:string):string;
var
  s,l:string;
begin
result:='';
if request.method = HM_UNK then exit;
s:=request.headers;
  repeat
  l:=chop(CRLF, s);
  if compareText(chop(':',l), h) = 0 then
    begin
    result:=l;
    exit;
    end;
  until s='';
end; // getHeader

procedure ThttpCln.dataavailable(Sender: TObject; Error: Word);

  procedure sendheader(h:string);
  begin
  state:=HCS_REPLYING_HEADER;
  with reply do
    if header='' then
      begin
      header:=h+additionalHeaders;
      // lines must be termined by CRLF
      if copy(header,length(header)-1,2) <> CRLF then header:=header+CRLF;
      end;
  sock.SendStr(reply.header+CRLF);
  end; // sendHeader

var
  i:integer;
begin
if error <> 0 then exit;

if state = HCS_IDLE then state:=HCS_REQUESTING;
buffer:=buffer+sock.ReceiveStr;
if assigned(srv.onEvent) then
  srv.onEvent(HE_GOT, self);
i:=pos(CRLF+CRLF, buffer);
if i < 0 then exit;
request.full:=copy(buffer,1,i-1);
delete(buffer,1,i+4);
if not parseHeader or not assigned(srv.onEvent) then exit;
// initializes reply
reply.mode:=_close;
reply.header:='';
reply.additionalHeaders:='';
reply.bodyMode:=_string;
reply.body:='';
reply.firstByte:=-1;
reply.lastByte:=-1;
srv.OnEvent(HE_REQUESTED, self);
case reply.mode of
  _close: disconnect;
  _ignore: ;
  _deny: sendHeader(replyheader_code(403));
  _not_found: sendHeader(replyheader_code(404));
  _bad_request: sendHeader(replyheader_code(400));
  _internal_error: sendHeader(replyheader_code(500));
  _reply_wo_body,
  _reply:
    if not openFileIfNeeded then
      sendHeader( replyHeader_code(404))
    else
      if reply.header > '' then
        sendHeader('')
      else
        if (reply.firstByte<0) and (reply.lastByte<0) then
          sendHeader( replyHeader_OK( totalBodySize, reply.contentType ) )
        else
          sendHeader( replyHeader_PARTIAL( reply.firstByte,
                                           reply.lastByte,
                                           totalBodySize,
                                           reply.contentType ) );
  end;//case
end; // dataavailable

procedure ThttpCln.senddata(sender:Tobject; bytes:integer);
begin
if bytes <= 0 then exit;
inc(bsent, bytes);
if state = HCS_REPLYING_BODY then inc(bsent_body, bytes);
if assigned(srv.onEvent) then srv.onEvent(HE_SENT, self);
end; // senddata

procedure ThttpCln.datasent(sender:Tobject; error:word);
begin
if bsent = 0 then exit;
if (state = HCS_REPLYING_HEADER) and (reply.mode = _reply) then
  state:=HCS_REPLYING_BODY;
if (state = HCS_REPLYING_BODY) and (bsent_body < length(reply.body)) then
  begin
  sock.SendStr(getNextChunk);
  exit;
  end;
closeFileIfNeeded;
if assigned(srv.onEvent) then srv.onEvent(HE_REPLIED, self);
disconnect;
end;

procedure ThttpCln.disconnect;
begin sock.close end;

function ThttpCln.totalBodySize:integer;
begin
case reply.bodyMode of
  _file: result:=filesize(f);
  _string: result:=length(reply.body);
  else result:=0;
  end;
end; // totalBodySize

function ThttpCln.openFileIfNeeded:boolean;
begin
result:=TRUE;
if ((TFileRec(f).Mode=0) or (TFileRec(f).Mode=fmClosed)) and (reply.bodyMode = _file) then
  begin
  IOresult;
  assignFile(f, reply.body);
  reset(f, 1);
  result:= IOresult=0;
  end;
end; // openFileIfNeeded

procedure ThttpCln.closeFileIfNeeded;
begin if (TFileRec(f).Mode<>0) and (TFileRec(f).Mode<>fmClosed) then closeFile(f) end;

function ThttpCln.getNextChunk;
var
  got:integer;
begin
case reply.bodyMode of
  _string: result:=copy( reply.body, bsent_body+1, chunkSize*1024 );
  _file:
    begin
    setLength( result, chunkSize*1024 );
    blockRead( f, result[1], chunkSize, got );
    setLength( result, got );
    end;
  end;//case
end;

end.
