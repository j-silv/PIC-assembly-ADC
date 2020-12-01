; ----------------------------------------------
;                       ADC
; ----------------------------------------------

        list p=16f877
        include "p16f877.inc"

; ==============================================================================
;                          variables/constantes
; ==============================================================================

        ; registers
        EXTERN       ADC_RESULT, PTR_RESULT

; ==============================================================================
;                          peripheral configuration
; ==============================================================================
ADC_FILE       CODE
ADC_Config
        GLOBAL       ADC_Config
        banksel      ADCON1
        ; Left justify ,1 analog channel
        ; VDD and VSS references
        movlw        ( 0<<ADFM | 1<<PCFG3 | 1<<PCFG2 | 1<<PCFG1 | 0<<PCFG0 )
        movwf        ADCON1

        banksel      ADCON0
        ; Fosc/8, A/D enabled
        movlw        ( 0 << ADCS1 | 1<<ADCS0 | 1<<ADON )
        movwf        ADCON0
        return

; ==============================================================================
;                           Interrupt callbacks
; ==============================================================================

; ----------------------------------
;              ADIF
; ----------------------------------

ADIF_Callback
    GLOBAL      ADIF_Callback

    ; not sure if it's necessary to PAGESEL for subprograms within the same module
    PAGESEL ADC_bin2dec
    call ADC_bin2dec      ; NOT YET CODED

    PAGESEL dec2ASCII
    call dec2ASCII        ; NOT YET CODED

    bankisel PTR_RESULT   ; preselect the correct bank for indirect addressing
                          ; of the result message string


    ; result[U_offset] = Unity   (register)
    ; result[D_offset] = Decimal (register)
    ; register[virgule_offset] = A',' (this will never change)
    ; register[volt_offset] = A'V'    (this will never change)
    ; etc....

    ; this is performed at the end, so that once the TXIF is raised, the FSR
    ; and IRP bits (bankisel) are good to go
    movlw PTR_RESULT      ; preload the FSR with the address to the
    movwf FSR             ; ADC result (this will be the next msg to send)

    banksel     PIE1
    bsf         PIE1, TXIE  ; USART TX interrupt flag enable
    return

; ==============================================================================
;                               Sub-programs
; ==============================================================================

; -------------------------------------
;      Lire tension ADC (polling)
; -------------------------------------

Lire_Tension_Polling
           GLOBAL   Lire_Tension_Polling
           banksel  ADCON0
start      bsf      ADCON0,GO            ; demarrage de la conversion
non        btfsc    ADCON0,GO_NOT_DONE   ; attendre la fin de conversion
           goto     non
oui        movf     ADRESH,W             ; mettre resultat (8 bits de poids fort)
                                         ; de la conversion au reg de travail
           movwf    ADC_RESULT           ; sauvegarder resultat (tension) en memoire
           return

; -------------------------------------
;   Start ADC conversion (interrupts)
; -------------------------------------

START_ADC
           GLOBAL      START_ADC
           banksel     ADCON0
           bsf         ADCON0, GO     ; demarrage de la conversion
           banksel     PIE1
           bsf         PIE1, ADIE     ; ADC conversion done interrupt flag enable
           return

; ------------------------------------
;           Transcodage ASCII
; ------------------------------------

ADC_bin2dec
    nop
    return

dec2ASCII
    nop
    return


; ----------------------------------
;          end module code
; ----------------------------------

    end
