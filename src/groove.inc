; groove.inc - a rhythm section for the tick handler: included after the melody, with DX = 330h, the MPU in UART
; mode, and only AX free to use. Every fourth tick (a quarter note at 18.2/16 bars a second, about 68 bpm in
; 4/4 with 16th-note melodies) it plays GM percussion on channel 10: kick, closed hi-hat, snare, hi-hat. On each
; kick a bass note sounds on channel 2 (program 0, piano), walking down C - A - G - E - D: the bar number times 4, mod 5,
; is the pentatonic degree 0, 4, 3, 2.
    mov ax,[fs:46Ch]
    test al,3
    jnz .g_end
    mov ah,42                 ; closed hi-hat on the off-beats
    test al,4
    jnz .g_drum
    mov ah,38                 ; snare on beats 2 and 4
    test al,8
    jnz .g_drum
    shr al,2                  ; a kick bar-beat: AL = t/16 * 4 (the low two bits are 0)
    aam 5                     ; AL = (bar * 4) mod 5: 0 4 3 2 1 = C A G E D
    add al,al
    add al,30                 ; 2(d + 15): two octaves below middle C
    aam 5
    aad 6
    mov ah,al
    mov al,91h                ; note on, channel 2: the bass
    out dx,al
    mov al,ah
    out dx,al
    mov al,100
    out dx,al
    mov ah,36                 ; and the kick
.g_drum:
    mov al,99h                ; note on, channel 10: drums
    out dx,al
    mov al,ah
    out dx,al
    add al,60                 ; velocity 96..102
    out dx,al
.g_end:
