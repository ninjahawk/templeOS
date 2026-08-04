/* Urim -- an oracle for TempleOS.

Terry built a lot-casting machine and called it a temple. The theology is
cleromancy: Proverbs 16:33, "The lot is cast into the lap, but the whole
disposing thereof is of the LORD." That premise makes demands of the
implementation, and stock TempleOS meets almost none of them:

  1. The lot must not be predetermined. GodWord draws from a deterministic
     PRNG -- given the seed, every word it will ever produce is already
     computable. Here the draw comes from RDRAND, and optionally from
     measured quantum vacuum fluctuation loaded by UrimSeed.
  2. The text must be able to carry meaning. GodWord returns dictionary
     words with no context. Here the draw lands in the King James Bible
     already shipped at ::/Misc/Bible.TXT, and is cited by book and verse.
  3. There must be a question. GodWord answers nothing in particular.
     Nothing is drawn here until one is stated.
  4. There must be a record, or the practice can never be found wrong.
     Every consultation is appended to a journal: the question, the
     provenance of the entropy, the raw draw, the citation, the reading
     committed at the time, and an outcome left blank to fill in later.

What this cannot do is establish that anything is on the other end. No
instrument can. It can refuse to fake the one part it controls -- whether
the draw was genuinely undetermined. */

#define URIM_BIBLE   "::/Misc/Bible.TXT"
#define URIM_JOURNAL "::/Home/Urim.Journal.TXT"

/* Offset of "1:1 In the beginning". Everything before it is Project
   Gutenberg front matter and must never be drawn. */
#define URIM_BODY_MIN 12207
#define URIM_TAIL     "End of the Project Gutenberg Edition of the New Testament"

U64 urim_val=0,urim_ok=0;
U64 urim_q=0,urim_q_fresh=0;
U8 urim_qsrc[64];

U0 UrimRaw()
{
asm {
DU8 0x48,0x0F,0xC7,0xF0;
MOV U64 [&urim_val],RAX
MOV RAX,0
SETC AL
MOV U64 [&urim_ok],RAX
}
}

/* RDRAND reports failure by clearing carry, so a caller that ignores it gets
   silent zeroes. Intel's guidance is ten retries, then treat the hardware as
   broken rather than fall back to something weaker. */
U64 UrimRand()
{
I64 i;
for (i=0;i<10;i++)
{
UrimRaw();
if (urim_ok)
return urim_val;
}
"RDRAND FAILED -- refusing to draw\n";
return 0;
}

/* RDRAND is a deterministic generator reseeded from a thermal noise circuit,
   and under emulation it is the host kernel's pool. Both are unpredictable in
   practice, neither is indeterminate in principle. A seed measured from
   quantum vacuum fluctuation is, so far as physics knows, genuinely not
   determined by anything -- which is the property the theology actually asks
   for. It is XOR'd into the draw, so the result is at least as unpredictable
   as the better of the two sources. The seed is spent after one draw, and
   the journal records which sources were used. */
U0 UrimSeed(U64 q,U8 *src)
{
urim_q=q;
urim_q_fresh=1;
StrCpy(urim_qsrc,src);
"Seed loaded from %s: %016X\n",src,q;
}

I64 UrimParaStart(U8 *b,I64 at)
{
I64 i;
i=at;
while (i>1)
{
if (b[i-1]=='\n'&&b[i-2]=='\n')
return i;
i--;
}
return 0;
}

I64 UrimParaEnd(U8 *b,I64 sz,I64 at)
{
I64 i;
i=at;
while (i<sz-1)
{
if (b[i]=='\n'&&b[i+1]=='\n')
return i;
i++;
}
return sz;
}

Bool UrimIsDigit(U8 c)
{
return c>='0'&&c<='9';
}

/* Walk forward to a paragraph beginning "chapter:verse", skipping book
   headings and the occasional stray line in the Gutenberg text. */
I64 UrimVerseAt(U8 *b,I64 sz,I64 at)
{
I64 p;
p=UrimParaStart(b,at);
while (p<sz&&!UrimIsDigit(b[p]))
{
p=UrimParaEnd(b,sz,p)+1;
while (p<sz&&b[p]=='\n')
p++;
}
return p;
}

/* Every book opens at 1:1, so the nearest preceding "1:1 " locates the heading
   that names the book.

   The heading is not always one line. 1 Samuel is titled "The First Book of
   Samuel, otherwise called, The First Book of the Kings" across three, and
   taking only the last line cites it as First Kings -- a wrong reference in a
   record whose whole purpose is being checkable. So walk back over heading
   lines and join them.

   Heading lines sit one blank line apart, while the testament banner far above
   is separated by several. A gap wider than one blank line therefore ends the
   heading, which keeps "The Old Testament of the King James Version of the
   Bible" out of every citation in Genesis. */
U0 UrimBook(U8 *b,I64 p,U8 *out)
{
I64 j,he,cur,s,i,k,o,nl,nn;
I64 ls[4],le[4];
out[0]=0;
j=p;
while (j>1)
{
if (b[j]=='\n'&&b[j+1]=='1'&&b[j+2]==':'&&b[j+3]=='1'&&b[j+4]==' ')
break;
j--;
}
if (j<=1)
return;
he=j;
nl=0;
cur=he;
while (nl<3&&cur>1)
{
nn=0;
while (cur>0&&(b[cur]=='\n'||b[cur]==' '))
{
if (b[cur]=='\n')
nn++;
cur--;
}
if (cur<=1)
break;
if (nl>0&&nn>2)
break;
s=cur;
while (s>0&&b[s-1]!='\n')
s--;
if (b[s]>='0'&&b[s]<='9')
break;
if (cur-s>=130)
break;
ls[nl]=s;
le[nl]=cur;
nl++;
cur=s-1;
}
o=0;
for (i=nl-1;i>=0;i--)
{
if (o>0&&o<130)
{
out[o]=' ';
o++;
}
for (k=ls[i];k<=le[i];k++)
if (o<130)
{
out[o]=b[k];
o++;
}
}
out[o]=0;
}

