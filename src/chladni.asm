; CHLADNI - the nodal lines of a vibrating plate: f(x,y) = sin(a*x)*sin(b*y) - sin(b*x)*sin(a*y) = 0.
; Sand collects where the plate does not move, so the picture is bright where |f| is small. The mode number a
; swings through [2, 4] with the BIOS clock. f is separable, so each frame first tabulates sin(aX) and sin(bX)
; for the 320 values of X (the 200 values of Y are a subset): 640 FSINs a frame instead of four per pixel.
; A probe crosses the plate in time with the music: where it meets a nodal line, a tubular bell rings.
BITS 16
CPU 386
ORG 100h
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
    fstp dword [si]           ; sin(aX)
    fld st0
    fimul word [bx+14]
    fsin
    fstp dword [si+4]         ; sin(bX), b = 6
    fadd dword [bx+8]         ; X += 0.02
    add si,8
    cmp si,TAB+2560
    jb .tb
    fcompp
    xor di,di
    mov bp,TAB+60*8           ; row y uses entry y+60: Y = (y-100)*0.02
.row:
    mov si,TAB
    mov cx,320
.px:
    fld dword [si]
    fmul dword [bp+4]         ; sin(aX) sin(bY)
    fld dword [si+4]
    fmul dword [bp]           ; sin(bX) sin(aY)
    fsubp st1,st0
    fabs
    fimul word [bx+16]        ; |f| * 600
    fistp word [bx+18]
    mov ax,[bx+18]
    test ah,ah                ; above 255: clamp
    jz .ok
    mov al,255
.ok:
    not al                    ; bright where the plate is still
    stosb
    add si,8
    loop .px
    add bp,8
    cmp di,64000
    jb .row
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    in al,60h
    cbw
    dec ax
    jnz frame                 ; Esc (scan code 1): AX = 0
    mov al,3
    int 10h
    pop ax                    ; unhook INT 1Ch: AX = 251Ch, DS:DX = the old vector
    pop dx
    pop ds
    int 21h
    ret
isr:                          ; INT 1Ch, 18.2 Hz
    pusha
    mov dx,330h
    mov ax,3FC0h              ; C0h (program change) to the MPU-401 data port, then 3Fh (UART mode) to its command port
    out dx,ax
    mov al,14                 ; program 14: tubular bells
    out dx,al
    mov al,90h                ; note on
    out dx,al
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
    aam 5                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    aad 6
    out dx,al                 ; note
    out dx,al                 ; velocity = note
.r:
    popa
    iret
data:
    dd 0.0115, -3.2, 0.02     ; w (radians per tick), X at the left edge, X per pixel
    dw 3, 6, 600              ; a = 3 + sin(w t); b; brightness scale. |f|*600 is stored just past the end
