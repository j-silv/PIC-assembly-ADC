; ----------------------------------------------------
;                      USART
; ----------------------------------------------------

    list p=16f877
    include "p16f877.inc"

; ==============================================================================
;                       variables, constants, labels
; ==============================================================================

      ; registers
      EXTERN    CURRENT_MODE, MODE_REQUEST, TMR1_V_COUNT

      ; subprograms
      EXTERN    START_ADC

      ; USART baud-rate prescaler value
      ; formula (asynchronous) = Baud-rate = FOSC/(16(X+1)) where X is the
      ; value in the SPBRG register and is between 0-255
      ; for a 9600 baud-rate with a FOSC of 4 MHz, we get X = 25
      constant  X_VAL_SPBRG = D'25'

USART_MSGS      IDATA
PTR_PROMPT_MSG  DB  "CAN\r\n\0"
PTR_RESULT_MSG  DB  "X,X V\r\n\0"

      ; these labels are available to other modules
      GLOBAL     PTR_PROMPT_MSG, PTR_RESULT_MSG

; ==============================================================================
;                          peripheral configuration
; ==============================================================================

USART_FILE    CODE
USART_Config
    GLOBAL      USART_Config
    ; inputs/outputs (RC6/TX/CK and RC7/RX/DT)
    ; TXUSART is an output (RC6 -> output)
    ; RXUSART is an input (RC7 -> input)
    banksel     TRISC
    movlw       ( 0<<TRISC6 | 1<<TRISC7 )
    movwf       TRISC

    ; USART baud-rate setup
    banksel     SPBRG
    movlw       X_VAL_SPBRG
    movwf       SPBRG

    ; asynchronous mode
    ; HIGH SPEED mode (BRGH = 1) to reduce error on the baud-rate generation
    ; 8-bit transmission mode
    ; enable transmission (for polling prompt msg transmission)
    banksel     TXSTA
    movlw       ( 1<<TXEN | 0<<TX9 | 1<<BRGH | 0<<SYNC )
    movwf       TXSTA

    ; USART receiver setup
    banksel     RCSTA
    movlw       ( 1<<SPEN | 1<<CREN )
    movwf       RCSTA

    return

; ==============================================================================
;               Initialization of the prompt and result msgs
;===============================================================================

INITIALIZE_USART_STRINGS
    GLOBAL   INITIALIZE_USART_STRINGS

    bankisel PTR_PROMPT_MSG
    movlw    PTR_PROMPT_MSG
    movwf    FSR

; ----------------------------------------------
;           Initialize the prompt msg
; ----------------------------------------------

    movlw A'C'
    movwf INDF

    incf FSR,F
    movlw A'A'
    movwf INDF

    incf FSR,F
    movlw A'N'
    movwf INDF

    incf FSR,F
    movlw A' '
    movwf INDF

    incf FSR,F
    movlw A'\r'
    movwf INDF

    incf FSR,F
    movlw A'\n'
    movwf INDF

    incf FSR,F
    movlw A'\0'
    movwf INDF

; ----------------------------------------------
;           Initialize the result msg
; ----------------------------------------------

    bankisel PTR_RESULT_MSG
    movlw    PTR_RESULT_MSG
    movwf    FSR

    incf FSR,F              ; comma index of result msg string
    movlw A','
    movwf INDF

    incf FSR,F
    incf FSR,F              ; empty space index of result msg string

    movlw A' '
    movwf INDF

    incf FSR,F              ; volts index of result msg string
    movlw A'V'
    movwf INDF

    incf FSR,F
    movlw A'\r'
    movwf INDF

    incf FSR,F
    movlw A'\n'
    movwf INDF

    incf FSR,F
    movlw A'\0'
    movwf INDF

    return

; ==============================================================================
;               Print prompt message to PC terminal (polling)
;===============================================================================

; ----------------------------------------------
;      Print prompt via USART to PC terminal
; ----------------------------------------------

PRINT_PROMPT_MSG
    GLOBAL      PRINT_PROMPT_MSG
    ; a banksel AND a bankisel are necessary because the 2 different registers
    ; are accessed with 2 different methods (direct/indirect addressing)
    banksel     PIR1              ; set the appropiate values of (RP1, RP0)
    bankisel    PTR_PROMPT_MSG    ; set the appropiate value of (IRP)

    movlw       PTR_PROMPT_MSG
    movwf       FSR               ; point to the start of the prompt msg

TEST_END_OF_PROMPT_MSG
    movf        INDF, W           ; move current byte pointed by FSR to work reg
    xorlw       A'\0'             ; this operation will make Z flag = 1 if
                                  ; null character ('\0') of the msg is reached
    btfsc       STATUS, Z         ; if the end of the msg is reached, end USART comm
    goto        PROMPT_MSG_SENT

TEST_TXIF
    btfss       PIR1, TXIF        ; test if the TX_REG is empty
    goto        TEST_TXIF

    movf        INDF, W           ; place msg byte pointed to by FSR into work reg
    movwf       TXREG             ; send msg byte to USART TX register
    incf        FSR               ; increment pointer index to next byte in prompt msg
    goto        TEST_END_OF_PROMPT_MSG

