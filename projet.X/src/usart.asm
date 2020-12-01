; ----------------------------------------------------
;        USART (mode asynchronous full-duplex)
; ----------------------------------------------------

      list p=16f877
      include "p16f877.inc"

      constant   X_VAL_SPBRG = D'25'  ; prescaler valeur pour le baud-rate generateur

; ==============================================================================
;                          variables/constantes
; ==============================================================================
      ; registers
      EXTERN      CURRENT_MODE, MODE_REQUEST
      ; subprograms
      EXTERN      START_ADC

                 UDATA  0x21
PTR_PROMPT_MSG   RES 1   ; pointe a msg prompt pour l'utilisateur "Test\r\n"
PTR_RESULT_MSG   RES 1   ; pointe a ADC result qu'on va envoyer via mode auto/manual

      ; export labels to other modules
      GLOBAL     PTR_PROMPT_MSG, PTR_RESULT_MSG

; ==============================================================================
;                          peripheral configuration
; ==============================================================================

USART_FILE    CODE
USART_Config
    GLOBAL      USART_Config    ; export sub-program label to other modules
    ; entrees/sorties (RC6/TX/CK and RC7/RX/DT)
    ; TXUSART EST OUTPUT (RC6 -> sortie)
    ; RXUSART EST INPUT (RC7 -> entree)
    banksel     TRISC
    movlw       ( 0<<TRISC6 | 1<<TRISC7 )
    movwf       TRISC

    ; USART baud-rate
    ; Utilisation de HIGH SPEED mode (BRGH = 1) pour reduire l'erreur sur le baud rate
    ; formule du baud rate = (Asynchronous) Baud Rate = FOSC/(16(X+1)) ou X  est la
    ; valeur du registre SPBRG et est de 0...255
    ; nous voulons 9600 baud avec un FOSC de 4 MHz, ca donne X = 25
    banksel     SPBRG
    movlw       X_VAL_SPBRG
    movwf       SPBRG

    ; mode asynchrone
    ; high speed pour reduire l'erreur
    ; 8-bit transmission mode
    ; enable la transmission
    banksel     TXSTA
    movlw           ( 1<<TXEN | 0<<TX9 | 1<<BRGH | 0<<SYNC )
    movwf           TXSTA

    ; peripherique serie est "enabled"
    ; enables continuous receive
    banksel     RCSTA
    movlw       ( 1<<SPEN | 1<<CREN )
    movwf       RCSTA

    banksel     TX_CHAR_COUNT
    clrf        TX_CHAR_COUNT    ; initaliser nombre de char a envoyer a 0
    return



; ==============================================================================
;                      Load/initialize result msg
; ==============================================================================

LOAD_RESULT_RAM
    GLOBAL   LOAD_RESULT_RAM
    bankisel PTR_RESULT_MSG                 ; selectionner banque pour l'acces indirecte

    movlw (PTR_RESULT_MSG + UNITY_OFFSET)
    movwf FSR
    movlw A'X'
    movwf INDF

    movlw (PTR_RESULT_MSG + COMMA_OFFSET)
    movwf FSR
    movlw A','
    movwf INDF

    movlw (PTR_RESULT_MSG + DECIMAL_OFFSET)
    movwf FSR
    movlw A'X'
    movwf INDF

    movlw (PTR_RESULT_MSG + SPACE_OFFSET)
    movwf FSR
    movlw A' '
    movwf INDF

    movlw (PTR_RESULT_MSG + VOLT_OFFSET)
    movwf FSR
    movlw A'V'
    movwf INDF

    incf FSR,F              ; return carriage character
    movlw A'\r'
    movwf INDF

    incf FSR,F              ; new line character
    movlw A'\n'
    movwf INDF

    incf FSR,F              ; END OF STRING NULL CHARACTER
    movlw A'\0'
    movwf INDF

    return

; ==============================================================================
;                    Print prompt message to PC terminal (polling)
; ==============================================================================

; ------------------------------------------
;      Load prompt message into RAM
; ------------------------------------------

LOAD_PROMPT_RAM
    GLOBAL   LOAD_PROMPT_RAM
    bankisel PTR_PROMPT_MSG ; selectionner banque pour l'acces indirecte
    movlw PTR_PROMPT_MSG    ; intialiser le pointeur

    movwf FSR               ; le FSR contient le pointeur
    movlw A'T'              ; premier byte du message prompt
    movwf INDF              ; Le registre pointe par PTR_PROMPT_MSG
                            ; est charge avec le premier byte du msg ('T') en ASCII
    incf FSR,F              ; prochain byte
    movlw A'e'              ; etc...
    movwf INDF

    incf FSR,F
    movlw A's'
    movwf INDF

    incf FSR,F
    movlw A't'
    movwf INDF

    incf FSR,F              ; return carriage character
    movlw A'\r'
    movwf INDF

    incf FSR,F              ; new line character
    movlw A'\n'
    movwf INDF

    incf FSR,F              ; END OF STRING NULL CHARACTER
    movlw A'\0'
    movwf INDF

    return

