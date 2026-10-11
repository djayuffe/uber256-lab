; SELFTEX - each pixel is a byte of the program's own machine code, picked by x*y/64 + time; and the music is
; the same bytes read in order: every other timer tick the next code byte is a kalimba note. The score is the program.
BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
    mov dx,3C9h
.pal:
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
    mov cx,320
    mov bx,100h               ; XLAT table = the program itself
    xor bp,bp                 ; time
.x:
    mov ax,di
    xor dx,dx
    div cx                    ; ax = y, dx = x
    imul ax,dx                ; x*y
    shr ax,6
    add ax,bp                 ; + time
    xlat                      ; AL = [100h + AL]: the program's own bytes are the texture
    stosb
    test di,di
    jnz .x
    inc bp
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    in al,60h
    cbw
    dec ax
    jnz .x                 ; Esc (scan code 1): AX = 0
    mov al,3
    int 10h                   ; text mode
    pop ax                    ; unhook INT 1Ch: AX = 251Ch, DS:DX = the old vector
    pop dx
    pop ds
    int 21h
    ret
isr:                          ; INT 1Ch, 18.2 Hz; BX = 100h in the main loop
    pusha
    mov dx,330h
    mov ax,3FC0h              ; C0h to the MPU data port, then 3Fh (UART mode) to its command port
    out dx,ax
    mov al,108                ; program 108: kalimba
    out dx,al
    mov al,90h                ; note on
    out dx,al
    mov ax,[fs:46Ch]
    shr ax,1
    jc .q
    and al,127                ; step through the first 128 bytes of the program, over and over
    cs xlat                   ; the code byte
    and al,30
    add al,46
    aam 5                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    aad 6
    out dx,al                 ; note
    out dx,al                 ; velocity = note
.q:
    popa
    iret
