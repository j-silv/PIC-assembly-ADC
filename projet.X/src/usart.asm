; ----------------------------------------------------
;        USART (mode asynchronous full-duplex)
; ----------------------------------------------------

      list p=16f877
      include "p16f877.inc"

; ==============================================================================
;                          variables/constantes
; ==============================================================================
      ; registers
      EXTERN     TX_CHAR_COUNT, CURRENT_MODE, MODE_REQUEST
      ; subprograms
      EXTERN      START_ADC

                 UDATA  0x21
PTR_PROMPT_MSG   RES 1   ; pointe a msg prompt pour l'utilisateur (6 bytes)
                            ; "Test\r\n" (bank 0)

			    ; put these in a separate header file as constants
      constant SIZE_PROMPT_MSG = 0x06   ; prompt message is 6 bytes long
      constant   X_VAL_SPBRG = D'25'  ; prescaler valeur pour le baud-rate generateur
      constant   VIRGULE_ASCII = 0x2C

      ; export labels to other modules
      GLOBAL     PTR_PROMPT_MSG, SIZE_PROMPT_MSG

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
    movlw	    ( 0<<TXEN | 0<<TX9 | 1<<BRGH | 0<<SYNC )
    movwf	    TXSTA

    ; peripherique serie est "enabled"
    ; enables continuous receive
    banksel     RCSTA
    movlw       ( 1<<SPEN | 1<<CREN )
    movwf       RCSTA

    banksel     TX_CHAR_COUNT
    clrf        TX_CHAR_COUNT    ; initaliser nombre de char a envoyer a 0
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
    xorlw       A'A'                 ; this operation will make Z flag = 0 if
                                     ; the character 'A' was received
    btfsc       STATUS, Z
    goto SET_AUTOMATIC_MODE

TEST_IF_A_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'a'                 ; this operation will make Z flag = 0 if
                                     ; the character 'a' was received
    btfsc       STATUS, Z
    goto SET_AUTOMATIC_MODE

TEST_IF_R_UPPER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'R'                 ; this operation will make Z flag = 0 if
                                     ; the character 'R' was received
    btfsc       STATUS, Z
    goto SET_MANUAL_MODE

TEST_IF_R_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'r'                 ; this operation will make Z flag = 0 if
                                     ; the character 'r' was received
    btfsc       STATUS, Z
    goto SET_MANUAL_MODE

TEST_IF_D_UPPER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'D'                 ; this operation will make Z flag = 0 if
                                     ; the character 'D' was received
    btfsc       STATUS, Z
    goto CONVERSION_REQUEST

TEST_IF_D_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'd'                 ; this operation will make Z flag = 0 if
                                     ; the character 'd' was received
    btfsc       STATUS, Z
    goto CONVERSION_REQUEST

SET_AUTOMATIC_MODE
    movlw       A'A'
    movwf       CURRENT_MODE         ; set the current mode reg to automatic
    banksel     PIE1
    bsf         PIE1, TMR1IE         ; Timer1 interrupt enable
    goto EXIT_CALLBACK

SET_MANUAL_MODE
    movlw       A'R'
    movwf       CURRENT_MODE         ; set the current mode reg to manual
    banksel     PIE1
    bcf         PIE1, TMR1IE         ; Timer1 interrupt disable
    goto EXIT_CALLBACK

CONVERSION_REQUEST
    movf        CURRENT_MODE, W
    xorlw       A'R'                 ; this operation will make Z flag = 0 if
                                     ; the current mode is manual! Thus the
                                     ; user has correctly requested a conersion
    btfsc       STATUS, Z
    call        START_ADC

EXIT_CALLBACK
    return

; ----------------------------------
;              TXIF
; ----------------------------------

TXIF_Callback
    GLOBAL      TXIF_Callback
    banksel     TXREG
    movlw       A'a'     ; move the ASCII code of "a" to w
    movwf       TXREG    ; write to USART transfer register
    return

; ----------------------------------
;          end module code
; ----------------------------------

    end
