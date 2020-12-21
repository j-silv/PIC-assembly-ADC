; ----------------------------------------------------
;            Configuration and main program
; ----------------------------------------------------

    list p=16f877
    include "p16f877.inc"

; ==============================================================================
;                       variables, constants, labels
; ==============================================================================

    ; subprograms
    EXTERN      PRINT_PROMPT_MSG
    EXTERN      INITIALIZE_USART_STRINGS, USART_Config, ADC_Config, TMR1_Config

; these registers are accessible from any register bank
SHARED_REGS            UDATA_SHR
W_TEMP                 RES 1   ; for context saving (ISR)
STATUS_TEMP            RES 1   ; for context saving (ISR)
PCLATH_TEMP            RES 1   ; for context saving (ISR)
ADC_RESULT_BINARY      RES 1   ; saves raw ADC result before conversion
                               ; also holds intermediate calculations during conversion
ADC_RESULT_UNITY       RES 1   ; contains the "ones" place value in ASCII
ADC_RESULT_DECIMAL     RES 1   ; contains the "decimal" place value in ASCII
TMR1_V_COUNT           RES 1   ; contains the number of times Timer1 has overflowed
CURRENT_MODE           RES 1   ; contains the current mode of the system (automatic/manual)
MODE_REQUEST           RES 1   ; contains the mode requested by the user (automatic/manual)

    ; these labels are available to other modules
    GLOBAL      W_TEMP, STATUS_TEMP, PCLATH_TEMP
    GLOBAL      ADC_RESULT_BINARY, ADC_RESULT_UNITY, ADC_RESULT_DECIMAL
    GLOBAL      TMR1_V_COUNT, CURRENT_MODE, MODE_REQUEST

; ==============================================================================
;                         PIC16F877 configuration
; ==============================================================================

    ; PIC16F877 configuration word settings
    __CONFIG _LVP_OFF & _DEBUG_OFF & _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _CPD_OFF & _WRT_ON

START_PROGRAM   CODE      0x000
                nop              ; reserved for the In-Circuit Debugger
                lgoto     MAIN_Config

#define INTERRUPTS_ON            ; if this is commented, then no interrupts will fire
                                 ; and only the message prompt will be sent to the terminal

; ==============================================================================
;                        peripheral configuration
; ==============================================================================

MAIN_FILE       CODE

MAIN_Config
    ; the ADC result msg is initialized to [X, X,  , V, \r, \n, \0]
    ; the prompt terminal msg is initialized to [C, A, N, \r, \n, \0]
    lcall       INITIALIZE_USART_STRINGS
    lcall       USART_Config
    lcall       ADC_Config
    lcall       TMR1_Config

; ==============================================================================
;                          print prompt message
; ==============================================================================

    ; the prompt terminal message is sent with polling method to PC terminal
    lcall        PRINT_PROMPT_MSG

    ; the USART transmission is disabled so that the interrupt flag, TXIF, stays low
    ; until after an A/D conversion is complete
    ; this is necessary because the TXIF flag will be checked in the ISR after
    ; the ADC callback subprogram. It will always be high before an A/D conversion starts
    ; even if the TXIE is low. As a result, if the TXEN bit is not cleared,
    ; the TXIF subprogram will be called and a message will be sent via USART before
    ; the A/D conversion starts
    ; Thus, simply disabling TXIE is not sufficient to avoid branching into the
    ; TXIF subprogram in the ISR
    banksel     TXSTA
    bcf         TXSTA, TXEN

; ==============================================================================
;                           interrupts configuration
; ==============================================================================

CLR_PERIPH_FLAGS
  banksel     PIR1
  bcf         PIR1, TMR1IF
  bcf         PIR1, ADIF

USART_TXIF_DISABLE
  banksel     PIE1
  bcf         PIE1, TXIE

ADC_ADIF_DISABLE
  banksel     PIE1
  bcf         PIE1, ADIE

#ifdef INTERRUPTS_ON
PERIPH_INT_ENABLE
  banksel     INTCON
  bsf         INTCON, PEIE
USART_RCIF_ENABLE
  banksel     PIE1
  bsf         PIE1, RCIE   ; Receive USART flag enable
                           ; upon startup, only the RCIF should be enabled
                           ; so the user can define the mode (automatic/manual)
GLOBAL_INT_ENABLE
  banksel     INTCON
  bsf         INTCON, GIE
#endif

; ==============================================================================
;                       main program (endless loop)
; ==============================================================================

main
        nop
        lgoto     main

; ----------------------------------
;          end module code
; ----------------------------------
        end
