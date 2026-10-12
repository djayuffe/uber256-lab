; CHLADNI - the nodal lines of a vibrating plate: f(x,y) = sin(a*x)*sin(b*y) - sin(b*x)*sin(a*y) = 0.
; Sand collects where the plate does not move, so the picture is bright where |f| is small. The mode number a
; swings through [2, 4] once every 30 s (a phase kept on the FPU stack, advanced every frame). f is separable,
; and |f| is symmetric about X = 0, so each frame tabulates sin(aX) and sin(bX) for just 260 values of X: the
; left half of the screen and, shifted by 60, all 200 values of Y. They are 16-bit integers scaled by K = 6271
; (520 FSINs a frame), and each pixel is two integer multiplies whose high words are already |f| * 600, drawn
; twice, at x and at 319-x: half the multiplies, and a full 70 frames a second.
; A probe crosses the plate in time with the music: where it meets a nodal line, a tubular bell rings, doubled
; an octave below.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
TAB equ 8000h-1040            ; 260 entries, ending at 8000h, of (sin(aX), sin(bX)), X = (k-159.5)*0.02: rows use the same table
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
    fldz                      ; theta = w * frame, kept at the bottom of the FPU stack
frame:
    mov bx,data
    fld st0                   ; a = 3 + sin(theta): the mode number swings through [2, 4] every 30 s
    fsin
    fiadd word [bx+12]
    mov si,TAB
    fld dword [bx+4]          ; X = -3.19
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
    jns .tb                   ; (the table ends where SI reaches 8000h)
    fcompp
    fadd dword [bx]           ; theta += w
    xor di,di
    mov bp,TAB+60*4           ; row y uses entry y+60: Y = (y-99.5)*0.02
.row:
    mov si,TAB
    lea bx,[di+319]           ; |f| is symmetric about X = 0: each value is drawn at x and at 319-x
.px:
    lodsw
    imul word [bp+2]          ; K^2 sin(aX) sin(bY) in DX:AX
    mov cx,dx
    lodsw
    imul word [bp]            ; K^2 sin(bX) sin(aY)
    xchg ax,cx
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
    mov [es:bx],al
    dec bx
    cmp di,bx
    jb .px
    add di,160
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
    dd 0.0029874, -3.19, 0.02 ; w (radians per frame: 0.0115 per BIOS tick at 70 Hz), X at the left edge, X per pixel
    dw 3, 6, 6271             ; a = 3 + sin(theta); b; K = sqrt(600 * 65536), the table scale
