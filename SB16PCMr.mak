
name = SB16PCMr

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

$(OUTDIR)\$(name).exe: $(name).asm
	@jwasm -mz -nologo -Fl$* -Fo$* -IInclude16 $(name).asm

