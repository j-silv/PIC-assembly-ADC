; ----------------------------------
;              Timer1
; ----------------------------------

    list p=16f877
    include "p16f877.inc"

; ==============================================================================
;                          variables/constantes
; ==============================================================================
    ; registers
    EXTERN      TMR1_V_COUNT
    ; subprograms
    EXTERN      START_ADC

; ==============================================================================
;                          peripheral configuration
; ==============================================================================
TMR1_FILE  CODE
TMR1_Config
    GLOBAL      TMR1_Config
    banksel     T1CON
    ; Prescaler = 1:8
    ; Oscillator shut off
    ; Internal clock (Fosc/4) used
    ; Timer enabled
    movlw       ( 1<<T1CKPS1 | 1<<T1CKPS0 | 0 << TMR1CS | 1<<TMR1ON )
    movwf       T1CON
    clrf        TMR1_V_COUNT   ; initaliser nombre d'overflow compte a 0


; ==============================================================================
;                           Interrupt callbacks
; ==============================================================================

; ----------------------------------
;              TMMR1IF
; ----------------------------------

TMR1IF_Callback
    GLOBAL      TMR1IF_Callback
    call        START_ADC
    return


; ----------------------------------
;          end module code
; ----------------------------------

    end
