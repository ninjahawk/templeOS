/* U -- host channel.

TempleOS cannot write ext4 and Linux cannot read RedSea, so the only way work
gets off this machine is QEMU's debug console: every byte written to port 0xE9
lands in a file on the host. UDump is also how typed-in source gets verified,
since a dropped keystroke would otherwise sit undetected in a source file. */

U0 UCh(U8 c)
{
OutU8(0xE9,c);
}

U0 UStr(U8 *s)
{
while (*s)
UCh(*s++);
}

U0 UDump(U8 *fn)
{
I64 sz=0,i;
U8 *b=FileRead(fn,&sz);
if (!b)
{
UStr("<<<NOFILE>>>\n");
return;
}
UStr("<<<BEGIN>>>\n");
for (i=0;i<sz;i++)
UCh(b[i]);
UStr("<<<END>>>\n");
Free(b);
}
