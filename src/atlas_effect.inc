; Compile-time contract for every standalone ATLAS effect.
; Metadata is used by audits and source views only; it emits no bytes.
%ifndef EFFECT_ID
    %error "ATLAS effect must define EFFECT_ID"
%endif
%ifndef EFFECT_TITLE
    %error "ATLAS effect must define EFFECT_TITLE"
%endif
%ifndef EFFECT_SUMMARY
    %error "ATLAS effect must define EFFECT_SUMMARY"
%endif
%ifndef PALETTE
    %error "ATLAS effect must define PALETTE"
%elif PALETTE < 1 || PALETTE > 7
    %error "ATLAS PALETTE must be in the range 1..7"
%endif
%ifndef INSTRUMENT
    %error "ATLAS effect must define INSTRUMENT"
%elif INSTRUMENT < 0 || INSTRUMENT > 127
    %error "ATLAS INSTRUMENT must be a General MIDI program 0..127"
%endif

%assign ATLAS_EFFECT_COUNT 0
%ifdef CAUSAL
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef TIMELENS
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef HORIZON
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef EMBOSS
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef PHASE
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef SURGERY
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef COMMUTE
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef BRACKET
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef MIRROR
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef SIGNED
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef RESFIELD
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef TERRACE
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef RESIDUAL
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef BIFURC
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef CRITICAL
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef HYSTER
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef LOOM
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef LIFT
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef REVERSO
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef ORBIT
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef RUNS
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef BYTEVM
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef SHUFFLE
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef BALLOT
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef PREFIX
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef RANK
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif
%ifdef RING
    %assign ATLAS_EFFECT_COUNT ATLAS_EFFECT_COUNT + 1
%endif

%if ATLAS_EFFECT_COUNT != 1
    %error "ATLAS source must select exactly one effect kernel"
%endif

%include "temporal.inc"
