U64 g_val=0,g_ok=0;

U0 TRaw()
{
asm {
DU8 0x48,0x0F,0xC7,0xF0;
MOV U64 [&g_val],RAX
MOV RAX,0
SETC AL
MOV U64 [&g_ok],RAX
}
}

U0 TT()
{
U8 b[120];
I64 i;
for (i=0;i<4;i++)
{
TRaw;
StrPrint(b,"val=%016X ok=%d\n",g_val,g_ok);
UStr(b);
}
}
