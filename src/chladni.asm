; CHLADNI - the nodal lines of a vibrating plate: f(x,y) = sin(a*x)*sin(b*y) - sin(b*x)*sin(a*y) = 0.
; Sand collects where the plate does not move, so the picture is bright where |f| is small. The mode number a
; swings through [2, 4] with the BIOS clock. f is separable, so each frame first tabulates sin(aX) and sin(bX)
; for the 320 values of X (the 200 values of Y are a subset), as 16-bit integers scaled by K = 6271: 640 FSINs a
; frame, and each pixel is two integer multiplies whose high words are already |f| * 600.
; A probe crosses the plate in time with the music: where it meets a nodal line, a tubular bell rings, doubled
; an octave below.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
TAB equ 8000h                 ; 320 entries of (sin(aX), sin(bX)), X = (k-160)*0.02: rows use the same table
    mov al,13h
    int 10h
    mov dx,3C9h
.pal:                         ; glow palette
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
frame:
    fild word [fs:46Ch]       ; a = 3 + sin(w * tick): the mode number swings through [2, 4] every 30 s
    fmul dword [bx]
    fsin
    fiadd word [bx+12]
    mov si,TAB
    fld dword [bx+4]          ; X = -3.2
.tb:
    fld st0
    fmul st0,st2
    fsin
    fimul word [bx+16]
    fistp word [si]           ; K sin(aX), K = 6271
    fld st0
    fimul word [bx+14]
    fsin
    fimul word [bx+16]
    fistp word [si+2]         ; K sin(bX), b = 6
    fadd dword [bx+8]         ; X += 0.02
    add si,4
    cmp si,TAB+1280
    jb .tb
    fcompp
    xor di,di
    mov bp,TAB+60*4           ; row y uses entry y+60: Y = (y-100)*0.02
.row:
    mov si,TAB
    mov cx,320
.px:
    mov ax,[si]
    imul word [bp+2]          ; K^2 sin(aX) sin(bY) in DX:AX
    push dx
    mov ax,[si+2]
    imul word [bp]            ; K^2 sin(bX) sin(aY)
    pop ax
    sub ax,dx                 ; the high words: K^2 f / 65536 = 600 f, since K^2 = 600 * 65536
    jns .abs
    neg ax                    ; |f| * 600
.abs:
    test ah,ah                ; above 255: clamp
    jz .ok
    mov al,255
.ok:
    not al                    ; bright where the plate is still
    stosb
    add si,4
    loop .px
    add bp,4
    cmp di,64000
    jb .row
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    ESC_OR_LOOP frame
isr:                          ; INT 1Ch, 18.2 Hz
    pusha
    MIDI_START 14             ; program 14: tubular bells
    mov ax,[fs:46Ch]          ; BIOS tick count
    shr ax,1
    jc .r
    imul bx,ax,323            ; a probe crossing the plate, one row and three pixels per step
    mov al,[es:bx]
    test al,al
    jns .r                    ; it rings only where it crosses a nodal line (the bright half of the palette)
    shr al,2
    and al,30
    add al,40
    PENTA                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    out dx,al                 ; note
    out dx,al                 ; velocity = note
    sub al,12                 ; and the same bell an octave lower
    out dx,al
    out dx,al
.r:
    popa
    iret
data:
    dd 0.0115, -3.2, 0.02     ; w (radians per tick), X at the left edge, X per pixel
    dw 3, 6, 6271             ; a = 3 + sin(w t); b; K = sqrt(600 * 65536), the table scale
