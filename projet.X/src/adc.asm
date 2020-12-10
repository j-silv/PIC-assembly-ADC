; ----------------------------------------------
;                       ADC
; ----------------------------------------------

    list p=16f877
    include "p16f877.inc"

; ==============================================================================
;                          variables/constantes
; ==============================================================================

        ; registers
        EXTERN       PTR_RESULT_MSG
        EXTERN       ADC_RESULT_BINARY, ADC_RESULT_UNITY, ADC_RESULT_DECIMAL

        constant     ADC_BIN_VOLT_UNITY_RATIO = D'51'
        constant     ADC_BIN_VOLT_DECIMAL_RATIO = D'5'
        constant     ASCII_NUMBER_OFFSET = 0x30

        constant     UNITY_OFFSET = 0x00  	; this corresponds to the index that the UNITY value occupies
                                            ; in the USART string
        constant     DECIMAL_OFFSET = 0x02	; this corresponds to the index that the DECIMAL value occupies
                                            ; in the USART string


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

    ; as long as there is no program memory boundary crossing in this module, no need to
    ; use a long call which selects the appropiate page bits
    call        ADC_BIN_TO_DEC_TO_ASCII
    ; once this function returns, the UNITY and DECIMAL values should be
    ; properly calculated and located in their dedicated registers
    ; we can now place these values into the appropiate indexes in the USART string

; ----------------------------------
;  Place results in USART string
; ----------------------------------

    ; This section performs the following ->
    ; result[U_offset] = Unity   (register)
    ; result[D_offset] = Decimal (register)
    bankisel PTR_RESULT_MSG   ; select the correct bank for indirect addressing
                              ; of the result message string
    movlw    (PTR_RESULT_MSG + UNITY_OFFSET)
    movwf    FSR              ; point to unity index in USART string
    movf     ADC_RESULT_UNITY, W
    movwf    INDF             ; place the ADC_UNITY_RESULT into the USART string
                              ; at the UNITY index
    movlw    (PTR_RESULT_MSG + DECIMAL_OFFSET)
    movwf    FSR              ; point to decimal index in USART string
    movf     ADC_RESULT_DECIMAL, W
    movwf    INDF             ; place the ADC_DECIMAL_RESULT into the USART string
                              ; at the DECIMAL index

; --------------------------------------------
;  Set FSR to point to start of USART string
; --------------------------------------------

    ; this is performed at the end, so that once the TXIF is raised, the FSR
    ; and IRP bits (bankisel) are good to go
    movlw PTR_RESULT_MSG      ; preload the FSR with the address to the
    movwf FSR                 ; ADC result (this will be the next msg to send)

    ; a movlw then mowf  using bit-wise operations
    ; cannot be done here, because the state of the TMR1IE is
    ; not directly known (automatic/manual). this is why bsf/bsf
    ; operations are performed instead
    banksel     PIE1
    bcf         PIE1, RCIE   ; Receive USART flag disable
    banksel     TXSTA
    bsf         TXSTA, TXEN  ; transmission is now enabled
    banksel     PIE1
    bsf         PIE1, TXIE   ; USART TX interrupt flag enable

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
           movwf    ADC_RESULT_BINARY    ; sauvegarder resultat (tension) en memoire
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

