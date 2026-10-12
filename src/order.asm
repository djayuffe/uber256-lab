; ORDER - geometry from orderings, not distances. Three cheap per-pixel expressions
;   a = (x*y)/64 + t   (hyperbolas)     b = x - 2t   (vertical lines)     c = 3y + t   (horizontal lines)
; are never drawn. Only their ORDER is: three comparisons give one of the six orderings (as 3 bits, via the
; carry flag), which picks a band of the palette, and a shades it. As t moves, regions fold, collide and swap.
; All three are kept incrementally (4xy grows by 4y per pixel, b by 1, c is set per row): no division or multiply
; per pixel, eleven instructions each, 70 frames a second.
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
    xor si,si                 ; 4y
.row:
    imul dx,bp,256            ; DX = 256t + 4xy: DH is a = (x*y)/64 + t, with no add or shift per pixel
    imul bx,bp,-2             ; BL = b = x - 2t at x = 0
    imul ax,si,3
    shr ax,2
    add ax,bp
    mov bh,al                 ; BH = c = 3y + t
    mov cx,320
.px:
    mov al,dh                 ; AL = a
    cmp dh,bh                 ; which of the six orderings of (a, b, c)? Each comparison's carry is rotated
    rcr al,1                  ; in at the top of AL: after three, AL = (a<b, b<c, a<c, a >> 3): the ordering
    cmp bl,bh                 ; picks a band of the palette and a shades it
    rcr al,1
    cmp dh,bl
    rcr al,1
    stosb
    add dx,si
    inc bl
    loop .px
    add si,4
    cmp si,800
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
