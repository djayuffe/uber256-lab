; dos.inc - the plumbing every demo shares. Macros only: including this file emits no bytes by itself.

; Hook the BIOS timer tick (INT 1Ch, 18.2 Hz) through DOS. The old vector (ES:BX from function 35h) and AX = 251Ch
; stay on the stack for UNHOOK_EXIT, so the main loop must leave the stack balanced. Clobbers AX, BX, DX, ES.
%macro HOOK_TICK 1
    mov ax,351Ch
    int 21h
    push es
    push bx
    mov ah,25h
    mov dx,%1
    int 21h
    push ax                   ; AX = 251Ch, for the unhook
%endmacro

; Once per frame: loop back to %1 unless Esc (scan code 1) is down; on Esc set text mode 3, put the timer vector
; back and return to DOS. "cbw / dec ax" leaves AX = 0 on Esc, so "mov al,3" is mode 3.
%macro ESC_OR_LOOP 1
    in al,60h
    cbw
    dec ax
    jnz %1
    mov al,3
    int 10h                   ; text mode
    pop ax                    ; unhook INT 1Ch: AX = 251Ch, DS:DX = the old vector
    pop dx
    pop ds
    int 21h
    ret
%endmacro

; Start of a tick handler's MIDI: DX = 330h; one OUT DX,AX sends C0h (program change) to the MPU-401 data port and
; 3Fh (enter UART mode; ignored once in it) to its command port 331h; then the program number and 90h (note on,
; channel 1). Clobbers AX, DX.
%macro MIDI_START 1
    mov dx,330h
    mov ax,3FC0h
    out dx,ax
    mov al,%1                 ; General MIDI program
    out dx,al
    mov al,90h                ; note on, channel 1
    out dx,al
%endmacro

; AL = 2d (even) -> floor(12d/5): 6*(2d div 5) + (2d mod 5) = 2d + floor(2d/5), degree d of C major pentatonic.
%macro PENTA 0
    aam 5
    aad 6
%endmacro
