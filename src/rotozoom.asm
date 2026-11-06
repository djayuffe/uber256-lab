; ROTOZOOM - XOR texture rotating about the screen centre without multiplies or a sine table.
; Imported from uber256-rotozoomer and adapted to the lab's shared exit/MIDI ABI.
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
    out dx,al
    add al,al
    out dx,al
    add al,al
    out dx,al
    inc bl
    jnz .pal
    HOOK_TICK isr
    mov bx,data

frame:
    mov si,bx                     ; Minsky step for (c,s), then for (u0,v0)
    mov cx,2
.m:
    mov eax,[si+4]
    sar eax,5
    sub [si],eax
    mov eax,[si]
    sar eax,5
    add [si+4],eax
    add si,8
    loop .m
    mov eax,[bx+8]
    mov [bx+16],eax
    mov eax,[bx+12]
    mov [bx+20],eax
    xor di,di
    mov dx,200
.y:
    mov ebp,[bx+16]
    mov esi,[bx+20]
    mov cx,320
.x:
    add ebp,[bx]                  ; u += c
    add esi,[bx+4]                ; v += s
    mov eax,ebp
    xor eax,esi
    shr eax,24
    add al,[bx+24]
    stosb
    loop .x
    mov eax,[bx+4]
    sub [bx+16],eax               ; next row: u -= s
    mov eax,[bx]
    add [bx+20],eax               ; next row: v += c
    dec dx
    jnz .y
    inc byte [bx+24]
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    ESC_OR_LOOP frame

isr:                              ; the rotating colour phase drives a saw lead
    pusha
    MIDI_START 81
    mov ax,[fs:46Ch]
    test al,1
    jnz .q
    and al,14
    add al,50
    PENTA
    out dx,al
    out dx,al
.q:
    popa
    iret

data:                             ; 16.16 fixed point; |(c,s)| = 56 texture units/pixel
    dd 56 << 16, 0
    dd -160 * 56 << 16            ; u0 = -160c
    dd -100 * 56 << 16            ; v0 = -100c
