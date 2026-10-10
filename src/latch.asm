; LATCH - a cellular automaton computed by the VGA's own write logic. Mode 0Dh is planar: one byte address holds
; 8 pixels in each of 4 planes. Reading a byte loads all 32 bits into the VGA latches; in write mode 3 with the
; XOR function and a 1-bit rotate, writing the byte back copies the latched pixels and XORs the set/reset colour
; into every pixel whose LEFT neighbour has plane 0 set. Copying each row from the row below therefore draws the
; space-time diagram of rule 60 (Sierpinski) rising up the screen, two one-byte CPU instructions per 8 pixels.
BITS 16
CPU 386
ORG 100h
    mov al,0Dh
    int 10h                   ; 320x200, 16 colours, planar
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
    jz .vs
    pop dx
    in al,60h
    dec al
    jnz frame
    mov ax,3
    int 10h
    ret
