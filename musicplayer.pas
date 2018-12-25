{$AppType GUI}
{$R MusicPlayer.res}
program MusicPlayer;
uses math,bass,basswma,bassflac,bassape,bassmidi,bass_fx,windows,display,sysutils,lazutf8;

var i,j:longint;
var rvoli:longword;
var framerate:longword=120;
var oldtime:real=0;
var newtime:real=0;
var showfps:boolean;
var showmode:boolean;
const ca:array[0..1]of longword=($9FFFFF,$9F0000);
const cb:array[0..4]of longword=($1FFF1F,$3F3FFF,$00FFFF,$FF00FF,$FF1F1F);
const cc:array[-1..11]of longword=(white,
$FFFF00,$1F9FFF,$FF3F3F,$1FFF9F,$FF00FF,$9FFF1F,
$3F3FFF,$FF9F1F,$00FFFF,$FF1F9F,$3FFF3F,$9F1FFF);
const chdef=8;
var ch:longword=chdef;
var chsum:real;

var stitle:AnsiString;
var stitlew:UnicodeString;
var nowindow:longword=0;
var wpos:longint;

var info:BASS_INFO;
var fdir:unicodestring;
var fnames:unicodestring;
var fname:pwchar;
var sf:BASS_MIDI_FONT;
var fsf2s:unicodestring;
var chan:longword;
var chaninfo:BASS_CHANNELINFO;
var channum:longword;
var bufmul:longword=2;

var len,pos:qword;
var lenr,posr:real;
const volal=14;
const vola:array[1..volal]of real=
(0,0.01,0.02,0.03,0.04,0.06,0.08,0.12,0.16,0.25,0.35,0.5,0.7,1);
var voli:longword=10;
var freq:single=1;
var spd:real=1;
var spdi:longint=0;
var frq:real=1;
var frqi:longint=0;
var pch:real=1;
var pchi:longint=0;
var key_ctrl,key_shift{,key_alt}:boolean;
var key_pos:longword;
var loop:longword;

const maxbuf=$4000;
const maxfft=$1000;
const maxlog=108-21+24;
var buf:array[0..maxbuf-1]of single;
var bufi:array[0..maxbuf-1]of longint;
var fft:array[0..maxfft-1]of single;
var fftlg:array[0..maxlog-1]of single;
var lgmul:real;
var lg:array[0..maxlog]of real;
var lgi:array[0..maxlog]of longint;
var lgr:array[0..maxlog]of real;
var hpos:array[0..maxlog-1]of longint;
var hposc:array[0..maxlog-1]of real;
var x1,y1,x2,y2:longint;
var modei:array[0..4]of shortint;
//var modeb:array[0..11]of shortint=(1,0,0,0,0,0,0,1,0,0,0,0);
const modes:array[-1..11]of ansistring=
('-','A','A#','B','C','C#','D','D#','E','F','F#','G','G#');
var mode:array[-1..11]of shortint;
var modec:shortint;
var fps:longint;

var hwm:HWND;
var para:unicodestring;

//var regdp:DWORD=1;
var regkey:HKEY;

procedure OpenKey();
begin
RegCreateKeyEx(HKEY_CURRENT_USER,
PChar('SoftWare\ax_music_player'),
0,nil,0,KEY_ALL_ACCESS,nil,regkey,nil);
end;

procedure CloseKey();
begin
RegCloseKey(regkey);
end;

procedure GetKeyS(kname:ansistring;var s:unicodestring);
var regtype:longword=REG_SZ;
var ca:array[0..MAXCHAR*2-1]of byte;
var size:longword=MAXCHAR*2;
begin
if RegQueryValueExW(regkey,PWChar(unicodestring(kname)),nil,@regtype,@ca,@size)=ERROR_SUCCESS then
  s:=copy(UnicodeString(pwchar(@ca)),0,length(unicodestring(pwchar(@ca))));
end;

procedure GetKeyQ(kname:ansistring;var i:qword);
var regtype:longword=11;
var ca:array[0..7] of byte;
var size:longword=8;
var ih,io:longword;
begin
if RegQueryValueEx(regkey,PChar(kname),nil,@regtype,@ca,@size)=ERROR_SUCCESS then
  ih:=ca[7] shl 24 or ca[6] shl 16 or ca[5] shl 8 or ca[4];
  io:=ca[3] shl 24 or ca[2] shl 16 or ca[1] shl 8 or ca[0];
  i:=ih shl 32 or io;
