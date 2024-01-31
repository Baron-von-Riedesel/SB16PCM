
;--- Play with Cxh/Bxh commands on SoundBlaster 16/16ASP.
;--- Public Domain, written by Andreas Grech.
;--- Inspired by a demo of Andr‚ Baresel.
;--- This is the real-mode variant.

	.286
	.MODEL small
	.dosseg
	.stack 2048
	option casemap:none
	option proc:private
	.386

;--- defaults ( overwritten by BLASTER environment variable )
BASEADDR	EQU 220h	; base address
SBIRQ		EQU 7		; IRQ
DMALOW		EQU 1		; DMA channel
DMAHIGH 	EQU 5		; HDMA channel

USELOWDMAFOR8BIT equ 1	; 0 works for VSB only

lf equ 10

	include dma.inc
	include sbequ.inc

; DMA WRITE MODE
WANTEDMODE  EQU DMA_MODE_SINGLE + DMA_MODE_AUTOINIT + DMA_MODE_READ

CStr macro text:vararg
local sym
	.const
sym db text,0
	.code
	exitm <offset sym>
endm

WaitRead macro
LOCAL loopWait
	push cx
	xor cx, cx
loopWait:
	in al, dx
	test al,80h
	loopzw loopWait		; Jump if bit7=0 - no data available
	pop cx
endm

WaitWrite macro
LOCAL loopWait
	push cx
	xor cx,cx
loopWait:
	in al, dx
	test al, 80h
	loopnzw loopWait	; Jump if bit7=1 - writing not allowed
	pop cx
endm

WriteDSP macro Base, cmd
	mov dx, Base
	add dx, SB_DSPWRITE
	WaitWrite
	mov al, cmd
	out dx, al
endm

RIFFHDR struct
chkId   dd ?
chkSiz  dd ?
format  dd ?
RIFFHDR ends

RIFFCHKHDR struct
subchkId    dd ?
subchkSiz   dd ?
RIFFCHKHDR ends

WAVEFMT struct
        RIFFCHKHDR <>
wFormatTag      dw ?
nChannels       dw ?
nSamplesPerSec  dd ?
nAvgBytesPerSec dd ?
nBlockAlign     dw ?
wBitsPerSample  dw ?
WAVEFMT ends

SAMPLEBUFFERLENGTH equ 6000h

	.DATA

OldIntSB    dd 0
dwSampleBuffer dd 0   ; linear address sample buffer
dwChunks	dd 0
pSampleBuffer dw offset samplebuffer ; near ptr sample buffer
wBase		dw BASEADDR
wIrq		dw SBIRQ
wDmaL		dw DMALOW
wDmaH		dw DMAHIGH
wType		dw 0
bVerbose    db 1
bReady      db 0
bOldMask	db 0
	align word
wDmaBaseChn dw 0
wDmaCntChn  dw 0
wDmaPageChn dw 0
wDmaWriteMask dw 0
wDmaWriteMode dw 0
wDmaClearFlipFlop dw 0

wavefmt WAVEFMT <>

	.data?

samplebuffer db SAMPLEBUFFERLENGTH * 2 dup (?)

	.const

pgtab db 87h, 83h, 81h, 82h, -1, 8bh, 89h, 8ah

	.CODE

dsseg dw 0

	include printf.inc

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; Our IRQ handler for detecting end of playing
; It's generated by the SoundBlaster hardware
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
sbirqproc proc
	push ax
	push dx
	push ds
	mov ds, cs:[dsseg]
	mov [bReady], 1
if 0	; debugging
	push bx
	mov bh,0
	mov ax,0E00h or '.'
	int 10h
	pop bx
endif
	mov dx, [wBase]
if 1
	mov ax, SB_DSPINTACK	; VSB is happy with 22Eh or 22Fh, but real SB needs 22Eh for 8 bit!
	cmp wDmaBaseChn, 10h
	jb @F
endif
	mov ax, SB16_DSPINTACK
@@:
	add dx, ax
	in al, dx
	mov al, 020h
	cmp [wIrq], 8
	jb @F
	out 0A0h, al
@@:
	out 020h, al
	pop ds
	pop dx
	pop ax
	sti
	IRET
