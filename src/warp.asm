; WARP - the DOS screen, untouched in memory, squashed, stretched and sheared by two CRT-controller registers:
; CR09 (character height) follows a fast triangle wave and CR13 (words per text row) a slow one. On top of
; that the attribute controller's pixel panning makes it shimmer sideways, and the 64 DAC colours that text
; mode uses run through a rainbow, so the text glows and every colour of the screen flows (black stays black).
; The music follows the same waves: an electric piano plays the character height as a pentatonic arpeggio that
; climbs as the text stretches; under it a GM drum kit keeps time and a bass walks C - A - G - E.
BITS 16
CPU 386
ORG 100h
    mov ax,351Ch              ; hook the timer tick (INT 1Ch), keeping the old vector on the stack
    int 21h
    push es
    push bx
    mov ah,25h
    mov dx,isr
    int 21h
    push ax                   ; AX = 251Ch, for the unhook
frame:
    mov dx,3D4h
    inc bx                    ; time
    mov al,bl                 ; triangle wave from the counter
    test al,32
    jz .up
    not al
.up:
    and al,31
    shr al,1                  ; 0..15
    add al,3                  ; character height 4..19 scan lines (16 is normal)
    or al,40h                 ; keep CR09 bit 6 (line compare bit 9)
    mov ah,al
    mov al,09h                ; CR09: maximum scan line = character height - 1
    out dx,ax
    mov al,bl                 ; a slower triangle, -4..+3, for the line stride
    shr al,3
    test al,8
    jz .up2
    not al
.up2:
    and al,7
    add al,40-4               ; CR13: 36..43 words per row (40 = the normal 80 columns)
    mov ah,al
    mov al,13h
    out dx,ax
    mov al,bl                 ; CR08, preset row scan: the whole screen bobs 0..15 scan lines, twice as fast
    add al,al
    test al,32
    jz .up4
    not al
.up4:
    and al,31
    shr al,1
    mov ah,al
    mov al,08h
    out dx,ax
    mov dl,0DAh
.vs:
    in al,dx
    test al,8
    jz .vs
.vs2:
    in al,dx                  ; (each read also resets the attribute controller's flip-flop)
    test al,8
    jnz .vs2
    mov dl,0C0h               ; attribute controller: pixel panning (13h, with bit 5 kept: display on)
    mov al,33h
    out dx,al
    mov al,bl                 ; a 0..7 triangle, eight times faster: the text shimmers sideways
    shl al,2
    test al,32
    jz .up3
    not al
.up3:
    shr al,2
    and al,7
    out dx,al
    mov dl,0C8h               ; the DAC, from colour 1 (0, the background, stays black)
    mov al,1
    out dx,al
    inc dx
    mov cx,63*3
.pal:                         ; a rainbow that flows: each component is a triangle of (time + 86 * byte position)
    mov al,cl
    imul ax,ax,86             ; 86 per byte: a third of a cycle between R, G and B, 2 per colour
    add al,bl
    add al,al
    jnc .p
    not al
.p:
    shr al,2
    out dx,al
    loop .pal
    in al,60h
    cbw
    dec ax
    jnz frame                 ; Esc (scan code 1): AX = 0
    mov al,3
    int 10h                   ; text mode (and the default palette and panning)
    pop ax                    ; unhook INT 1Ch: AX = 251Ch, DS:DX = the old vector
    pop dx
    pop ds
    int 21h
    ret
isr:                          ; INT 1Ch, 18.2 Hz; BX is the main loop's frame counter
    pusha
    mov dx,330h
    mov ax,3FC0h              ; C0h to the MPU data port, then 3Fh (UART mode) to its command port
    out dx,ax
    mov al,4                  ; program 4: electric piano
    out dx,al
    mov al,90h                ; note on, channel 1
    out dx,al
    mov al,bl                 ; the same triangle wave as the character height
    test al,32
    jz .up
    not al
.up:
    and al,30
    add al,46
    aam 5                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    aad 6
    out dx,al                 ; note
    out dx,al                 ; velocity = note
%include "groove.inc"
    popa
    iret
