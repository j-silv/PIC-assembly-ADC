; ------------------------------------
;              Interrupts
; ------------------------------------

    list p=16f877
    include "p16f877.inc"

; ==============================================================================
;                          variables/constantes
; ==============================================================================

    ; registers
    EXTERN      W_TEMP, STATUS_TEMP
     ; subprograms
    EXTERN      RCIF_Callback, TXIF_Callback

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

; Did we receive a message via USART?
RCIF_status
    banksel       PIR1
    btfsc         PIR1, RCIF
    PAGESEL       RCIF_Callback
    call          RCIF_Callback

; Did the Timer1 module overflow?
TMR1F_status
    nop       ; NOT YET CODED

; Is the analog to digital conversion done?
ADIF_status
    nop       ; NOT YET CODED

; Is the USART TX register ready for a new character?
TXIF_status
    banksel       PIR1
    btfsc         PIR1, TXIF
    PAGESEL       TXIF_Callback
    call          TXIF_Callback

; -------------------------------------
;       Restaurer le contexte
; -------------------------------------

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