; ------------------------------------------------------------------------
; Example/explanation: carry bit/NOT_borrow bit
; If we perform the subtract instruction -> 3-5, the ALU in the PIC uC performs
; a 2's complement on the 2nd operand and follows with an addition
; ------------------------------------------------------------------------
;   3  =   0011 =    3  =   0011   ->  3 in 2's complement and unsigned
; - 5  = - 0101 = +(-5) = + 1011   -> -5 in 2's complement, 11 in unsigned
;                       = 0 1110   =  -2 in 2's complement, 14 in unsigned
;               carry bit ^
; ------------------------------------------------------------------------
; What we see here is that if the result is supposed to be negative, the
; carry bit will be RESET. This will always be the case.
;
; However, if the inverse of this operation is done -> 5-3, we see that
; the result is expected to be positive and the 2's complement conversion
; is what leads to the carry bit being SET
; ------------------------------------------------------------------------
;   5  =   0101 =    5  =   0101  ->  5 in 2's complement and unsigned
; - 3  = - 0011 = +(-3) = + 1101  -> -3 in 2's complement, 13 in unsigned
;                       = 1 0010  =  -2 (in 2's complement), 18 in unsigned!
;               carry bit ^
; ------------------------------------------------------------------------

ADC_BIN_TO_DEC_TO_ASCII
    GLOBAL  ADC_BIN_TO_DEC_TO_ASCII

    movlw   (ASCII_NUMBER_OFFSET - 0x01)
    movwf   ADC_RESULT_UNITY            ; ADC_RESULT_UNITY currently contains 0x2F
    movwf   ADC_RESULT_DECIMAL          ; ADC_RESULT_DECIMAL currently contains 0x2F
                                        ; previous unity/decimal results are effectively erased
    ; pull result from A/D Result High Register (ADRESH)
    ; because the ADC is configured in left justified,
    ; we should be pulling the 8 MSBs from the 10-bit result
    banksel ADRESH
    movf    ADRESH,W
    movwf   ADC_RESULT_BINARY           ; save to dedicated register for subsequent subwf instructions

; ------------------------------------
;           UNITY calculation
; ------------------------------------

    ; first pass through this instruction block, ADC_RESULT_UNITY
    ; will become 0x30 (0 in ASCII)
    ; by preloading this register with ASCII_NUMBER_OFFSET - 1, the initial value is
    ; effectively "set" to 0 in ASCII, without the need for extra gotos
CALCULATE_UNITY_PLACE
    incf    ADC_RESULT_UNITY, F
    movwf   ADC_RESULT_BINARY           ; save result of substraction (division "remainder")
    movlw   ADC_BIN_VOLT_UNITY_RATIO    ; prepare substraction constant value in working reg

    subwf   ADC_RESULT_BINARY, W        ; subtract 51 from binary result (1 volt corresponds to 51 in dec (ratio))
    btfsc   STATUS, C                   ; if the carry bit is SET, the result is POSITIVE
    goto    CALCULATE_UNITY_PLACE       ; this means that the UNITY value for the ADC result is not yet found

; ------------------------------------
;        DECIMAL calculation
; ------------------------------------

    movf    ADC_RESULT_BINARY, W        ; After UNITY calculation, the division "remainder" is placed
                                        ; working reg to test if the remainder is 50 (special case)

; special case; the remainder = 50
; if this test is not done, then the decimal place is going to show
; the character (:), which is the ASCII result of incrementing the decimal 
; place by 10 from 0

TEST_IF_REMAINDER_IS_50
    xorlw       D'50'                   ; this operation will make Z flag = 1 if it is the 
                                        ; the special case that the remainder = 50
    btfsc       STATUS, Z               ; if it is, then the decimal place should automatically become 
                                        ; the 0 in ASCII and the unite should be "rounded" up 
    goto        REMAINDER_IS_50

    movf    ADC_RESULT_BINARY, W        ; After testing special case, the division "remainder" is placed
                                        ; into working reg after xor operation 
                                        ; to calculate the DECIMAL place value of ADC result

CALCULATE_DECIMAL_PLACE
    incf    ADC_RESULT_DECIMAL, F
    movwf   ADC_RESULT_BINARY           ; save result of substraction (division "remainder")
    movlw   ADC_BIN_VOLT_DECIMAL_RATIO  ; prepare substraction constant value in working reg

    subwf   ADC_RESULT_BINARY, W        ; subtract 5 from binary result (0.1 volt corresponds to 5 in dec (ratio))
    btfsc   STATUS, C                   ; if the carry bit is SET, the result is POSITIVE
    goto    CALCULATE_DECIMAL_PLACE     ; this means that the DECIMAL value for the ADC result is not yet found


EXIT_CONVERSION
    return
    
REMAINDER_IS_50
    movlw   A'0'                        
    movwf   ADC_RESULT_DECIMAL          ; the decimal place automatically takes the ASCII character 0
    incf    ADC_RESULT_UNITY, F         ; round up the result (the unity is incremented)
                                        ; this means that 4.9 would become 5, 3.9 would become 4, etc...
    goto    EXIT_CONVERSION

; ----------------------------------
;          end module code
; ----------------------------------

    end