end;

procedure GetKeyI(kname:ansistring;var i:longword);
var regtype:longword=REG_DWORD;
var ca:array[0..3] of byte;
var size:longword=4;
begin
if RegQueryValueEx(regkey,PChar(kname),nil,@regtype,@ca,@size)=ERROR_SUCCESS then
  i:=ca[3] shl 24 or ca[2] shl 16 or ca[1] shl 8 or ca[0]
end;

procedure SetKeyS(kname:ansistring;s:unicodestring);
begin
RegSetValueExW(regkey,PWChar(UnicodeString(kname)),0,REG_SZ,PWChar(s),length(s)*2);
end;

procedure SetKeyI(kname:ansistring;i:longword);
begin
RegSetValueEx(regkey,PChar(kname),0,REG_DWORD,@i,sizeof(DWORD));
end;

procedure SetKeyQ(kname:ansistring;i:qword);
begin
RegSetValueEx(regkey,PChar(kname),0,11,@i,sizeof(QWORD));
end;

const find_max=$10000;
var find_info:TUnicodeSearchRec;
var find_count:longword;
var find_current:longword;
var find_result:array[0..find_max] of unicodestring;

procedure find_file(s:unicodestring);
var dir:unicodestring;
begin
find_current:=0;
find_result[0]:='';
repeat
find_current:=find_current+1;
if find_current>find_count then break;
until find_result[find_current]=s;
if find_current>find_count then
  begin
  find_count:=0;
  dir:=ExtractFilePath(s);
  if findfirst(dir+UnicodeString('*'),0,find_info)=0 then
    begin
    find_count:=find_count+1;
    find_result[find_count]:=dir+UnicodeString(find_info.name);
    if find_result[find_count]=s then find_current:=find_count;
    while findnext(find_info)=0 do
      begin
      find_count:=find_count+1;
      find_result[find_count]:=dir+UnicodeString(find_info.name);
      if find_result[find_count]=s then find_current:=find_count;
      end;
    end;
  end;
end;

function get_file(n:longword):unicodestring;
begin
if n<1 then n:=n+find_count;
if n>find_count then n:=n-find_count;
find_current:=n;
get_file:=find_result[find_current];
end;

function mixcolor(c1,c2:longword;mix:real):longword;
var c1r,c1g,c1b:longword;
var c2r,c2g,c2b:longword;
var c3r,c3g,c3b:longword;
begin
if mix>1 then mix:=1;
c1r:=c1 and $0000FF;
c1g:=c1 and $00FF00;
c1b:=c1 and $FF0000;
c2r:=c2 and $0000FF;
c2g:=c2 and $00FF00;
c2b:=c2 and $FF0000;
c3r:=trunc(c1r*mix+c2r*(1-mix)) and $0000FF;
c3g:=trunc(c1g*mix+c2g*(1-mix)) and $00FF00;
c3b:=trunc(c1b*mix+c2b*(1-mix)) and $FF0000;
mixcolor:=c3r or c3g or c3b;
end;

function r2s(r:real):ansistring;
var h,m,s,ss:longword;
begin
if r<0 then r:=0;
ss:=trunc(r*1000);
s:=ss div 1000;
ss:=ss mod 1000;
m:=s div 60;
s:=s mod 60;
h:=m div 60;
m:=m mod 60;
r2s:=i2s(m)+':'+i2s(s,2,'0')+'.'+i2s(ss div 100);
if h>0 then r2s:=i2s(h)+':'+i2s(m,2,'0')+':'+i2s(s,2,'0')+'.'+i2s(ss div 100);
end;

const maxlrc=$1000;
var lrct:array[1..maxlrc]of longword;
var lrcs:array[1..maxlrc]of ansistring;
var lrcnum:longword;
var lrctmax:longword;
var lrcstr:ansistring;

