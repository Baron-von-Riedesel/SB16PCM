
# creates a 32-bit protected-mode, tiny variant

name = SB16PCM

DEBUG=0

!if $(DEBUG)
LOPTD=debug c op cvp
AOPTD=-Zi
OUTDIR=Debug
!else
LOPTD=
AOPTD=
OUTDIR=Release
!endif

ALL: $(OUTDIR) $(OUTDIR)\$(name)t.exe

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(name)t.exe: $*.obj
	@jwlink $(LOPTD) format dos f $* op q,m=$*

$(OUTDIR)\$(name)t.obj: $(name)f.asm
	@jwasm -c -nologo -D?MODEL=tiny -Fl$* -Fo$* -IInclude32 $(AOPTD) $(name)f.asm

