; ORDER - geometry from orderings, not distances. Three cheap per-pixel expressions
;   a = (x*y)/64 + t   (hyperbolas)     b = x - 2t   (vertical lines)     c = 3y + t   (horizontal lines)
; are never drawn. Only their ORDER is: three comparisons give one of the six orderings (as 3 bits, via the
; carry flag), which picks a band of the palette, and a shades it. As t moves, regions fold, collide and swap.
; All three are kept incrementally (x*y grows by y per pixel, b by 1, c by 3 per row): no division, no multiply.
; The music is read off the picture: a probe walks down the screen and the ordering under it is the root of a
; four-note pizzicato arpeggio, so the harmony moves each time the probe crosses a boundary; a drum kit and a
; walking bass (groove.inc) play under it, and the palette flows with time.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
    mov al,13h
    int 10h
    HOOK_TICK isr                 ; the timer tick drives the music
    push word 0A000h
    pop es
frame:
    xor di,di
    xor dx,dx                 ; y
.row:
    xor si,si                 ; x*y
    imul bx,bp,-2             ; BL = b = x - 2t at x = 0
    imul ax,dx,3
    add ax,bp
    mov bh,al                 ; BH = c = 3y + t
    mov cx,320
.px:
    mov ax,si
    shr ax,6
    add ax,bp                 ; AL = a = (x*y)/64 + t
    cmp al,bl                 ; which of the six orderings of (a, b, c)? three comparisons -> 3 bits in AH
    rcl ah,1
    cmp bl,bh
    rcl ah,1
    cmp al,bh
    rcl ah,1
    shl ah,5                  ; the ordering picks a band of the palette...
    shr al,3
    add al,ah                 ; ...and a shades it
    stosb
    add si,dx
    inc bl
    loop .px
    inc dx
    cmp dl,200
    jb .row
    inc bp
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    mov dl,0C8h               ; the palette flows inside each band: entry k = (k AND E0h) + ((k + 2t) AND 1Fh),
    mov al,0                  ; streamed as i, 2i, 4i, so every region keeps its hue while its shading streams
    out dx,al
    inc dx
    mov cx,256
.flow:
    mov ax,bp
    add ax,ax
    add ax,cx
    and al,1Fh
    mov ah,cl
    and ah,0E0h
    or al,ah
    out dx,al
    add al,al
    out dx,al
    add al,al
    out dx,al
    loop .flow
    ESC_OR_LOOP frame
isr:                          ; INT 1Ch, 18.2 Hz
    pusha
    MIDI_START 45             ; program 45: pizzicato strings
    mov ax,[fs:46Ch]          ; BIOS tick count
    shr ax,1
    jc .q                     ; a note every other tick
    imul bx,ax,321            ; the probe walks down a diagonal: one row and one pixel per step
    and al,3
    add al,al                 ; a four-note arpeggio (degrees +0 +2 +4 +6)...
    mov ah,[es:bx]
    shr ah,5
    add al,ah                 ; ...on the degree given by the ordering under the probe
    add al,al
    add al,48
    PENTA                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    out dx,al                 ; note
    out dx,al                 ; velocity = note
.q:
%include "groove.inc"
    popa
    iret