procedure checklrc(s:UnicodeString);
var flrc:text;
var lrc:ansistring;
begin
lrcnum:=0;
if length(s)>0 then
for i:=1 to length(s) do if s[i]='.' then j:=i;
s:=copy(s,1,j-1)+'.lrc';
//if fileexists(s) then
//else s:=copy(s,1,j-1)+'.txt';
if fileexists(s) then
  begin
  assign(flrc,s);
  reset(flrc);
  while not(eof(flrc)) do
    begin
    readln(flrc,lrc);
    if length(lrc)>=10 then
      begin
      if (lrc[1]='[') and (lrc[4]=':') and (lrc[7]='.') and (lrc[10]=']') then
        begin
        lrcnum:=lrcnum+1;
        lrct[lrcnum]:=(ord(lrc[2])-48)*10+ord(lrc[3])-48;
        lrct[lrcnum]:=lrct[lrcnum]*60+(ord(lrc[5])-48)*10+ord(lrc[6])-48;
        lrct[lrcnum]:=lrct[lrcnum]*1000+((ord(lrc[8])-48)*10+ord(lrc[9])-48)*10;
        lrcs[lrcnum]:=copy(lrc,11,length(lrc)-10);
        end;
      if (lrc[1]='[') and (lrc[3]=':') and (lrc[6]='.') and (lrc[10]=']') then
        begin
        lrcnum:=lrcnum+1;
        lrct[lrcnum]:=ord(lrc[2])-48;
        lrct[lrcnum]:=lrct[lrcnum]*60+(ord(lrc[4])-48)*10+ord(lrc[5])-48;
        lrct[lrcnum]:=lrct[lrcnum]*1000+((ord(lrc[7])-48)*10+ord(lrc[8])-48)*10;
        lrcs[lrcnum]:=copy(lrc,11,length(lrc)-10);
        end;
      end;
    end;
  close(flrc);
  end;
end;

procedure savefile();
begin
SetKeyS('fnames',fnames);
SetKeyS('fsf2s',fsf2s);
SetKeyQ('pos',pos);
SetKeyI('voli',voli);
SetKeyI('nowindow',nowindow);
SetKeyI('bufmul',bufmul);
SetKeyI('ch',ch);
SetKeyI('framerate',framerate);
SetKeyI('loop',loop);
end;

procedure playfile(s:unicodestring);forward;

procedure loadfile();
begin
GetKeyS('fnames',fnames);
GetKeyS('fsf2s',fsf2s);
GetKeyQ('pos',pos);
GetKeyI('voli',voli);
GetKeyI('nowindow',nowindow);
GetKeyI('bufmul',bufmul);
GetKeyI('ch',ch);
GetKeyI('framerate',framerate);
GetKeyI('loop',loop);
if (para<>'') and (para<>fnames) then begin fnames:=para;pos:=0;end;
if fileexists(fnames) then playfile(fnames);
Bass_ChannelSetPosition(chan,pos,BASS_POS_BYTE);
if fileexists(fsf2s) then playfile(fsf2s);
end;

procedure playfile(s:unicodestring);
begin
if copy(s,length(s)-2,3)='sf2' then fsf2s:=s
else
begin
find_file(s);
//SetForegroundWindow(_hw);
//ShowWindow(_hw,SW_SHOWNORMAL);
fnames:=s;
fname:=PWChar(s);
Bass_MusicFree(chan);
Bass_StreamFree(chan);
chan:=Bass_StreamCreateFile(false,fname,0,0,BASS_STREAM_DECODE or BASS_STREAM_PRESCAN or BASS_UNICODE);
chan:=Bass_FX_TempoCreate(chan,BASS_FX_FREESOURCE or loop);
if (chan=0) then chan:=Bass_WMA_StreamCreateFile(false,fname,0,0,loop);
if (chan=0) then chan:=Bass_FLAC_StreamCreateFile(false,fname,0,0,loop);
if (chan=0) then chan:=Bass_APE_StreamCreateFile(false,fname,0,0,loop);
if (chan=0) then chan:=Bass_MusicLoad(false,fname,0,0,loop or BASS_STREAM_PRESCAN or BASS_MUSIC_RAMPS,1);
if (chan=0) then chan:=Bass_MIDI_StreamCreateFile(false,fname,0,0,loop,1);
end;
if chan<>0 then
begin
checklrc(s);
sf.font:=Bass_MIDI_FontInit(PChar(fsf2s),0);
sf.preset:=-1;
sf.bank:=0;
Bass_MIDI_StreamSetFonts(chan,PBASS_MIDI_FONT(@sf),1);
Bass_channelPlay(chan,false);
BASS_ChannelSetAttribute(chan,BASS_ATTRIB_VOL,vola[voli]);
BASS_ChannelGetAttribute(chan,BASS_ATTRIB_FREQ,freq);
spd:=1;spdi:=0;
pch:=1;pchi:=0;
frq:=1;frqi:=0;
BASS_ChannelGetInfo(chan,chaninfo);
channum:=chaninfo.chans;
savefile();
end;
end;

