U0 PeekAt(U8 *b,I64 sz,I64 at,I64 n,U8 *label)
{
U8 buf[700];
if (at<0)
at=0;
if (at+n>sz)
n=sz-at;
MemCpy(buf,b+at,n);
buf[n]=0;
UStr(label);
UStr("[");
UStr(buf);
UStr("]\n");
}

U0 Peek2()
{
I64 sz=0,i,first=-1,last=-1;
U8 *b=FileRead("::/Misc/Bible.TXT",&sz);
U8 buf[200];
if (!b)
return;
for (i=0;i<sz-5;i++)
{
if (b[i]=='\n'&&b[i+1]=='1'&&b[i+2]==':'&&b[i+3]=='1'&&b[i+4]==' ')
{
first=i;
break;
}
}
for (i=sz-6;i>0;i--)
{
if (b[i]=='\n'&&b[i+1]>='0'&&b[i+1]<='9'&&b[i+2]>='0'&&b[i+2]<='9')
{
last=i;
break;
}
}
StrPrint(buf,"size=%d first11=%d lastverse=%d\n",sz,first,last);
UStr(buf);
PeekAt(b,sz,first-600,650,"BEFORE_FIRST");
PeekAt(b,sz,last-200,500,"AT_LAST");
PeekAt(b,sz,sz-400,400,"TAIL");
Free(b);
}
Peek2;