sbirqproc endp

GetEnvironmentVariable proc stdcall uses es si di pVar:ptr, pOut:ptr, wSize:word

	mov ah, 51h
	int 21h
	mov es, bx
	mov es, es:[2Ch]
	xor di, di
	mov si, pVar
	mov bx, si
	.while byte ptr [bx]
		inc bx
	.endw
	sub bx, si
nextvar:
	mov cx, bx
	push si
	push di
	repz cmpsb
	jz found
skipvar:
	pop di
	pop si
	mov al, 0
	or cx,-1
	repnz scasb
	cmp byte ptr es:[di],0
	jnz nextvar
	xor ax, ax
	ret
found:
	cmp byte ptr es:[di],'='
	jnz skipvar
	add sp, 2*2
	inc di
	mov si, di
	mov di, pOut
	mov cx, wSize
	mov bx, ds
	push es
	pop ds
	mov es, bx
@@:
	lodsb
	stosb
	cmp al,0
	loopnz @B
	mov ds, bx
	mov ax, di
	sub ax, pOut
	ret
GetEnvironmentVariable endp

;--- si:ptr
;--- al:first digit
;--- cl:base (10/16)
;--- out:number in AX
;--- Z if no valid digit found

getnum proc uses ebx
	mov bx, si
	xor edx, edx
	movzx ecx, cl
nextdigit:
	lodsb
	sub al, '0'
	jb exit
	cmp al, 9
	jbe ok
	cmp cl, 16
	jnz exit
	sub al, 7
	cmp al, 15
	ja exit
ok:
	imul edx, ecx
	movzx eax, al
	add edx, eax
	jmp nextdigit
exit:
	dec si
	mov eax, edx
	cmp si, bx
	ret
getnum endp

;--- scan BLASTER variable

ScanBlasterVar proc stdcall uses si pVar:ptr
	mov si, pVar
	or bx, -1
	.while (byte ptr [si])
		lodsb
		.if (al == ' ')
			or bx,-1
			.continue
		.endif
		.if ((al >= 'a') && (al <= 'z'))
			sub al,20h
		.endif
		.if (bx == -1)
			mov cl,16
			.if (al == 'A')
				mov bx, offset wBase
			.elseif (al == 'I')
				mov bx, offset wIrq
				mov cl,10
			.elseif (al == 'D')
				mov bx, offset wDmaL
			.elseif (al == 'H')
				mov bx, offset wDmaH
			.elseif (al == 'T')
				mov bx, offset wType
			.endif
			.continue
		.endif
		dec si
		call getnum
		jz numdone
		.if (bx != -1)
			mov [bx], ax
		.endif
numdone:
	.endw
	ret
ScanBlasterVar endp

;--- open .wav file
;--- check format
;--- return handle in bx, size in eax

getfileinfo proc stdcall pszFile:ptr

local hFile:word
local currdevice:dword
local riffhdr:RIFFHDR
local datahdr:RIFFCHKHDR

	mov hFile,-1

;--- open the .wav file

	mov si, pszFile
	mov bx,3040h
	mov cx,0
	mov dx,1
	mov di,0
	mov ax,716Ch
	stc
	int 21h
	jnc @F
	.if ax == 7100h
		mov ax,6c00h
		int 21h
	.endif
	.if CARRY?
		invoke printf, CStr("cannot open '%s'",lf), si
		jmp exit
	.endif
@@:
	mov bx, ax
	mov hFile, ax