procedure getdata();
begin
len:=Bass_ChannelGetLength(chan,BASS_POS_BYTE);
pos:=Bass_ChannelGetPosition(chan,BASS_POS_BYTE);
if len>0 then pos:=pos mod len;
posr:=Bass_ChannelBytes2Seconds(chan,pos);
lenr:=Bass_ChannelBytes2Seconds(chan,len);
if len>0 then wpos:=trunc(_w*pos/len) else wpos:=0;
stitle:='';
//while (System.pos('\',stitle)>0) do delete(stitle,1,System.pos('\',stitle));
stitle:=stitle+'['+r2s(posr)+'/'+r2s(lenr)+']';
if vola[voli]<1 then stitle:=stitle+'['+i2s(longword(round(vola[voli]*100)))+'%]';
if loop=0 then stitle:=stitle+'['+i2s(find_current)+'/'+i2s(find_count)+']'
else stitle:=stitle+'<'+i2s(find_current)+'/'+i2s(find_count)+'>';
if spdi>0 then stitle:=stitle+'[+'+i2s(abs(spdi))+']';
if spdi<0 then stitle:=stitle+'[-'+i2s(abs(spdi))+']';
if pchi>0 then stitle:=stitle+'<+'+i2s(abs(pchi))+'>';
if pchi<0 then stitle:=stitle+'<-'+i2s(abs(pchi))+'>';
if frqi>0 then stitle:=stitle+'(+'+i2s(abs(frqi))+')';
if frqi<0 then stitle:=stitle+'(-'+i2s(abs(frqi))+')';
if bufmul<>2 then stitle:=stitle+'<'+i2s(bufmul)+'>';
if ch<>chdef then stitle:=stitle+'<='+i2s(ch)+'>';
if nowindow=BASS_DATA_FFT_NOWINDOW then stitle:=stitle+'<Hn>';
stitlew:=UnicodeString(stitle)+ExtractFileName(fnames);
if not(Bass_channelIsActive(chan)=BASS_ACTIVE_STOPPED) then
  SetTitleW(stitlew);
if Bass_channelIsActive(chan)=BASS_ACTIVE_PLAYING then
  begin
  Bass_ChannelGetData(chan,@fft,BASS_DATA_FFT4096 or nowindow);
  Bass_ChannelGetData(chan,@buf,maxbuf or BASS_DATA_FLOAT);
  end;
for i:=0 to maxbuf-1 do
  bufi[i]:=trunc((buf[i]/2+1/2)*_h);
for i:=0 to maxlog-1 do
  begin
  fftlg[i]:=(fft[lgi[i+1]]+(fft[lgi[i+1]+1]-fft[lgi[i+1]])*lgr[i+1]/2)*lgr[i+1];
  fftlg[i]:=fftlg[i]-(fft[lgi[i]]+(fft[lgi[i]+1]-fft[lgi[i]])*lgr[i]/2)*lgr[i];
  for j:=lgi[i] to lgi[i+1]-1 do fftlg[i]:=fftlg[i]+(fft[j]+fft[j+1])/2;
  end;
for i:=0 to maxlog-1 do
  begin
  if fftlg[i]<0 then fftlg[i]:=0;
  hpos[i]:=trunc(sqrt(fftlg[i])*_h*maxlog/128);
  if hpos[i]>_h then hpos[i]:=_h;
  end;
end;

function getmode(start,step:shortint):shortint;
//var modea,modeas:array[-1..11]of real;
begin           {
getmode:=-1;
modeas[-1]:=0;
for i:=start to start+step*12 do
  modea[i mod 12]:=sqrt(hposc[i]);
for j:=0 to 11 do
  begin
  modeas[j]:=0;
  for i:=0 to 11 do
    modeas[j]:=modeas[j]+ln(modea[i]+1)*(modeb[(i-j+24)mod 12]);
  if modeas[j]>modeas[getmode] then getmode:=j;
  end;         }
