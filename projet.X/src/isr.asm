; ------------------------------------
;              Interrupts
; ------------------------------------

    list p=16f877
    include "p16f877.inc"

; ==============================================================================
;                          variables/constantes
; ==============================================================================

    ; registers
    EXTERN      W_TEMP, STATUS_TEMP     ; these registers are shared across
                                        ; all banks, thus no banksel instruction is
                                        ; necessary to access them
     ; subprograms
    EXTERN      RCIF_Callback, TMR1IF_Callback, ADIF_Callback, TXIF_Callback

; ==============================================================================
;                        Interrupt service routine (ISR)
; ==============================================================================

; ------------------------------------
;       Sauvegarder le contexte
; ------------------------------------

ISR_FILE    CODE        0x004             ; interrupt vector location pour le PIC uC
            movwf       W_TEMP            ; Copy W to TEMP register
            swapf       STATUS, W         ; Swap status to be saved into W
            movwf       STATUS_TEMP       ; Save status to bank zero STATUS_TEMP register

; -----------------------------------
;           Flag checking
; -----------------------------------

; Although PIR1 is the same interrupt flag register for
; all the peripherals used in this program, it's important to
; still perform a banksel PIR1. This is to deal with situations where
; the X_Callback subprogram causes the current bank to be changed

; Did we receive a message via USART?
RCIF_status
    banksel       PIR1
    btfss         PIR1, RCIF
    lgoto          TMR1IF_status         ; check next flag if this flag is not set
    lcall          RCIF_Callback

; Did the Timer1 module overflow?
TMR1IF_status
    banksel       PIR1
    btfss         PIR1, TMR1IF          ; check next flag if this flag is not set
    lgoto          ADIF_status

    bcf           PIR1, TMR1IF          ; clear flag
    lcall          TMR1IF_Callback

; Is the analog to digital conversion done?
ADIF_status
    banksel       PIR1
    btfss         PIR1, ADIF           ; check next flag if this flag is not set
    lgoto          TXIF_status

    bcf           PIR1, ADIF           ; clear flag
    lcall          ADIF_Callback

; Is the USART TX register ready for a new character?
TXIF_status
    banksel       PIR1
    btfss         PIR1, TXIF
    lgoto          INT_FLAG_CHECK_DONE  ; all flags checked

    lcall          TXIF_Callback

; -------------------------------------
;       Restaurer le contexte
; -------------------------------------

INT_FLAG_CHECK_DONE
    swapf         STATUS_TEMP,W   ; Swap STATUS_TEMP register into W
                                  ; (sets bank to original state)
    movwf         STATUS          ; Move W into STATUS register
    swapf         W_TEMP,F        ; Swap W_TEMP
    swapf         W_TEMP,W        ; Swap W_TEMP into W
    retfie                        ; return from interrupt


; ----------------------------------
;          end module code
; ----------------------------------

    end
