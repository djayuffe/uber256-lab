; LATCH - a cellular automaton computed by the VGA's own write logic. Mode 0Dh is planar: one byte address holds
; 8 pixels in each of 4 planes. Reading a byte loads all 32 bits into the VGA latches; in write mode 3 with the
; XOR function and a 1-bit rotate, writing the byte back copies the latched pixels and XORs the set/reset colour
; into every pixel whose LEFT neighbour has plane 0 set. Copying each row from the row below therefore draws the
; space-time diagram of rule 60 (Sierpinski) rising up the screen, two one-byte CPU instructions per 8 pixels.
; The music is the same fractal in time: a music box plays the ruler sequence (how many times the step number
; divides by two: 0 1 0 2 0 1 0 3 ...), the Towers-of-Hanoi rhythm that is also the Sierpinski triangle's,
; over a drum kit and a walking bass (groove.inc). The 15 colours run through a flowing rainbow and the
; attribute controller's pixel panning makes the picture shimmer.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
    mov al,0Dh
    int 10h                   ; 320x200, 16 colours, planar
    HOOK_TICK isr                 ; the timer tick drives the music
    push word 0A000h
    pop es
    mov dx,3CEh               ; VGA graphics controller
    mov ax,0F01h              ; GR01: set/reset enabled on all four planes
    out dx,ax
    mov ax,1803h              ; GR03: logical function XOR
    out dx,ax
    mov ax,0305h              ; GR05: write mode 3 (bit mask = rotated CPU data)
    out dx,ax
frame:
    mov al,0                  ; GR00: set/reset colour = frame counter
    mov ah,bl
    out dx,ax
    mov al,[es:9000h]         ; load zero latches, then seed the row just below the screen
    mov al,bl                 ; two seeds: the frame counter's bits at x = 16, their complement at x = 168
    mov [es:8002],al
    not al
    mov [es:8021],al
    mov si,40
    xor di,di
    mov cx,8000
.row:
    es lodsb                  ; latches <- 8 pixels x 4 planes from one row down
    rcr al,1                  ; plane-0 mask shifted one pixel right; CF carries the last pixel into the next byte
    stosb                     ; written one row up, XOR colour where the left neighbour has plane 0 set
    loop .row
    inc bx
    push dx
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs                    ; (the read also resets the attribute controller's flip-flop)
    mov dl,0C0h               ; attribute controller 13h, pixel panning: the waterfalls shimmer sideways
    mov al,33h
    out dx,al
    mov al,bl
    shl al,2
    test al,32
    jz .up
    not al
.up:
    shr al,2
    and al,7
    out dx,al
    mov dl,0C8h               ; the DAC from colour 1 (black stays black): a flowing rainbow, each component a
    mov al,1                  ; triangle of (time + 86 * byte position), so R, G and B are a third of a cycle apart
    out dx,al
    inc dx
    mov cx,63*3
.pal:
    mov al,cl
    imul ax,ax,86
    add al,bl
    add al,al
    jnc .p
    not al
.p:
    shr al,2
    out dx,al
    loop .pal
    pop dx
    ESC_OR_LOOP frame
isr:                          ; INT 1Ch, 18.2 Hz
    pusha
    MIDI_START 10             ; program 10: music box
    mov ax,[fs:46Ch]          ; BIOS tick count
    shr ax,1
    jc .q                     ; a note every other tick
    bsf ax,ax                 ; the ruler function of the step: its trailing zero bits
    jz .q
    add al,al
    add al,50
    PENTA                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic, from C4
    out dx,al                 ; note
    out dx,al                 ; velocity = note
.q:
%include "groove.inc"
    popa
    iret