;--- now load the RIFF headers to get the PCM format and size for the samples block

	lea dx,riffhdr
	mov cx,sizeof riffhdr
	mov ax,3F00h
	int 21h
	.if ax != cx
		invoke printf, CStr("file %s: cannot read riff header",lf), si
		jmp exit
	.endif
	.if (riffhdr.chkId != "FFIR")
		invoke printf, CStr("file %s: no RIFF header found",lf), si
		jmp exit
	.endif
	.if (riffhdr.format != "EVAW")
		invoke printf, CStr("file %s: not a WAVE format",lf), si
		jmp exit
	.endif
	mov dx, offset wavefmt
	mov cx, sizeof wavefmt
	mov ax,3F00h
	int 21h
	.if ax != cx
		invoke printf, CStr("file %s: cannot read wave format",lf), si
		jmp exit
	.endif
	.if (wavefmt.subchkId != " tmf")
		invoke printf, CStr("file %s: no fmt chunk found",lf), si
		jmp exit
	.endif
	.if bVerbose
		invoke printf, CStr("Channels=%u",lf), wavefmt.nChannels
		invoke printf, CStr("Samples/Second=%u",lf), wavefmt.nSamplesPerSec
		invoke printf, CStr("Bits/Sample=%u",lf), wavefmt.wBitsPerSample
	.endif

	lea dx, datahdr
	mov cx, sizeof datahdr
	mov ax, 3F00h
	int 21h
	.if ax != cx
		invoke printf, CStr("file %s: cannot read data header",lf), si
		jmp exit
	.endif
	.if (datahdr.subchkId != "atad")
		invoke printf, CStr("file %s: no data chunk found",lf), si
		jmp exit
	.endif
	.if bVerbose
		invoke printf, CStr("data subchunk size=%lu",lf), datahdr.subchkSiz
	.endif

;--- format must be 8/16 bit, 1/2 channels, 11025/22050/44100 Hz
	mov dx, wavefmt.wBitsPerSample
	mov bx, wavefmt.nChannels
	cmp dx, 16
	jz @F
	cmp dx, 8
	jnz fmterr
@@:
	cmp bx, 1
	jz @F
	cmp bx, 2
	jnz fmterr
@@:
	mov ecx, wavefmt.nSamplesPerSec
	cmp ecx, 44100
	jz @F
	cmp ecx, 22050
	jz @F
	cmp ecx, 11025
	jz @F
fmterr:
	invoke printf, CStr("formats supported: 8/16 bit, 1/2 channels, 11025/22050/44100 Hz",lf)
	jmp exit
@@:
	mov bx, hFile
	mov eax, datahdr.subchkSiz
	clc
	ret
exit:
	mov bx, hFile
	cmp bx, -1
	jz @F
	mov ah, 3Eh
	int 21h
@@:
	stc
	ret
getfileinfo endp

;--- read file
;--- out: NC: read ok, eax=bytes read

fileread proc stdcall hFile:word, pBuffer:ptr, dwSize:dword
	mov dx, pBuffer
	test dwChunks, 1
	jz @F
	add dx, SAMPLEBUFFERLENGTH shr 1
@@:
	xor eax, eax
	mov ecx, dwSize
	jecxz nothingtoread
	cmp ecx, SAMPLEBUFFERLENGTH shr 1
	jb @F
	mov ecx, SAMPLEBUFFERLENGTH shr 1
@@:
	mov bx, hFile
	mov ah, 3Fh
	int 21h
	jc error
if 0
	pushad
	invoke printf, CStr("fileread: read %u bytes",10), ax
	popad
endif
nothingtoread:
	cmp ax, SAMPLEBUFFERLENGTH shr 1
	jz done
	pushad
	mov cx, SAMPLEBUFFERLENGTH shr 1
	sub cx, ax
	mov di, dx
	add di, ax
	mov al,0
	cmp wavefmt.wBitsPerSample, 8
	jnz @F
	mov al,80h
@@:
	rep stosb
	popad
done:
	inc dwChunks
	movzx eax, ax
	ret
error:
	invoke printf, CStr("file read error",10)
	stc
	ret
fileread endp

;--- set DMA registers
;--- WRITEMASK      DMABase + 10 * DMAWidth
;--- WRITEMODE      DMABase + 11 * DMAWidth
;--- CLEARFLIPFLOP  DMABase + 12 * DMAWidth
;--- BASE_CHN       DMABase + DMAWidth * channel
;--- COUNT_CHN      DMABase + DMAWidth * channel + DMAWidth
;--- PAGE_CHN       channel PAGE

setdmaports proc uses ebx

	movzx ebx, wDmaH
if USELOWDMAFOR8BIT
	cmp wavefmt.wBitsPerSample, 16
	jz @F
	mov bx, wDmaL
