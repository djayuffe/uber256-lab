; FLOWTEX - the classic SELFTEX bands, code[x*y/1024 + t], in few colours and big flows. The program's own bytes
; are stretched into a 64 KB table once at start-up: 32 steps between each pair of neighbouring code bytes, linearly
; interpolated, so the bands of machine code become smooth satin ridges instead of pixel noise, each code byte now
; spanning sixteen times the area it did in SELFTEX. The palette is one sepia-to-ivory ramp. Per pixel the table index
; grows by y/32 (a 16.16 add, `add bp,dx` / `adc si,bx`), so a pixel is five instructions: one table read, no
; multiply, no division. Time slides the whole field along the code, 1/32 of a byte a frame.
; Music: a harp, calm as the flow, plays the four code bytes flowing in at the corner as an arpeggio, each note
; doubled two octaves down.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
tt  equ 0FF00h                ; the frame counter, in the program's own segment
    mov al,13h
    int 10h
    mov dx,3C9h
.pal:                         ; one warm ramp, sepia to ivory: s = i/4, (s, s - s/8, s - s/4)
    mov al,bl
    shr al,2
    out dx,al
    mov ah,al
    shr ah,3
    sub al,ah
    out dx,al
    sub al,ah
    out dx,al
    inc bl
    jnz .pal
    mov bx,100h               ; XLAT table = the program itself
    mov ax,cs
    add ah,10h
    mov es,ax                 ; the 64 KB flow table, the segment above the program
    mov gs,ax
    xor di,di
.tb:                          ; T[k] = a + (b - a) f / 32, a = code[k/32], b = code[k/32 + 1], f = k mod 32
    mov ax,di
    shr ax,5
    push ax
    inc ax
    xlat
    movzx dx,al               ; b
    pop ax
    xlat
    mov ah,0                  ; a
    sub dx,ax
    mov cx,di
    and cx,31
    imul dx,cx
    sar dx,5
    add ax,dx
    stosb
    test di,di                ; all 65,536 entries (the 256 code bytes, eight times over)
    jnz .tb
    HOOK_TICK isr                 ; the timer tick drives the music
    push word 0A000h
    pop es
frame:
    xor di,di
    xor ax,ax                 ; AH = y
    cwd
    xor bx,bx                 ; BX:DX = y/32 in 16.16: the index step per pixel
.row:
    mov si,[tt]               ; SI = the index at x = 0: time
    xor bp,bp                 ; its fraction
    mov cx,320
.px:
    add bp,dx
    adc si,bx
    mov al,[gs:si]
    stosb
    loop .px
    add dx,2048               ; the step grows by 1/32 a row
    adc bx,0
    inc ah
    cmp ah,200
    jb .row
    inc word [tt]
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    ESC_OR_LOOP frame
isr:                          ; INT 1Ch, 18.2 Hz
    pusha
    MIDI_START 46             ; program 46: orchestral harp
    mov ax,[fs:46Ch]
    shr ax,1
    jc .q
    and al,3                  ; a four-note arpeggio of the code bytes flowing in at the top-left corner
    mov bx,[cs:tt]            ; (a code byte is 32 table steps)
    shr bx,5
    add al,bl
    mov bx,100h
    cs xlat
    and al,30
    add al,46
    PENTA                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    out dx,al                 ; note
    out dx,al                 ; velocity = note
    sub al,24                 ; and two octaves below, softer: the harp's bass string
    out dx,al
    out dx,al
.q:
    popa
    iret