getmode:=start;
for i:=start to start+step*12 do
  if hposc[i]>hposc[getmode] then
    getmode:=i;
getmode:=getmode mod 12;
end;

function maxr(x,y:real):real;
begin if x>y then maxr:=x else maxr:=y;end;

procedure drawwin();
begin
Clear();
_fx:=0;_fy:=0;
GetData();
chsum:=1;
for i:=0 to maxlog-1 do
  begin
  if i=0 then
    hposc[i]:=sqrt(hpos[i])*maxr(0,hpos[i]/(hpos[i+1]+1)-1)*maxr(0,hpos[i]/(hpos[i+1]+1)-1)
  else if i=maxlog-1 then
    hposc[i]:=sqrt(hpos[i])*maxr(0,hpos[i]/(hpos[i-1]+1)-1)*maxr(0,hpos[i]/(hpos[i-1]+1)-1)
  else
    hposc[i]:=sqrt(hpos[i])*maxr(0,hpos[i]/(hpos[i-1]+1)-1)*maxr(0,hpos[i]/(hpos[i+1]+1)-1);
  hposc[i]:=sqrt(hposc[i]);
  chsum:=chsum+hposc[i];
  end;
for i:=0 to maxlog-1 do
  begin
  x1:=trunc(i/maxlog*_w);
  x2:=trunc((i+1)/maxlog*_w);
  y1:=_h-hpos[i];
  y2:=_h;
  bar(x1,y1,x2-x1,y2-y1,mixcolor(cc[(118-i) mod 12],ca[0],maxlog*hposc[i]/chsum/ch));
  end;
if channum>0 then
for i:=0 to _w*channum div bufmul+1 do
  begin
  x1:=i div channum*bufmul;
  x2:=(i div channum+1)*bufmul;
  y1:=bufi[i];
  y2:=bufi[i+channum];
  line(x1,y1,x2-x1,y2-y1,cb[channum-(i mod channum)-1]);
  end;
modei[1]:=getmode(36,1);
modei[2]:=getmode(48,1);
modei[3]:=getmode(60,1);
modei[4]:=getmode(36,3);
for i:=-1 to 11 do mode[i]:=0;
mode[modei[0]]:=mode[modei[0]]+3;
mode[modei[1]]:=mode[modei[1]]+2;
mode[modei[2]]:=mode[modei[2]]+2;
mode[modei[3]]:=mode[modei[3]]+2;
mode[modei[4]]:=mode[modei[4]]+2;
//modec:=5;
for j:=6 to 13 do
  for i:=-1 to 11 do
    if mode[i]=j then
      begin
      modei[0]:=i;
      modec:=j;
      end;
modec:=100;
if showmode then
  begin
  if modei[0]>=0 then
    drawtextln(modes[(modei[0]+frqi+120) mod 12],mixcolor(cc[(118-modei[0]) mod 12],ca[1],(modec-3)/4))
  else
    drawtextln(modes[modei[0]],mixcolor(cc[(118-modei[0]) mod 12],ca[1],(modec-3)/4))
  end;
fps:=getfps;
showfps:=abs(framerate-getfpsr)>1;
if showfps then drawtextln(i2s(framerate)+'/'+i2s(fps),white);
line(wpos,0,0,_h,white);
//line(0,0,trunc(rvol/5*_w),0,yellow);
rvoli:=BASS_ChannelGetLevel(chan);
rvoli:=hi(rvoli)+lo(rvoli);
line(0,0,trunc(rvoli/65536*_w),0,yellow);
lrcstr:='';
lrctmax:=0;
for i:=1 to lrcnum do
  if (posr*1000>=lrct[i]) and (lrctmax<lrct[i]) then
    begin
    lrcstr:=lrcs[i];
    lrctmax:=lrct[i];
    end;
setfontheight(round(_w*2.3)div max(54,length(lrcstr)));
drawtextxy(lrcstr,max(0,round((_w-getstringwidth(lrcstr))/2)),0,white);
freshwin();
end;