@@:
endif
	mov edx, 0	; edx=DMABase (0/C0)
	mov ecx, 1	; ecx=DMAWidth (1/2)
	cmp ebx, 4
	jb @F
	mov dx, 0C0h
	inc ecx
@@:
	mov eax, 10
	imul eax, ecx
	add eax, edx
	mov wDmaWriteMask, ax
	mov ax, 11
	imul eax, ecx
	add eax, edx
	mov wDmaWriteMode, ax
	mov ax, 12
	imul eax, ecx
	add eax, edx
	mov wDmaClearFlipFlop, ax
	mov al, [ebx+pgtab]	; al=page register
	mov ah, 0
	mov wDmaPageChn, ax
	mov eax, ebx
	and al, 3
	shl eax, 1
	imul eax, ecx
	add eax, edx
	mov wDmaBaseChn, ax
	add eax, ecx
	mov wDmaCntChn, ax
	ret
setdmaports endp

GetDmaChannel proc
	mov al, byte ptr wDmaH
	sub al, 4
if USELOWDMAFOR8BIT
	cmp wavefmt.wBitsPerSample, 16
	jz @F
	mov al, byte ptr wDmaL
@@:
endif
	ret
GetDmaChannel endp

;--- get linear address and offset of sample buffer.
;--- (must not cross a 64-kB boundary)

getsamplebuffer proc uses esi
	mov ax, ds
	movzx eax,ax
	shl eax, 4
	mov ecx, offset samplebuffer
	add eax, ecx

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; calculate page and offset for DMAcontroller :
;
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

	mov esi, eax
	mov ecx, SAMPLEBUFFERLENGTH
	lea eax, [esi+ecx-1]
	mov edx, esi
	shr eax, 16
	shr edx, 16
	cmp eax, edx				;does a 64kb segment overrun occur?
	jz @F
	shl eax, 16

	mov edx, eax
	sub edx, esi
	add dx, offset samplebuffer
	mov [pSampleBuffer], dx

	mov esi, eax
@@:
	mov eax, esi
	mov [dwSampleBuffer], eax
	clc
	ret
getsamplebuffer endp

;--- return #samples in one half of sample buffer (ecx).
;--- stereo are 2 samples, so just the bits/sample are relevant.
;--- edx must be preserved.

getsamplebufferlength proc
	mov ecx, SAMPLEBUFFERLENGTH shr 1
	cmp wavefmt.wBitsPerSample, 8
	jz @F
	shr ecx, 1
@@:
	ret
getsamplebufferlength endp

dispdmastatus proc
	xor ecx, ecx
	mov dx, [wDmaCntChn]
	in al, dx
	mov cl, al
	in al, dx
	mov ch, al
	xor eax, eax
	mov dx, [wDmaPageChn]
	in al, dx
	shl eax, 16
	mov dx, [wDmaBaseChn]
	in al, dx
	mov ah, al
	in al, dx
	xchg al, ah
	cmp dx, 10h
	jb @F
	shl eax, 1
	shl ecx, 1
@@:
	invoke printf, CStr("DMA ofs=%lX cnt=%lX    ",13), eax, ecx
	ret
dispdmastatus endp

ResetDSP proc
	mov dx, [wBase]
	add dx, SB_DSPRESET
	mov al, 1
	out dx, al			; start DSP reset

	in al, dx
	in al, dx
	in al, dx
	in al, dx			; wait 3 æsec

	xor al, al
	out dx, al			; end DSP Reset

	mov dx, [wBase]
	add dx, SB_DSPSTATUS
	WaitRead
	mov dx, [wBase]
	add dx, SB_DSPREAD
	in al, dx
	cmp al, 0aah		; if there is a SB then it returns 0AAh
	je @F
	stc
	ret
@@:
	clc
	ret
ResetDSP endp

ReadDSPWord proc stdcall bCmd:byte

	WriteDSP [wBase], bCmd
	mov dx, [wBase]
	add dx, SB_DSPSTATUS
	WaitRead
	mov dx, [wBase]
	add dx, SB_DSPREAD
	in al, dx
	mov ah, al
	mov dx, [wBase]
	add dx, SB_DSPSTATUS
	WaitRead
	mov dx, [wBase]
	add dx, SB_DSPREAD
	in al, dx
	ret

