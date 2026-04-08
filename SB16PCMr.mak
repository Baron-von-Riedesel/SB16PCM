
# creates 2 real-mode variants
# first uses DOS memory, second uses VDS DMA buffer.

name1 = SB16PCMr
name2 = SB16PCMv

DEBUG=0

!if $(DEBUG)
OUTDIR=Debug
!else
OUTDIR=Release
!endif

ALL: $(OUTDIR) $(OUTDIR)\$(name1).exe $(OUTDIR)\$(name2).exe

$(OUTDIR):
	@mkdir $(OUTDIR)

$(OUTDIR)\$(name1).exe: $(name1).asm
	@jwasm -mz -nologo -Fl$* -Fo$* -IInclude16 $(name1).asm

$(OUTDIR)\$(name2).exe: $(name1).asm
	@jwasm -mz -nologo -Fl$* -Fo$* -DUSEVDS=1 -IInclude16 $(name1).asm

