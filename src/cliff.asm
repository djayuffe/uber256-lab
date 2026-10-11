; CLIFF - the GALAXY engine with the Clifford map: x' = sin(a*y) + c*cos(a*x), y' = sin(b*x) + d*cos(b*y).
; It plays itself too: on every timer tick the orbit's current y position picks a pentatonic note on a marimba.
; The pixel position words live just past the end of the file, inside the program's own segment.
BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
    mov dx,3C9h
.pal:                         ; a glow palette: black -> red -> orange -> white-ish
    mov al,bl
    shr al,2
    out dx,al
    shr al,1
    out dx,al
    shr al,1
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
    fninit
    mov bx,data
    fld1
    fldz
    mov dx,3DAh
frame:
    mov cx,6000
.it:
    fld st1
    fmul dword [bx]           ; a*y
    fsin
    fld st1
    fmul dword [bx]           ; a*x
    fcos
    fmul dword [bx+8]         ; c*cos(a*x)
    faddp st1,st0             ; x' = sin(a*y) + c*cos(a*x)
    fld st1
    fmul dword [bx+4]         ; b*x
    fsin
    fld st3
    fmul dword [bx+4]         ; b*y
    fcos
    fmul dword [bx+12]        ; d*cos(b*y)
    faddp st1,st0             ; y' = sin(b*x) + d*cos(b*y)
    fstp st3                  ; [y', x', x, y] -> [x', y']
    fstp st1
    fld st0
    fimul word [bx+16]        ; * 45
    fistp word [bx+22]
    fld st1
    fimul word [bx+16]
    fistp word [bx+24]
    imul ax,[bx+24],320       ; y*320 + x + (100*320+160): centre the picture
    add ax,[bx+22]
    add ax,32160
    xchg ax,di
    add byte [es:di],12
    loop .it
    fild word [fs:46Ch]       ; morph two parameters (a and d) every frame by s*cos(s*tick): they swing back
    fmul dword [bx+16]        ; and forth over a 9.6-minute cycle instead of drifting off for ever
    fcos
    fmul dword [bx+16]
    mov si,12
.mp:
    fld dword [bx+si]
    fadd st0,st1
    fstp dword [bx+si]
    sub si,12
    jnc .mp
    fstp st0
.vs:
    in al,dx
    test al,8
    jz .vs
.dec:                         ; fade: every pixel loses 1/16 of itself, plus 1, floored at 0
    mov al,[es:di]
    mov ah,al
    shr ah,4
    sub al,ah
    sub al,1
    adc al,0
    stosb
    loop .dec                 ; CX is 0 here: 65536 passes cover the whole segment
    in al,60h
    cbw
    dec ax
    jnz frame                 ; Esc (scan code 1): AX = 0
    mov al,3
    int 10h
    pop ax                    ; unhook: AX = 251Ch, DS:DX = the old vector
    pop dx
    pop ds
    int 21h
    ret
isr:                          ; INT 1Ch, 18.2 times a second (DS is not ours here)
    pusha
    mov dx,330h
    mov ax,3FC0h              ; C0h (program change) to the MPU-401 data port, then 3Fh (UART mode) to its command port
    out dx,ax
    mov al,12                 ; program 12: marimba
    out dx,al
    mov al,90h                ; note on
    out dx,al
    mov al,[cs:bx+24]         ; a note on every tick: the orbit's y position (BX = data in the main loop)
    and al,14
    add al,50
    aam 5                     ; AL = 2d -> 2d + floor(2d/5) = floor(12d/5): a major-pentatonic degree d
    aad 6
    out dx,al                 ; note (C4..E5)
    out dx,al                 ; velocity = note
.r:
    popa
    iret
data:
    dd -1.4, 1.6, 1.0, 0.7                  ; a, b, c, d
    dw 45                                   ; +16: the scale, and the low half of s = 0x39D1002D = 0.000399
    dw 39D1h                                ; the pixel position words live just past the end, at +22 and +24
