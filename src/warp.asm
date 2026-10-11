; WARP - the DOS screen, untouched in memory, squashed, stretched and sheared by two CRT-controller registers:
; CR09 (character height) follows a fast triangle wave and CR13 (words per text row) a slow one.
; The music follows the same wave: on every timer tick an electric piano plays the current character height
; as a degree of the pentatonic scale, so the arpeggio climbs as the text stretches and falls as it squashes.
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
    mov dx,3D4h
frame:
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
    push dx
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
.vs2:
    in al,dx
    test al,8
    jnz .vs2
    pop dx
    in al,60h
    cbw
    dec ax
    jnz frame                 ; Esc (scan code 1): AX = 0
    mov al,3
    int 10h                   ; text mode
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
    mov al,90h                ; note on
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
    popa
    iret