; it is not necessary to preload the FSR and preset the IRP, a nop instruction could
; be placed here instead, or a rearranged labeling
PROMPT_MSG_SENT
                bankisel PTR_RESULT_MSG   ; preselect the correct bank for indirect addressing
                                          ; the start of this msg
                movlw PTR_RESULT_MSG      ; preload the FSR with the address to the
                movwf FSR                 ; ADC result (this will be the next msg to send)

                return

; ==============================================================================
;                           Interrupt callbacks
; ==============================================================================

; ----------------------------------
;              RCIF
; ----------------------------------

RCIF_Callback
    GLOBAL      RCIF_Callback
    banksel     RCREG
    movf        RCREG, W
    movwf       MODE_REQUEST         ; save what was received into a dedicated register
                                     ; this is to avoid possibly reading 2 different
                                     ; bytes in FIFO during the XOR tests below
TEST_IF_A_UPPER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'A'                 ; this operation will make Z flag = 1 if
                                     ; the character 'A' was received
    btfsc       STATUS, Z
    goto        SET_AUTOMATIC_MODE

TEST_IF_A_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'a'                 ; this operation will make Z flag = 1 if
                                     ; the character 'a' was received
    btfsc       STATUS, Z
    goto        SET_AUTOMATIC_MODE

TEST_IF_R_UPPER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'R'                 ; this operation will make Z flag = 1 if
                                     ; the character 'R' was received
    btfsc       STATUS, Z
    goto        SET_MANUAL_MODE

TEST_IF_R_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'r'                 ; this operation will make Z flag = 1 if
                                     ; the character 'r' was received
    btfsc       STATUS, Z
    goto        SET_MANUAL_MODE

TEST_IF_D_UPPER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'D'                 ; this operation will make Z flag = 1 if
                                     ; the character 'D' was received
    btfsc       STATUS, Z
    goto        CONVERSION_REQUEST

TEST_IF_D_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'd'                 ; this operation will make Z flag = 1 if
                                     ; the character 'd' was received
    btfsc       STATUS, Z
    goto        CONVERSION_REQUEST

INVALID_CHAR_SENT
    goto        EXIT_RCIF_CALLBACK   ; otherwise, a character other than A,a,R,r,D,d was sent


SET_AUTOMATIC_MODE
    movlw       A'A'
    movwf       CURRENT_MODE

    ; the TMR1 and its interrupt are enabled at this point because in automatic mode
    ; the peripheral should be counting
    banksel     T1CON
    bsf         T1CON, TMR1ON
    banksel     PIE1
    bsf         PIE1, TMR1IE

    ; reset overflow count register (0 ms have passed)
    ; necessary in case RCIF is raised while TMR1_V_COUNT is at 1
    ; if that happens, TMR1_V_COUNT would never be reset
    banksel     TMR1_V_COUNT
    clrf        TMR1_V_COUNT
    goto        EXIT_RCIF_CALLBACK

SET_MANUAL_MODE
    movlw       A'R'
    movwf       CURRENT_MODE

    ; the TMR1 and its interrupt are disabled at this point because in manual mode
    ; the peripheral should NOT be counting
    banksel     T1CON
    bcf         T1CON, TMR1ON
    banksel     PIE1
    bcf         PIE1, TMR1IE

    goto        EXIT_RCIF_CALLBACK

CONVERSION_REQUEST
    movf        CURRENT_MODE, W
    xorlw       A'R'                 ; this operation will make Z flag = 1 if
                                     ; the current mode is manual! Thus the
                                     ; user has correctly requested a conversion

    btfss       STATUS, Z            ; a btfss instead of a btfsc is performed here
                                     ; because if Z is set, then we DO want to
                                     ; start the ADC and if it isn't, then we want
                                     ; to exit this callback
    goto        EXIT_RCIF_CALLBACK
    lcall       START_ADC
    PAGESEL     EXIT_RCIF_CALLBACK ; not technically necessary to perform
                                   ; a PAGESEL psuedoinstruction here since no subsequent
                                   ; goto instructions are performed in this object module

EXIT_RCIF_CALLBACK
    return

; ----------------------------------
;              TXIF
; ----------------------------------

TXIF_Callback
    GLOBAL      TXIF_Callback
    bankisel    PTR_RESULT_MSG    ; ensuring the (RP0, RP1) bits are correctly set/reset
                                  ; shouldn't really be necessary since
                                  ; indirect addressing should not occur
                                  ; elsewhere after printing the prompt message
TEST_END_OF_RESULT_MSG
    movf        INDF, W           ; move current byte pointed by FSR to work reg
    xorlw       A'\0'             ; this operation will make Z flag = 1 if
                                  ; null character ('\0') of the msg is reached
    btfsc       STATUS, Z         ; if the end of the msg is reached, end USART comm
    goto RESULT_MSG_SENT

SEND_NEW_BYTE
    banksel     TXREG
    movf        INDF, W           ; place msg byte pointed to by FSR into work reg
    movwf       TXREG             ; send msg byte to USART TX register
    incf        FSR               ; increment pointer index to next byte in result msg
    goto EXIT_TXIF_CALLBACK

RESULT_MSG_SENT
    banksel     TXSTA
    bcf         TXSTA, TXEN       ; disable USART transmission
    banksel     PIE1
    bcf         PIE1, TXIE
    bsf         PIE1, RCIE

EXIT_TXIF_CALLBACK
    return

; ----------------------------------
;          end module code
; ----------------------------------

    end
