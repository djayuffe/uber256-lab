; JULIA - a Julia set in 8.8 fixed point whose constant c circles slowly (a Minsky oscillator: x += y>>5, y -= x>>5).
; No FPU, no sine table. Colour = how fast the point escapes, through a wrapping RGB palette. A Julia set is
; symmetric under z -> -z, so only the top half is computed and each pixel is also written to its mirror.
; The music is read off the picture as it is drawn: on every timer tick the escape time of the pixel just
; computed is a celesta note, and the inside of the set is silence; a low C pedal sounds every 16 ticks, and
; the tick handler also rotates the palette, so the bands flow even between the (slow) frames.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
    mov al,13h
    int 10h
    HOOK_TICK isr                 ; the timer tick drives the music
    push word 0A000h
    pop es
    mov bp,-180               ; cr: the real part of c (ci stays in memory)
frame:
    xor di,di
.px:
    mov ax,di
    xor dx,dx
    mov bx,320
    div bx                    ; ax = y, dx = x
    shl dx,1
    sub dx,319
    mov bx,dx                 ; bx = x  (8.8, +-1.25), centred between pixels 159 and 160
    shl ax,1
    sub ax,199
    mov si,ax                 ; si = y, centred between rows 99 and 100: (x, y) -> (-x, -y) is pixel i -> 63999 - i
    mov cx,31
.it:
    mov ax,bx
    imul bx
    shrd ax,dx,8
    push ax                   ; x*x
    mov ax,si
    imul si
    shrd ax,dx,8
    push ax                   ; y*y
    mov ax,bx
    imul si
    shrd ax,dx,7              ; 2*x*y
    add ax,[ci]
    mov si,ax                 ; y' = 2xy + cy
    pop ax                    ; y*y
    pop bx                    ; x*x
    mov dx,bx
    add dx,ax
    cmp dx,1024               ; |z|^2 > 4: escaped
    ja .out
    sub bx,ax
    add bx,bp                 ; x' = x*x - y*y + cx
    loop .it
.out:
    mov al,cl
    shl al,3
    stosb
    mov bx,64000              ; and the mirror pixel, 63999 - i
    sub bx,di
    mov [es:bx],al
    cmp di,32000              ; the top half only
    jb .px
    mov ax,[ci]               ; move c round a circle
    sar ax,5
    add bp,ax
    mov ax,bp
    sar ax,5
    sub [ci],ax
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    ESC_OR_LOOP frame
isr:                          ; INT 1Ch, 18.2 Hz: the pixel just drawn plays (DI is the main loop's pointer)
    pusha
    MIDI_START 8              ; program 8: celesta
    mov al,[es:di-1]          ; escape time * 8
    shr al,2
    jz .q                     ; inside the set: a rest
    and al,30
    add al,44
    PENTA                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    out dx,al                 ; note
    out dx,al                 ; velocity = note
.q:
    test byte [fs:46Ch],15    ; every 16 ticks a low C on channel 2 (piano): a pedal under the celesta
    jnz .np
    mov al,91h
    out dx,al
    mov al,36
    out dx,al
    mov al,90
    out dx,al
.np:
    mov dx,3C8h               ; and on every tick the palette moves on (a ramp shifted by 2t, streamed as R = i,
    mov al,1                  ; G = 2i, B = 4i), so the escape bands flow smoothly however slowly the picture
    out dx,al                 ; is drawn; colour 0, the set itself, stays black
    inc dx
    mov bx,[fs:46Ch]
    add bx,bx
    mov cx,255
.flow:
    mov ax,cx
    add ax,bx
    out dx,al
    add al,al
    out dx,al
    add al,al
    out dx,al
    loop .flow
    popa
    iret
ci: dw 0
