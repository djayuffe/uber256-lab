; ESCHER - the picture is drawn once. After that only the CRTC moves: the display start address drifts,
; and the line-compare register restarts the scan-out from address 0 part-way down the screen, so the top
; slides while the bottom is a second copy of the same texture. Nothing is redrawn.
; The music is a Shepard scale: five octave-spaced notes step up a semitone at a time under a fixed bell of
; loudness, so the scale climbs for ever without getting higher - Escher's staircase, heard.
BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
    mov dx,3C9h
.pal:                         ; R = i, G = 2i, B = 4i
    mov al,bl
    out dx,al
    add al,al
    out dx,al
    add al,al
    out dx,al
    inc bl
    jnz .pal
    mov ax,351Ch              ; hook the timer tick (INT 1Ch), keeping the old vector on the stack
    int 21h
    push es
    push bx
    mov ah,25h
    mov dx,isr
    int 21h
    push ax                   ; AX = 251Ch, for the unhook
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
    mov ax,bp                 ; the oscillator: bx += bp>>5, bp -= bx>>5
    sar ax,5
    add bx,ax
    mov ax,bx
    sar ax,5
    sub bp,ax
    inc si
    in al,60h
    cbw
    dec ax
    jnz frame                 ; Esc (scan code 1): AX = 0
    mov al,3
    int 10h                   ; text mode
    pop ax                    ; unhook INT 1Ch: AX = 251Ch, DS:DX = the old vector
    pop dx
    pop ds
    int 21h
    ret
isr:                          ; INT 1Ch, 18.2 Hz
    pusha
    mov dx,330h
    mov ax,3FC0h              ; C0h to the MPU data port, 3Fh (UART mode) to its command port
    out dx,ax
    mov al,11                 ; program 11: vibraphone
    out dx,al
    mov al,90h
    out dx,al
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
