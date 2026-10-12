; GALAXY - a de Jong strange attractor drawn as a glowing, fading, slowly morphing cloud; it plays itself:
; every other timer tick the orbit's current x position picks a note of a pentatonic scale on a vibraphone.
; The pixel position words live just past the end of the file, inside the program's own segment.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
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
    HOOK_TICK isr                 ; the timer tick drives the music
    push word 0A000h
    pop es
    fninit
    mov bx,data
    fld1
    fld1
    mov dx,3DAh
frame:
    mov cx,6000
.it:
    fld st1
    fmul dword [bx]
    fsin
    fld st1
    fmul dword [bx+4]
    fcos
    fsubp st1,st0
    fld st1
    fmul dword [bx+8]
    fsin
    fld st3
    fmul dword [bx+12]
    fcos
    fsubp st1,st0
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
    aam 16                    ; AH = v/16, AL = v mod 16
    aad 15                    ; AL = 15 AH + AL = v - v/16
    sub al,1
    adc al,0
    stosb
    loop .dec                 ; CX is 0 here: 65536 passes cover the whole segment
    ESC_OR_LOOP frame
isr:                          ; INT 1Ch, 18.2 times a second (DS is not ours here)
    pusha
    MIDI_START 11             ; program 11: vibraphone
    mov al,[fs:46Ch]          ; the BIOS tick count (FS = 0 at start-up)
    shr al,1
    jc .r                     ; a note every other tick
    mov al,[cs:bx+22]         ; the orbit's x position (BX = data in the main loop)
    and al,14
    add al,50
    PENTA                     ; AL = 2d -> 2d + floor(2d/5) = floor(12d/5): a major-pentatonic degree d
    out dx,al                 ; note (C4..E5)
    out dx,al                 ; velocity = note
.r:
    popa
    iret
data:
    dd 1.4, -2.3, 2.4, -2.1                 ; a, b, c, d
    dw 45                                   ; +16: the scale, and the low half of s = 0x3A1D002D = 0.000599
    dw 3A1Dh                                ; the pixel position words live just past the end, at +22 and +24
