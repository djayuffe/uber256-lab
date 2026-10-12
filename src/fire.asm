; FIRE - framebuffer feedback: every pixel becomes the average of the four pixels below it, minus a
; little. Two random rows of heat at the bottom keep the energy up (the thing NEBULA lacked).
; The music is read off the fire: every other tick a probe drifting through the flames reads the heat
; under it; a hot pixel plays a nylon-guitar note, higher and louder the hotter it is. A drum kit and a walking
; bass (groove.inc) play under it, and one white-hot ember a frame is dropped into the lower half to rise as a spark.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
    mov al,13h
    int 10h
    mov dx,3C9h
.pal:                         ; fire palette: R = min(63, i/2), G = i/4, B = i/8
    mov al,bl
    shr al,1
    cmp al,63
    jbe .r
    mov al,63
.r:
    out dx,al
    mov al,bl
    shr al,2
    out dx,al
    shr al,1
    out dx,al
    inc bl
    jnz .pal
    HOOK_TICK isr                 ; the timer tick drives the music
    push word 0A000h
    pop es
    push es
    pop ds                    ; DS = ES = video: no segment prefixes in the loop
frame:
    mov di,63680              ; the last two rows get fresh random heat
    mov cx,640
.seed:
    imul bx,bx,25173          ; 16-bit LCG: the high byte is the noise
    add bx,13849
    cmp bh,110                ; about 40% of the pixels are white-hot, the rest cold
    sbb al,al
    stosb
    loop .seed
    mov di,bx                 ; one ember a frame: a white-hot pixel somewhere in the lower half, which the
    shr di,1                  ; averaging then lifts and spreads into a rising spark
    mov byte [di+32000],255
    xor di,di
.p:
    movzx ax,byte [di+319]
    movzx cx,byte [di+320]
    add ax,cx
    movzx cx,byte [di+321]
    add ax,cx
    movzx cx,byte [di+640]
    add ax,cx
    shr ax,2
    sub al,1                  ; cool by one, but never below zero
    adc al,0
    stosb
    cmp di,63680
    jb .p
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    ESC_OR_LOOP frame
isr:
    pusha
    MIDI_START 24             ; nylon guitar
    mov ax,[fs:46Ch]
    shr ax,1
    jc .q
    imul bx,ax,1283           ; the probe: 4 rows and 3 pixels on each step, kept in the flames (rows 141-204)
    or bh,0B0h
    mov al,[es:bx]            ; the heat under it
    cmp al,40
    jb .q                     ; cold: a rest
    shr al,3
    and al,30
    add al,40
    PENTA
    out dx,al
    out dx,al
.q:
%include "groove.inc"
    popa
    iret
