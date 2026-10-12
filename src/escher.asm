; ESCHER - the picture is drawn once. After that only the CRTC moves: the display start address drifts,
; and the line-compare register restarts the scan-out from address 0 part-way down the screen, so the top
; slides while the bottom is a second copy of the same texture. Nothing is redrawn: pixel panning makes the
; drift pixel-smooth and the palette streams colour through the bands.
; The music is a Shepard scale: five octave-spaced notes step up a semitone at a time under a fixed bell of
; loudness, so the scale climbs for ever without getting higher - Escher's staircase, heard.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
    mov al,13h
    int 10h
    HOOK_TICK isr                 ; the timer tick drives the music
    push word 0A000h
    pop es
    xor di,di
.tex:                         ; texture: (x-160)*(y-100) / 64 - hyperbolic bands, drawn once
    mov ax,di
    xor dx,dx
    mov cx,320
    div cx                    ; ax = y, dx = x
    sub dx,160
    sub ax,100
    imul ax,dx
    sar ax,6
    stosb
    cmp di,64000
    jb .tex
    mov dx,3D4h               ; line compare bits 8 and 9 (CR07 bit 4, CR09 bit 6) are set in mode 13h,
    mov ax,0F07h              ; which puts the split below the screen on a real VGA: clear them
    out dx,ax                 ; (CR07 bit 4 is writable even with the CRTC write-protect on)
    mov ax,0109h
    out dx,ax
    mov bx,3000               ; a Minsky oscillator (bx, bp) drives the display start address
    xor bp,bp
    xor si,si                 ; line compare
frame:
    mov dx,3DAh
.v0:
    in al,dx                  ; wait for the end of a retrace, then the start of the next: one step per frame
    test al,8
    jnz .v0
.vs:
    in al,dx
    test al,8
    jz .vs
    mov ax,bp
    sar ax,6
    imul ax,ax,80             ; vertical: whole rows
    mov cx,bx
    sar cx,5
    add ax,cx                 ; horizontal: units of 4 pixels
    and ax,3FFFh
    mov dl,0D4h
    mov cl,al                 ; start address: AH already holds the high byte
    mov al,0Ch
    out dx,ax
    mov ah,cl
    inc ax                    ; 0Dh: the low byte
    out dx,ax
    mov ax,si                 ; line compare (CR18): a split that sweeps down the screen
    mov ah,al
    mov al,18h
    out dx,ax
    mov dl,0C0h               ; attribute controller 13h, pixel panning: the start address moves in steps of
    mov al,33h                ; 4 pixels; panning by 0, 1, 2 or 3 more (written as 0, 2, 4, 6 in 256-colour
    out dx,al                 ; mode) makes the horizontal drift pixel-smooth (the retrace wait's reads of
    mov al,bl                 ; 3DAh reset the flip-flop)
    shr al,2
    and al,6
    out dx,al
    mov dl,0C8h               ; and the palette flows: entry k = (k + frame) streamed as i, 2i, 4i, so the
    mov al,0                  ; bands stream through the texture although no pixel is ever redrawn
    out dx,al
    inc dx
    mov cx,256
.flow:
    mov ax,cx
    add ax,si
    out dx,al
    add al,al
    out dx,al
    add al,al
    out dx,al
    loop .flow
    mov ax,bp                 ; the oscillator: bx += bp>>5, bp -= bx>>5
    sar ax,5
    add bx,ax
    mov ax,bx
    sar ax,5
    sub bp,ax
    inc si
    ESC_OR_LOOP frame
isr:                          ; INT 1Ch, 18.2 Hz
    pusha
    MIDI_START 11             ; program 11: vibraphone
    mov al,[fs:46Ch]          ; BIOS tick count
    test al,3
    jnz .r                    ; a step every 4 ticks
    shr al,2
    aam 12                    ; AL = the step's pitch class
    add al,24
    mov cx,5
.oct:                         ; five octaves: 24+p .. 72+p
    out dx,al                 ; note
    push ax
    sub al,54                 ; loudness: a bell centred on the middle of the five octaves, 127 - 3|n - 54|
    jns .a
    neg al
.a:
    mov ah,al
    add al,al
    add al,ah
    xor al,7Fh
    out dx,al                 ; velocity
    pop ax
    add al,12
    loop .oct
.r:
    popa
    iret