; ----------------------------------------------
;      Print prompt via USART to PC terminal
; ----------------------------------------------

PRINT_PROMPT_MSG
    GLOBAL PRINT_PROMPT_MSG
    ; necessaire a faire un banksel/bankisel pour les deux, car ces 2 registres sont accede
    ; par 2 manieres different - addressage directe et addressage indirecte
    banksel     PIR1              ; selectionne le bank pour PIR1 this (RP1, RP0)
    bankisel    PTR_PROMPT_MSG    ; selectionne le bank pour PTR_PROMPT_MSG (IRP)

    movlw       PTR_PROMPT_MSG
    movwf       FSR               ; point to the start of the prompt msg

TEST_END_OF_MSG
    movf        INDF, W           ; move current byte pointed by FSR to work reg
    xorlw       A'\0'             ; this operation will make Z flag = 1 if
                                  ; null character ('\0') of the msg is reached
    btfsc       STATUS, Z         ; if the end of the msg is reached, end USART comm
    goto MSG_SENT

TEST_TXIF
    btfss       PIR1, TXIF        ; test if the TX_REG is empty
    goto        TEST_TXIF         ; sinon, attendre

    movf        INDF, W           ; place msg byte pointed to by FSR into work reg
    movwf       TXREG             ; send msg byte to USART TX register
    incf        FSR               ; increment pointer index to next byte in prompt msg
    goto        TEST_END_OF_MSG

; it is not necessary to preload the FSR and preset the IRP, a nop instruction could
; be placed here instead, or a rearranged labeling
MSG_SENT
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
    goto SET_AUTOMATIC_MODE

TEST_IF_A_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'a'                 ; this operation will make Z flag = 1 if
                                     ; the character 'a' was received
    btfsc       STATUS, Z
    goto SET_AUTOMATIC_MODE

TEST_IF_R_UPPER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'R'                 ; this operation will make Z flag = 1 if
                                     ; the character 'R' was received
    btfsc       STATUS, Z
    goto SET_MANUAL_MODE

TEST_IF_R_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'r'                 ; this operation will make Z flag = 1 if
                                     ; the character 'r' was received
    btfsc       STATUS, Z
    goto SET_MANUAL_MODE

TEST_IF_D_UPPER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'D'                 ; this operation will make Z flag = 1 if
                                     ; the character 'D' was received
    btfsc       STATUS, Z
    goto CONVERSION_REQUEST

TEST_IF_D_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'd'                 ; this operation will make Z flag = 1 if
                                     ; the character 'd' was received
    btfsc       STATUS, Z
    goto CONVERSION_REQUEST

SET_AUTOMATIC_MODE
    movlw       A'A'
    movwf       CURRENT_MODE         ; set the current mode reg to automatic
    banksel     PIE1
    bsf         PIE1, TMR1IE         ; Timer1 interrupt enable

    ; reset overflow count register (0 ms have passed)
    ; necessary in case RCIF raised while TMR1_V_COUNT is at 1
    ; if that happens, TMR1_V_COUNT would never be reset
    banksel     TMR1_V_COUNT
    clrf        TMR1_V_COUNT
    goto EXIT_CALLBACK

SET_MANUAL_MODE
    movlw       A'R'
    movwf       CURRENT_MODE         ; set the current mode reg to manual
    banksel     PIE1
    bcf         PIE1, TMR1IE         ; Timer1 interrupt disable
    goto EXIT_CALLBACK

CONVERSION_REQUEST
    movf        CURRENT_MODE, W
    xorlw       A'R'                 ; this operation will make Z flag = 1 if
                                     ; the current mode is manual! Thus the
                                     ; user has correctly requested a conersion
    btfsc       STATUS, Z
    PAGESEL     START_ADC
    call        START_ADC

EXIT_CALLBACK
    return

; ----------------------------------
;              TXIF
; ----------------------------------

TXIF_Callback
    GLOBAL      TXIF_Callback
    bankisel    PTR_RESULT_MSG    ; this shouldn't really be necessary since
                                  ; indirect addressing isn't used unexpectedly
TEST_END_OF_MSG
    movf        INDF, W           ; move current byte pointed by FSR to work reg
    xorlw       A'\0'             ; this operation will make Z flag = 1 if
                                  ; null character ('\0') of the msg is reached
    btfsc       STATUS, Z         ; if the end of the msg is reached, end USART comm
    goto MSG_SENT

SEND_NEW_BYTE
    banksel     TXREG
    movf        INDF, W           ; place msg byte pointed to by FSR into work reg
    movwf       TXREG             ; send msg byte to USART TX register
    incf        FSR               ; increment pointer index to next byte in result msg
    goto EXIT_CALLBACK

MSG_SENT
    banksel     PIE1
    bcf         PIE1, TXIE  ; USART TX interrupt flag disable
    bsf         PIE1, RCIE  ; USART RC interrupt flag enable

EXIT_CALLBACK
    return

; ----------------------------------
;          end module code
; ----------------------------------

    end
