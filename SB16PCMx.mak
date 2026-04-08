
# creates a 16-bit protected-mode, small variant

name = SB16PCMx

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

ALL: $(OUTDIR) $(OUTDIR)\$(name).exe

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(name).exe: $*.obj
	@jwlink $(LOPTD) format dos f $* op q,m=$*

$(OUTDIR)\$(name).obj: $(name).asm
	@jwasm -c -nologo -Fl$* -Sg -Fo$* -IInclude16 $(AOPTD) $(name).asm

