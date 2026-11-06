; MOIRE - two ring families, one orbiting the other, XORed into a swirling moire.
; Imported from uber256-dos-intro and adapted to the lab's shared exit/MIDI ABI.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"

    mov al,13h
    int 10h
    push word 0A000h
    pop es
    mov dx,3C9h
.pal:
    mov al,bl
    out dx,al                     ; R = i
    add al,al
    out dx,al                     ; G = 2i
    add al,al
    out dx,al                     ; B = 4i
    inc bl
    jnz .pal
    HOOK_TICK isr
    mov cx,320

frame:
    mov al,[t]                    ; orbiting centre: two quarter-shifted triangle waves
    cbw
    xor al,ah
    add al,64
    xor ah,ah
    mov si,ax
    mov al,[t]
    add al,64
    cbw
    xor al,ah
    add al,36
    xor ah,ah
    mov bp,ax
.x:
    mov ax,di
    xor dx,dx
    div cx                        ; AX = y, DX = x
    push ax
    push dx
    sub dx,160
    imul dx,dx
    sub al,100
    imul al
    add ax,dx
    shr ax,7                      ; screen-centred ring family
    pop dx
    pop bx
    push ax
    sub dx,si
    imul dx,dx
    sub bx,bp
    imul bx,bx
    add bx,dx
    shr bx,7                      ; orbiting ring family
    pop ax
    xor ax,bx
    add al,[t]
    stosb
    test di,di
    jnz .x                        ; DI wrapped: the 64 KB pass is complete
    inc byte [t]
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    ESC_OR_LOOP frame

isr:                              ; the orbit drives a bright crystal arpeggio
    pusha
    MIDI_START 98
    mov ax,[fs:46Ch]
    test al,1
    jnz .q
    and al,14
    add al,48
    PENTA
    out dx,al
    out dx,al
.q:
    popa
    iret
t:                                ; frame counter in zero-filled memory after the file