ReadDSPWord endp

main proc c argc:word, argv:ptr

local hFile:word
local dwSize:dword
local dwTimer:dword
local szVar[64]:byte

	mov cs:[dsseg], ds
	push ds
	pop es
	mov hFile, -1

	.if argc < 2
		invoke printf, CStr("%s",10), CStr('Play 8/16bit mono/stereo with cmd C6h/B6h (SB16 only).')
		invoke printf, CStr("%s",10), CStr("Usage: playsb16 .WAV-filename")
		invoke printf, CStr("%s",10), CStr('Stop playing with <ESC>.')
		jmp exit2
	.endif

;--- get BLASTER settings

	invoke GetEnvironmentVariable, CStr("BLASTER"), addr szVar, sizeof szVar
	.if (ax)
		invoke ScanBlasterVar, addr szVar
	.endif
	.if bVerbose
		invoke printf, CStr("base=%X, irq=%u, dma=%u, hdma=%u",10), wBase, wIrq, wDmaL, wDmaH
	.endif

;--- get file info

	mov bx, argv
	mov bx, [bx+2]
	invoke getfileinfo, bx
	jc exit2
	mov hFile, bx
	mov dwSize, eax

;--- calc linear address and offset of sample buffer

	call getsamplebuffer
	jc exit2
	.if bVerbose
		invoke printf, CStr("sample buffer linear address=%lX",10), [dwSampleBuffer]
	.endif

;--- fill sample buffer

	mov si, [pSampleBuffer]
	invoke fileread, hFile, si, dwSize	; fill first half of buffer
	jc exit
	sub dwSize, eax
	invoke fileread, hFile, si, dwSize	; fill second half of buffer
	jc exit
	sub dwSize, eax

;--- setup isr

	in al,021h
	mov bOldMask, al

	mov al, byte ptr [wIrq]
	.if ( al < 8 )
		add al, 8
	.else
		add al, 68h
	.endif
	push es
	mov ah, 35h
	int 21h
	mov word ptr [OldIntSB+0], bx
	mov word ptr [OldIntSB+2], es
	pop es
	push ds
	push cs
	pop ds
	mov dx, offset sbirqproc
	mov ah, 25h
	int 21h
	pop ds

;--- enable sound IRQ

	mov dx, 21h
	mov bx, [wIrq]
	cmp bx, 8
	jb @F
	mov dx, 0A1h
	sub bx, 8
@@:
	in al, dx
	btr ax, bx
	out dx, al

;--- init SB and DMA hardware

	call ResetDSP
	.if CARRY?
		invoke printf, CStr('No SoundBlaster found at 0x%x',10), [wBase]
		jmp exit3
	.endif

;--- check if it's a SB16
	invoke ReadDSPWord, DSP_VERSION
	.if ax < 400h
		invoke printf, CStr('No SB16 found, DSP version=%X',10), ax
		jmp exit3
	.endif

	WriteDSP [wBase], DSP_ENABLESPEAKER

;--- Setup DMA-controller
	call setdmaports
	.if bVerbose
		invoke printf, CStr("DMA ports addr/cnt/page=%X/%X/%X",10), wDmaBaseChn, wDmaCntChn, wDmaPageChn
	.endif

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; 1st  MASK DMA CHANNEL
;
	call GetDmaChannel
	or al, DMA_MASK_DISABLE_CHN	; bits 0-1 select channel
	mov dx, wDmaWriteMask
	out dx, al
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; 2nd  CLEAR FLIPFLOP
;
	mov dx, wDmaClearFlipFlop
	out dx, al
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; 3rd  WRITE TRANSFER MODE
;
	call GetDmaChannel
	or al, WANTEDMODE
	mov dx, wDmaWriteMode
	out dx, al
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; 4th  WRITE PAGE NUMBER
;
	mov esi, [dwSampleBuffer]
	mov eax, esi
	shr eax, 16
	cmp wDmaBaseChn, 10h
	jb @F
	shr eax, 1	; 16-bit DMA
