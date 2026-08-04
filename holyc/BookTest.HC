/* Regression test for UrimBook. 1134990 is the draw that cited 1 Samuel as
   "The First Book of the Kings"; 20000 lands in Genesis, whose heading sits
   below the testament banner and must not absorb it. */
U0 BookOne(U8 *b,I64 sz,I64 off)
{
I64 p,ch,vs;
U8 bk[140],line[300];
p=UrimVerseAt(b,sz,off);
UrimBook(b,p,bk);
UrimRef(b,p,&ch,&vs);
StrPrint(line,"%d -> [%s] %d:%d\n",off,bk,ch,vs);
UStr(line);
}

U0 BookTest()
{
I64 sz=0;
U8 *b=FileRead("::/Misc/Bible.TXT",&sz);
if (!b)
return;
BookOne(b,sz,20000);
BookOne(b,sz,1134990);
BookOne(b,sz,2747632);
BookOne(b,sz,4000000);
Free(b);
}
