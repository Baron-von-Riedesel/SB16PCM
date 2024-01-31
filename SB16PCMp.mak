
name = SB16PCMp

DEBUG=0

!if $(DEBUG)
LOPTD=/DEBUG:FULL
AOPTD=-Zi -DDEBUG
OUTDIR=DEBUG
!else
LOPTD=/DEBUG:NONE
AOPTD=
OUTDIR=RELEASE
!endif

$(OUTDIR)\$(name).exe: $*.obj
	@jwlink format win pe hx f $* op q,m=$*,stub=\hx\bin\loadpe.bin

$(OUTDIR)\$(name).obj: $(name).asm $(name).mak
	@jwasm -c -nologo -Fl$* -Fo$* -coff -IInclude32 $(name).asm