procedure helpproc();
begin
  if fileexists(fdir+UnicodeString('musicplayer.txt')) then
    ShellExecuteW(0,nil, PWChar(UnicodeString('notepad.exe')),PWChar(fdir+UnicodeString('musicplayer.txt')),nil,1)
  else
    MsgBoxW(UnicodeString('Missing help file: ')+fdir+UnicodeString('musicplayer.txt'),UnicodeString('Help file not found!'));
end;

procedure makeact();
begin
if ismsg(WM_USER) then
  begin
  if _ms.lParam=0 then para:=para+widechar(_ms.wParam mod $10000);
  if _ms.lParam=1 then para:='';
  if _ms.lParam=2 then Playfile(para);
  end;
if isdropfile() then
  Playfile(getdropfilew());
if (ismouse() or ismsg($200)) and (_ms.wparam=1) then
  begin
  wpos:=getmouseposx();
//  wpos:=_ms.pt.x-GetPosX-GetBorderWidth;
  while IsNextMsg do ;
  if wpos<0 then wpos:=0;
  pos:=trunc(len*wpos/_w);
  Bass_ChannelSetPosition(chan,pos,BASS_POS_BYTE);
  end;
key_shift:=GetKeyState(VK_SHIFT)<0;
key_ctrl:=GetKeyState(VK_CONTROL)<0;
//key_alt:=GetKeyState(VK_MENU)<0;
if iskey(K_RIGHT) or iskey(K_LEFT) then
  begin
  key_pos:=1;
  if key_ctrl then key_pos:=5;
  if key_shift then key_pos:=30;
  if iskey(K_RIGHT) then posr:=posr+key_pos;
  if iskey(K_LEFT) then posr:=posr-key_pos;
  if posr>lenr then posr:=0;
  if posr<0 then posr:=0;
  pos:=Bass_ChannelSeconds2Bytes(chan,posr);
  Bass_ChannelSetPosition(chan,pos,BASS_POS_BYTE);
  end;
if iskey(K_UP) or iskey(K_DOWN) or ismousewheel then
  begin
  if iskey(K_UP) or (ismousewheel and (_ms.wParam>0)) then voli:=voli+1;
  if iskey(K_DOWN) or (ismousewheel and (_ms.wParam<0)) then voli:=voli-1;
  if voli>volal then voli:=volal;
  if voli<1 then voli:=1;
  BASS_ChannelSetAttribute(chan,BASS_ATTRIB_VOL,vola[voli]);
  end;
if iskey(K_PGUP) or iskey(K_PGDN) or iskey(K_HOME) or iskey(K_END) then
  begin
  if iskey(K_PGUP) then playfile(get_file(find_current-1));
  if iskey(K_PGDN) then playfile(get_file(find_current+1));
  if iskey(K_HOME) then playfile(get_file(1));
  if iskey(K_END) then playfile(get_file(find_count));
  end;
if iskey(187) or iskey(189) then
  begin
  if iskey(187) and (spdi<+48) then begin spd:=spd*lgmul;spdi:=spdi+1;end;
  if iskey(189) and (spdi>-48) then begin spd:=spd/lgmul;spdi:=spdi-1;end;
  Bass_ChannelSetAttribute(chan,BASS_ATTRIB_TEMPO,(spd-1)*100);
  end;
if iskey(219) or iskey(221) then
  begin
  if iskey(221) and (pchi<+60) then begin pch:=pch*lgmul;pchi:=pchi+1;end;
  if iskey(219) and (pchi>-60) then begin pch:=pch/lgmul;pchi:=pchi-1;end;
  Bass_ChannelSetAttribute(chan,BASS_ATTRIB_TEMPO_PITCH,pchi);
  end;
if iskey(K_ADD) or iskey(K_SUB) then
  begin
  if iskey(K_ADD) then begin frq:=frq*lgmul;frqi:=frqi+1;end;
  if iskey(K_SUB) then begin frq:=frq/lgmul;frqi:=frqi-1;end;
  if frq*freq>info.maxrate then begin frq:=frq/lgmul;frqi:=frqi-1;end;
  if frq*freq<info.minrate then begin frq:=frq*lgmul;frqi:=frqi+1;end;
  Bass_ChannelSetAttribute(chan,BASS_ATTRIB_FREQ,trunc(frq*freq));
  end;
if iskey(K_F3) or iskey(K_F4) then
  begin
  if iskey(K_F3) then bufmul:=bufmul-1;
  if iskey(K_F4) then bufmul:=bufmul+1;
  if bufmul=0 then bufmul:=1;
  end;
