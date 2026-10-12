; MEGA - the uber256-lab megademo: eleven of the intros in one program, each introduced by a title card and closed by
; a fade, with its own live music, ending on WARP bending the credits.
;
; Each part is its own source assembled with -DMEGA (build.sh): the same code as the 256-byte release, except that its
; exit macro also ends the part when the BIOS tick count reaches the word at PSP:5Ch, flags Esc at PSP:5Eh and leaves
; the screen as it is. The megademo runs a part the way DOS runs a .COM: it clears a 64 KB segment above itself, puts
; the part at offset 100h, a far jump back to itself at offset 0 (where the part's final RET lands), the end tick at
; 5Ch, gives it its own stack and the registers DOS gives a program, and jumps in. Between parts it reads the DAC and
; fades the picture to black, then draws the next title in the BIOS 8x8 font, scaled up, in a gold gradient that fades
; in and out. Esc at any moment ends the show.
BITS 16
CPU 386
ORG 100h
%include "sizes.inc"          ; the byte counts of the 256-byte builds, written by build.sh

    cld
    xor ax,ax
    mov fs,ax                 ; FS = 0: the BIOS tick count is [fs:46Ch], as every part assumes
    mov ax,cs
    add ax,1000h
    mov [pseg],ax             ; the parts run in the 64 KB segment above the megademo
    mov ax,1130h              ; the BIOS 8x8 font (characters 0..127)
    mov bh,3
    push es
    int 10h
    mov [font],bp
    mov [font+2],es
    pop es
    mov ax,13h
    int 10h
    mov cx,90                 ; a moment of black before the show
.dark:
    call vsync
    jc quit
    loop .dark
    mov word [hold],200
    mov si,intro
    call card
    jc quit
    mov word [hold],80
    mov bx,parts
.next:
    lea si,[bx+PT_TITLE]
    push bx
    call card
    pop bx
    jc quit
    cmp word [bx+PT_BIN],warp_bin
    jne .run
    push bx
    call credits              ; WARP bends whatever is on the text screen: give it the credits
    pop bx
.run:
    push bx
    call run_part
    pop bx
    mov es,[pseg]
    cmp byte [es:5Eh],0
    jne quit                  ; Esc during the part
    push bx
    call fade_out
    pop bx
    jc quit
    add bx,PT_SIZE
    cmp bx,parts_end
    jb .next
    mov word [hold],240
    mov si,outro
    call card                 ; the end
quit:
    mov ax,3
    int 10h
    mov dx,bye
    mov ah,9
    int 21h
    ret

; ---- one part: a fresh segment, DOS's entry conditions, a far jump home at PSP:0, the end tick at PSP:5Ch
run_part:
    mov es,[pseg]
    xor di,di
    xor ax,ax
    mov cx,8000h
    rep stosw                 ; a clean 64 KB, as a freshly loaded program would mostly see
    mov byte [es:0],0EAh      ; jmp far back
    mov word [es:1],back
    mov [es:3],cs
    mov si,[bx+PT_BIN]
    mov cx,[bx+PT_LEN]
    mov di,100h
    rep movsb
    mov ax,[fs:46Ch]
    add ax,[bx+PT_TICKS]
    mov [es:5Ch],ax
    mov [save_sp],sp
    mov ax,es
    cli
    mov ss,ax
    mov sp,0FFFEh
    sti
    push word 0               ; the part's RET goes to PSP:0
    push ax
    push word 100h
    mov ds,ax
    xor ax,ax                 ; the registers DOS starts a .COM with
    xor bx,bx
    mov cx,00FFh
    mov dx,ds
    mov si,100h
    mov di,0FFFEh
    mov bp,091Ch
    retf
back:
    cli
    mov ax,cs
    mov ss,ax
    mov sp,[cs:save_sp]
    sti
    mov ds,ax
    cld
    ret

; ---- the frame clock: wait for the end of one retrace and the start of the next; CF = 1 if Esc is down
vsync:
    push ax
    push dx
    mov dx,3DAh
.a: in al,dx
    test al,8
    jnz .a
.b: in al,dx
    test al,8
    jz .b
    in al,60h
    cmp al,1                  ; Esc down: CF = 1
    stc
    je .c
    clc
.c: pop dx
    pop ax
    ret

; ---- fade the current picture to black over 32 frames (any mode: it is the DAC that fades)
fade_out:
    push ds
    pop es
    mov dx,3C7h
    xor al,al
    out dx,al
    mov dl,0C9h
    mov di,dac
    mov cx,768
    rep insb
    mov bl,31
.f: call vsync
    jc .x
    mov dx,3C8h
    xor al,al
    out dx,al
    inc dx
    mov si,dac
    mov cx,768
.v: lodsb
    mul bl
    shr ax,5
    out dx,al
    loop .v
    dec bl
    jns .f
    clc
.x: ret

; ---- a title card: SI -> big title, then a byte-count line, then a tagline (each zero-terminated)
card:
    mov ax,13h
    int 10h
    xor bl,bl
    call card_pal             ; everything black while drawing
    push word 0A000h
    pop es
    mov byte [scale],5
    mov byte [ty],44
    mov byte [solid],0
    call text                 ; the name, 40 pixels high, in a gold gradient
    mov byte [scale],2
    mov byte [ty],108
    mov byte [solid],200
    call text                 ; the size
    mov byte [scale],1
    mov byte [ty],140
    mov byte [solid],201
    call text                 ; the tagline
    mov bl,0
.in:                          ; fade in over 32 frames
    call vsync
    jc .x
    call card_pal
    inc bl
    cmp bl,33
    jb .in
    mov cx,[hold]             ; hold
.h: call vsync
    jc .x
    loop .h
    mov bl,32
.out:
    call vsync
    jc .x
    call card_pal
    dec bl
    jns .out
    clc
.x: ret

; card palette at brightness BL/32: colours 64..127 a gradient from ivory (top of the letters) to deep gold (bottom),
; 200 and 201 two warm greys for the small lines
card_pal:
    push cx
    inc byte [phase]          ; a band of white light runs down the letters, one gradient step a frame
    mov dx,3C8h
    mov al,64
    out dx,al
    inc dx
    xor cx,cx
.p: mov al,cl                 ; the band: 5 x (6 - d) where d = (k - phase) mod 64 is below 6
    sub al,[phase]
    and al,63
    sub al,6
    neg al
    jg .band
    xor al,al
.band:
    mov ah,5
    mul ah
    mov [boost],al
    mov al,cl                 ; R = 63 - k/4
    shr al,2
    neg al
    add al,63
    call .out
    mov al,cl                 ; G = 60 - k/2
    shr al,1
    neg al
    add al,60
    call .out
    mov al,cl                 ; B = 50 - 3k/4
    mov ah,al
    shr ah,2
    sub al,ah
    neg al
    add al,50
    call .out
    inc cx
    cmp cx,64
    jb .p
    dec dx
    mov al,200
    out dx,al
    inc dx
    mov byte [boost],0
    mov al,58
    call .out
    mov al,54
    call .out
    mov al,46
    call .out
    mov al,34
    call .out
    mov al,30
    call .out
    mov al,24
    call .out
    pop cx
    ret
.out:
    add al,[boost]
    cmp al,63
    jbe .o
    mov al,63
.o: mul bl
    shr ax,5
    out dx,al
    ret

; draw the zero-terminated string at SI, centred, BIOS font scaled by [scale], top row [ty]; [solid] = 0 for the
; gold gradient (colour 64 + 8 x glyph row + sub-row), else that colour. SI is left after the terminator.
text:
    push si
    xor cx,cx
.len:
    lodsb
    test al,al
    jz .gotlen
    inc cx
    jmp .len
.gotlen:
    pop si
    movzx ax,byte [scale]
    shl ax,3
    mul cx                    ; width in pixels
    neg ax
    add ax,320
    shr ax,1
    mov [tx],ax
.ch:
    lodsb
    test al,al
    jz .done
    push si
    movzx si,al
    shl si,3
    add si,[font]             ; the glyph, in the BIOS font segment
    xor dx,dx                 ; DL = glyph row, DH = sub-row
.row:
    push ds
    mov ds,[cs:font+2]
    mov ah,[si]
    pop ds
    xor dh,dh
.sub:
    movzx di,byte [ty]        ; y = ty + row * scale + sub
    movzx bx,dl
    movzx cx,byte [scale]
    imul bx,cx
    add di,bx
    movzx bx,dh
    add di,bx
    imul di,di,320
    add di,[tx]
    mov al,[solid]            ; colour
    test al,al
    jnz .c
    movzx ax,dh
    shl ax,3
    div byte [scale]          ; 8 x sub / scale (AH is clobbered: reload the glyph row)
    mov bl,dl
    shl bl,3
    add al,bl
    add al,64
.c:
    push si
    push ds
    mov ds,[cs:font+2]
    mov ah,[si]
    pop ds
    pop si
    mov bh,8                  ; eight columns
.col:
    movzx cx,byte [scale]
    shl ah,1
    jnc .skip
    rep stosb
    jmp short .nx
.skip:
    add di,cx
.nx:
    dec bh
    jnz .col
    inc dh
    cmp dh,[scale]
    jb .sub
    inc si
    inc dl
    cmp dl,8
    jb .row
    pop si
    movzx ax,byte [scale]
    shl ax,3
    add [tx],ax
    jmp .ch
.done:
    ret

; ---- the credits that WARP bends: text mode 3, centred lines in colours 1..15
credits:
    mov ax,3
    int 10h
    mov ah,1
    mov cx,2000h
    int 10h                   ; no cursor
    push word 0B800h
    pop es
    mov si,credit_lines
    mov di,3 * 160
    mov bl,9                  ; colour
.line:
    cmp byte [si],0FFh
    je .done
    push di
    push si                   ; centre it: (80 - length) / 2
    xor cx,cx
.l: lodsb
    test al,al
    jz .ll
    inc cx
    jmp .l
.ll:
    pop si
    mov ax,80
    sub ax,cx
    and ax,-2
    add di,ax
.put:
    lodsb
    test al,al
    jz .eol
    mov ah,bl
    stosw
    jmp .put
.eol:
    pop di
    add di,160 * 2
    inc bl
    cmp bl,16
    jb .line
    mov bl,9
    jmp .line
.done:
    ret

; ---- the programme
PT_BIN   equ 0
PT_LEN   equ 2
PT_TICKS equ 4
PT_TITLE equ 6
%macro PART 5                 ; label, file, seconds, title, tagline
    dw %1_bin, %1_end - %1_bin, %3 * 182 / 10
    db %4, 0, %2, " BYTES", 0, %5, 0
%endmacro
; (every entry is padded to the same size so the table can be walked)
PT_SIZE  equ 80
%macro ENTRY 5
%%e:
    PART %1, %2, %3, %4, %5
    times PT_SIZE - ($ - %%e) db 0
%endmacro

intro:
    db "UBER256", 0, "LAB  MEGADEMO", 0, SZ_COUNT, " INTROS, 256 BYTES EACH, MUSIC LIVE", 0
outro:
    db "THE END", 0, SZ_COUNT, " INTROS", 0, "ALL OF THEM TOGETHER: ", SZ_TOTAL, " BYTES", 0
parts:
    ENTRY flowtex, SZ_FLOWTEX, 16, "FLOWTEX", "ITS OWN MACHINE CODE, AS SATIN - HARP"
    ENTRY selftex, SZ_SELFTEX, 16, "SELFTEX", "A RIVER OF MACHINE CODE - KALIMBA"
    ENTRY goldtex, SZ_GOLDTEX, 16, "GOLDTEX", "POLISHED GOLD ON CODE - GLOCKENSPIEL"
    ENTRY order,   SZ_ORDER,   16, "ORDER",   "SHAPES FROM ORDERINGS - PIZZICATO"
    ENTRY galaxy,  SZ_GALAXY,  20, "GALAXY",  "A DE JONG ATTRACTOR - VIBRAPHONE"
    ENTRY cliff,   SZ_CLIFF,   16, "CLIFF",   "A CLIFFORD ATTRACTOR - MARIMBA"
    ENTRY fire,    SZ_FIRE,    16, "FIRE",    "FEEDBACK AND HEAT - GUITAR"
    ENTRY roots,   SZ_ROOTS,   16, "ROOTS",   "A CUBIC'S MIGRATING ROOTS - STEEL DRUMS"
    ENTRY julia,   SZ_JULIA,   20, "JULIA",   "A JULIA SET, IN SLOW MOTION - CELESTA"
    ENTRY latch,   SZ_LATCH,   16, "LATCH",   "COMPUTED BY THE VGA ITSELF - MUSIC BOX"
    ENTRY warp,    SZ_WARP,    24, "WARP",    "THE CREDITS, BENT - ELECTRIC PIANO"
parts_end:

credit_lines:
    db "U B E R 2 5 6 - L A B   M E G A D E M O", 0
    db "eleven intros of 256 bytes or less, each playing its own music", 0
    db "FLOWTEX  SELFTEX  GOLDTEX  ORDER  GALAXY  CLIFF", 0
    db "FIRE  ROOTS  JULIA  LATCH  WARP", 0
    db "code and music: djayuffe & Claude", 0
    db "NASM - 16-bit real mode - VGA - x87 - MPU-401 General MIDI", 0
    db "github.com/djayuffe/uber256-lab", 0
    db "thanks for watching", 0
    db 0FFh
bye:
    db "uber256-lab megademo - eleven intros, 256 bytes each. Thanks for watching.", 13, 10, "$"

%macro BIN 2
%1_bin:
    incbin %2
%1_end:
%endmacro
    BIN flowtex, "build/FLOWTEX.MEG"
    BIN selftex, "build/SELFTEX.MEG"
    BIN goldtex, "build/GOLDTEX.MEG"
    BIN order,   "build/ORDER.MEG"
    BIN galaxy,  "build/GALAXY.MEG"
    BIN cliff,   "build/CLIFF.MEG"
    BIN fire,    "build/FIRE.MEG"
    BIN roots,   "build/ROOTS.MEG"
    BIN julia,   "build/JULIA.MEG"
    BIN latch,   "build/LATCH.MEG"
    BIN warp,    "build/WARP.MEG"

section .bss
pseg:    resw 1
font:    resw 2
save_sp: resw 1
tx:      resw 1
hold:    resw 1
phase:   resb 1
boost:   resb 1
scale:   resb 1
ty:      resb 1
solid:   resb 1
dac:     resb 768