@@:
	mov dx, wDmaPageChn
	out dx, al
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; 5th  WRITE BASEADDRESS
;
	mov eax, esi
	mov dx, wDmaBaseChn
	cmp dx, 10h
	jb @F
	shr eax, 1	; 16-bit DMA
@@:
	out dx, al
	mov al, ah
	out dx, al
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; 6th  WRITE SAMPLELENGTH-1
;
	mov dx, wDmaCntChn
	mov ecx, SAMPLEBUFFERLENGTH
	cmp dx, 10h
	jb @F
	shr ecx, 1	; 16-bit DMA
@@:
	dec ecx
	mov al, cl
	out dx, al
	mov al, ch
	out dx, al
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; 7th  DEMASK CHANNEL
;
	call GetDmaChannel
	or al, DMA_MASK_ENABLE_CHN
	mov dx, wDmaWriteMask
	out dx, al

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; Setup SoundBlaster :
;
; 1st  SET SAMPLERATE
;
	WriteDSP [wBase], DSP_SETOUTSAMPLERATE
	mov ecx, wavefmt.nSamplesPerSec
	WaitWrite
	mov al,ch
	out dx,al
	WaitWrite
	mov al,cl
	out dx,al
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; 2nd  play 8/16bit stereo (B6 30)/mono (C6 00) XX XX
;
	WaitWrite
	mov ax, 030B6h				;B6,30 = DMA DAC 16bit autoinit, stereo, signed
	cmp wavefmt.wBitsPerSample, 16
	jz @F
	mov ax, 000C6h				;C6,00 = DMA DAC 8bit autoinit, mono, unsigned
@@:
	out dx, al
	WaitWrite
	mov al, ah					;AL = stereo signed / mono unsigned
	out dx, al
	call getsamplebufferlength
	dec ecx
	WaitWrite
	mov al, cl					; LOWER PART SAMPLELENGTH
	out dx, al
	WaitWrite
	mov al, ch					; HIGHER PART SAMPLELENGTH
	out dx, al

; TRANSFER STARTS NOW

	mov eax, ds:[46ch]
	mov dwTimer, eax
waitloop:
if 1
	.if bVerbose
		push ds
		mov ax, 0
		mov ds, ax
		mov eax, ds:[46ch]
		pop ds
		sub eax, dwTimer
		cmp eax, 5
		jb @F
		add dwTimer, eax
		call dispdmastatus
@@:
	.endif
endif
	mov ah,01					;AH = Check for character function
	int 16h
	jz @F
	mov ah,0
	int 16h
	cmp ah,1
	jz exit
@@:
	cmp [bReady],0				; interrupt occured?
	jz waitloop
	mov [bReady],0
	cmp dwSize, 0
	jz @F
	invoke fileread, hFile, pSampleBuffer, dwSize
	jc exit
	sub dwSize, eax
	jmp waitloop
@@:
if 1
;--- wait till the last half has been played
	invoke fileread, hFile, pSampleBuffer, dwSize
@@:
	cmp [bReady],0
	jz @B
endif

exit:
;	WriteDSP [wBase], DSP_PAUSE8BIT
	call ResetDSP
exit3:
;--- RESTORE PIC MASK
	mov al, bOldMask
	out 21h, al

;--- RESTORE IRQ
	mov dx, word ptr [OldIntSB+0]
	mov cx, word ptr [OldIntSB+2]
	mov ax, cx
	or ax, dx
	jz exit2
	mov al, byte ptr [wIrq]
	.if ( al < 8 )
		add al, 8
	.else
		add al, 68h
	.endif
	push ds
	mov ds, cx
	mov ah, 25h
	int 21h
	pop ds
exit2:
	mov bx, hFile
	cmp bx, -1
	jz @F
	mov ah, 3Eh
	int 21h
@@:
	ret

main endp

	include setargv.inc

start:
	mov ax,@data
	mov ds,ax
	mov cx,ss
	sub cx,ax
	shl cx,4
	mov ss,ax
	add sp,cx
	call _setargv
	invoke main, [_argc], [_argv]
	mov ax,04c00h
	int 21h

	END start