U0 UrimRef(U8 *b,I64 p,I64 *ch,I64 *vs)
{
I64 i,c,v;
i=p;
c=0;
v=0;
while (UrimIsDigit(b[i]))
{
c=c*10+b[i]-'0';
i++;
}
if (b[i]==':')
i++;
while (UrimIsDigit(b[i]))
{
v=v*10+b[i]-'0';
i++;
}
*ch=c;
*vs=v;
}

I64 UrimCount(U8 *j,I64 sz)
{
I64 i,n;
n=0;
if (!j)
return 0;
for (i=0;i<sz-12;i++)
if (!MemCmp(j+i,"CONSULTATION",12))
n++;
return n;
}

/* Locate the Gutenberg licence that trails the text, so no draw lands in it. */
I64 UrimBodyMax(U8 *b,I64 sz)
{
I64 p,tl;
tl=StrLen(URIM_TAIL);
for (p=URIM_BODY_MIN;p<sz-tl;p++)
if (b[p]=='E')
if (!MemCmp(b+p,URIM_TAIL,tl))
return p;
return sz;
}

U0 Urim()
{
I64 bsz,jsz,body_max,off,p,pe,np,ch,vs,n,left;
U64 draw,hw;
U8 *b,*jr,*nj,*q,*reading,*passage,*rec;
U8 book[140],when[64],prov[64];

bsz=0;
jsz=0;

q=GetStr("QUESTION> ");
if (!q||!*q)
{
"Nothing was asked, so nothing is drawn.\n";
return;
}

b=FileRead(URIM_BIBLE,&bsz);
if (!b)
{
"Cannot read the corpus.\n";
Free(q);
return;
}

body_max=UrimBodyMax(b,bsz);

hw=UrimRand();
if (!hw)
{
Free(b);
Free(q);
return;
}
draw=hw;
if (urim_q_fresh)
{
draw=hw^urim_q;
StrPrint(prov,"rdrand ^ %s",urim_qsrc);
urim_q_fresh=0;
}
else
StrCpy(prov,"rdrand");

off=URIM_BODY_MIN+draw%(body_max-URIM_BODY_MIN);
p=UrimVerseAt(b,bsz,off);
pe=UrimParaEnd(b,bsz,p);

/* The drawn verse, plus the two that follow, so it can be read in context. */
left=2;
while (left>0&&pe<body_max)
{
np=pe+1;
while (np<bsz&&b[np]=='\n')
np++;
if (!UrimIsDigit(b[np]))
break;
pe=UrimParaEnd(b,bsz,np);
left--;
}
if (pe-p>3800)
pe=p+3800;

passage=MAlloc(4096);
MemCpy(passage,b+p,pe-p);
passage[pe-p]=0;

UrimBook(b,p,book);
UrimRef(b,p,&ch,&vs);

/* FileRead raises a visible error on a missing file, and on the very first
   consultation the journal legitimately does not exist yet. */
jr=NULL;
if (FileFind(URIM_JOURNAL))
jr=FileRead(URIM_JOURNAL,&jsz);
n=UrimCount(jr,jsz)+1;

"\n----------------------------------------\n";
"CONSULTATION %d\n",n;
"QUESTION  %s\n",q;
"ENTROPY   %s\n",prov;
"DRAW      %016X\n",draw;
"OFFSET    %d of %d\n",off,body_max;
"PASSAGE   %s %d:%d\n\n",book,ch,vs;
"%s\n",passage;
"----------------------------------------\n";

/* The reading is committed now, before the outcome is known. That is the
   entire point of writing it down. */
reading=GetStr("READING> ");

StrPrint(when,"%D %T",Now(),Now());

rec=MAlloc(8192);
rec[0]=0;
CatPrint(rec,"================================================================\n");
CatPrint(rec,"CONSULTATION %d\n",n);
CatPrint(rec,"WHEN      %s\n",when);
CatPrint(rec,"QUESTION  %s\n",q);
CatPrint(rec,"ENTROPY   %s\n",prov);
CatPrint(rec,"DRAW      %016X\n",draw);
CatPrint(rec,"OFFSET    %d of %d\n",off,body_max);
CatPrint(rec,"PASSAGE   %s %d:%d\n",book,ch,vs);
CatPrint(rec,"%s\n",passage);
if (reading)
CatPrint(rec,"READING   %s\n",reading);
else
CatPrint(rec,"READING   \n");
CatPrint(rec,"OUTCOME   \n");
CatPrint(rec,"================================================================\n\n");

nj=MAlloc(jsz+StrLen(rec)+16);
if (jr)
MemCpy(nj,jr,jsz);
MemCpy(nj+jsz,rec,StrLen(rec));
FileWrite(URIM_JOURNAL,nj,jsz+StrLen(rec));

"Recorded as consultation %d in %s\n",n,URIM_JOURNAL;

Free(nj);
Free(rec);
Free(passage);
if (jr)
Free(jr);
Free(b);
Free(q);
if (reading)
Free(reading);
}

U0 UrimLog()
{
UDump(URIM_JOURNAL);
}
