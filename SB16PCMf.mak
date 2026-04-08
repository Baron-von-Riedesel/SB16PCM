
# creates a 32-bit protected-mode, zero-based flat variant

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

ALL: $(OUTDIR) $(OUTDIR)\$(name)f.exe

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(name)f.exe: $*.obj
	@jwlink $(LOPTD) format win pe hx f $* op q,m=$*,stub=\hx\bin\loadpe.bin,stack=8192

$(OUTDIR)\$(name)f.obj: $(name)f.asm
	@jwasm -c -nologo -D?MODEL=flat -Fl$* -Fo$* -coff -IInclude32 $(AOPTD) $(name)f.asm

