
# this variant of SB16PCMr reads an Audio-CD instead of a file.

name1 = SB16CDr

DEBUG=0

!if $(DEBUG)
OUTDIR=Debug
!else
OUTDIR=Release
!endif

ALL: $(OUTDIR) $(OUTDIR)\$(name1).exe

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(name1).exe: $(name1).asm
	@jwasm -mz -nologo -Fl$* -Fo$* -IInclude16 $(name1).asm