if iskey(K_F5) or iskey(K_F6) then
  begin
  if iskey(K_F6) then ch:=ch*2;
  if iskey(K_F5) then ch:=ch div 2;
  if ch<1 then ch:=1;
  if ch>512 then ch:=512;
  end;
if iskey(K_F7) or iskey(K_F8) then
  begin
  if iskey(K_F7) and (framerate>10) then framerate:=framerate-((framerate-1) div 60+1);
  if iskey(K_F8) and (framerate<360) then framerate:=framerate+(framerate div 60+1);
  showfps:=true;
  end;
if iskey(K_F12) then
  begin
  loop:=loop xor BASS_SAMPLE_LOOP;
  playfile(get_file(find_current));
  end;
if iskey(K_F11) then showmode:=not(showmode);
if iskey(K_SPACE) or ismouseright then
  if not(Bass_ChannelPause(chan)) then Bass_ChannelPlay(chan,false);
if iskey(K_F2) then
  nowindow:=BASS_DATA_FFT_NOWINDOW-nowindow;
if iskey(K_F1) then
  newthread(@helpproc);
if iskey(K_ESC) then
  CloseWin();
end;

procedure LoopAudio();
var s:unicodestring;
begin
len:=Bass_ChannelGetLength(chan,BASS_POS_BYTE);
pos:=Bass_ChannelGetPosition(chan,BASS_POS_BYTE);
if pos>=len then
  if Bass_channelIsActive(chan)=BASS_ACTIVE_STOPPED then
    begin
    s:=get_file(find_current+1);
    if not(copy(s,length(s)-2,3)='exe')then
      if not(copy(s,length(s)-2,3)='dll')then
        playfile(s);
    end;
end;

procedure DoDraw();
begin
newtime:=gettimer;
if newtime>oldtime+1/framerate then
  begin
  while newtime>oldtime+1/framerate do oldtime:=oldtime+1/framerate;
  drawwin();
  end
else
  sleep(1);
end;

procedure DoDrawThread();
begin
while IsWin do DoDraw();
end;

procedure initwin();
begin
_w:=round(getscrwidth/2.5*GetScrCapsX);_h:=round(getscrheight/4*GetScrCapsY);
createwin(_w,_h,ca[1],ca[1]);
_wc.HIcon:=LoadImage(0,'musicplayer.ico',IMAGE_ICON,0,0,LR_LOADFROMFILE);
sendmessage(_hw,WM_SETICON,ICON_SMALL,longint(_wc.HIcon));
SetTitleW('MusicPlayer made by ax_pokl');
setfontname('Arial');
setpenwidth(2);
end;

procedure initbass();
begin
Bass_Init(-1,44100,0,0,nil);
BASS_GetInfo(info);
end;

procedure initvar();
begin
lgmul:=power(2,1/12);
lg[0]:=27.5/(44100/4096)/sqrt(lgmul);
for i:=1 to maxlog do lg[i]:=lg[i-1]*lgmul;
for i:=0 to maxlog do lgi[i]:=trunc(lg[i]);
for i:=0 to maxlog do lgr[i]:=lg[i]-lgi[i];
end;

begin
OpenKey();
hwm:=FindWindow('DisplayClass',nil);
fdir:=UnicodeString(ParamStrUTF8(0));
repeat
if length(fdir)>0 then delete(fdir,length(fdir),1);
until (length(fdir)<=1) or (fdir[length(fdir)]='\');
fsf2s:=fdir+'midi.sf2';
para:=UnicodeString(ParamStrUTF8(1));
if hwm<>0 then
  if para<>'' then
    begin
    SendMessage(hwm,WM_USER,0,1);
    for i:=1 to length(para) do
    begin
      SendMessage(hwm,WM_USER,longword(word(para[i])),0);
      end;
    SendMessage(hwm,WM_USER,0,2);
    halt;
    end;
//finis:=fdir+'musicplayer.ini';
//assign(fini,finis);
initwin();
initvar();
initbass();
loadfile();
NewThread(@DoDrawThread);
repeat
LoopAudio();
if IsNextMsg() then makeact()
else delay(1);
until not(IsWin);
Bass_ChannelStop(chan);
savefile();
end.
