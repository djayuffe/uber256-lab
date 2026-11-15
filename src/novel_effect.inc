; Compile-time contract for the six effects specified in 256.md.
; Metadata emits no bytes; every source must select exactly one kernel.
%ifndef EFFECT_ID
    %error "Novel effect must define EFFECT_ID"
%endif
%ifndef EFFECT_TITLE
    %error "Novel effect must define EFFECT_TITLE"
%endif
%ifndef EFFECT_SUMMARY
    %error "Novel effect must define EFFECT_SUMMARY"
%endif
%ifndef PALETTE
    %error "Novel effect must define PALETTE"
%elif PALETTE < 1 || PALETTE > 7
    %error "Novel effect PALETTE must be in the range 1..7"
%endif
%ifndef INSTRUMENT
    %error "Novel effect must define INSTRUMENT"
%elif INSTRUMENT < 0 || INSTRUMENT > 127
    %error "Novel effect INSTRUMENT must be a General MIDI program 0..127"
%endif

%assign NOVEL_EFFECT_COUNT 0
%ifdef XORTUN
    %assign NOVEL_EFFECT_COUNT NOVEL_EFFECT_COUNT + 1
%endif
%ifdef PLASMA
    %assign NOVEL_EFFECT_COUNT NOVEL_EFFECT_COUNT + 1
%endif
%ifdef CAFLAME
    %assign NOVEL_EFFECT_COUNT NOVEL_EFFECT_COUNT + 1
%endif
%ifdef VOXFLOOR
    %assign NOVEL_EFFECT_COUNT NOVEL_EFFECT_COUNT + 1
%endif
%ifdef KALEIDO
    %assign NOVEL_EFFECT_COUNT NOVEL_EFFECT_COUNT + 1
%endif
%ifdef RAYMARCH
    %assign NOVEL_EFFECT_COUNT NOVEL_EFFECT_COUNT + 1
%endif
%if NOVEL_EFFECT_COUNT != 1
    %error "Novel source must select exactly one effect kernel"
%endif

%include "temporal.inc"
