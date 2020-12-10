;______________________________________________________________________________
; TP Master 1 - MNE (2020-2021)
; Justin SILVER
;
; systeme d'acquisition, tension --> PC avec un
; microcontroleur - PIC16F877
;
; Ce programme lit une tension binaire venant de l'ADC, le
; convertit en decimal et apres en ASCII.
; Ensuite, le resultat est envoye via USART au terminal PC
; ______________________________________________________________________________

; ==============================================================================
;                           variables/constantes
; ==============================================================================

    ; import labels from other modules
    EXTERN      PTR_PROMPT_MSG, PTR_RESULT_MSG
    ; subprograms
    EXTERN      copy_init_data, PRINT_PROMPT_MSG
    EXTERN      USART_Config, ADC_Config, TMR1_Config

    ; ces registres sont accesibles de n'importe quelle page de memoire
    ; I believe I have to go ahead and use UDATA... I should do that
SHARED_REGS            UDATA_SHR
W_TEMP                 RES 1   ; pour context sauvegarde (ISR)
STATUS_TEMP            RES 1   ; pour context sauvegarde (ISR)
PCLATH_TEMP            RES 1   ; pour context sauvegarde (ISR)
ADC_RESULT_BINARY      RES 1   ; contient le resultat
                               ; binaire (tension) de l'ADC
ADC_RESULT_UNITY       RES 1   ; contient le resultat de la conversion UNITY
ADC_RESULT_DECIMAL     RES 1   ; contient le resultat de la conversion DECIMAL
TMR1_V_COUNT           RES 1   ; contient le nombre de fois le peripherique
                               ; Timer1 a fait un overflow
CURRENT_MODE           RES 1   ; contient le mode de fonctionnement actuel du systeme
                               ; 'A' pour automatique, 'D' pour manuel
MODE_REQUEST           RES 1   ; contient le mode de fonctionnement demande par
                               ; l'utilisateur

    ; export labels to other modules
    GLOBAL      W_TEMP, STATUS_TEMP, PCLATH_TEMP
    GLOBAL      ADC_RESULT_BINARY, ADC_RESULT_UNITY, ADC_RESULT_DECIMAL
    GLOBAL      TMR1_V_COUNT, CURRENT_MODE, MODE_REQUEST

; ==============================================================================
;                               configuration du uC
; ==============================================================================

    list p=16f877
    include "p16f877.inc"

    ; PIC16F877 Configuration Bit Settings
    ; turn on ICD with _DEBUG_OFF, because this
    ; clears the DEBUG bit in the config word (see doc)
    __CONFIG _DEBUG_OFF & _LVP_OFF & _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _CPD_OFF & _WRT_ON


START_PROGRAM   CODE      0x000
                nop              ; reserved for the  In-Circuit Debugger
                lgoto      MAIN_Config

#define INTERRUPTS_ON            ; si commenté, les interrupts ne sont pas enables
                                 ; si c'est le cas, seulement le message de prompt
                                 ; est affiché au terminal et le programme reste
                                 ; dans la boucle while() sans en sortir

; ==============================================================================
;                         configuration des periphiques
; ==============================================================================

MAIN_FILE       CODE

; ENABLE_MCLR
    ; banksel     PCON
    ; ; this is to enable master clear button on PICDEM
    ; movlw	    (1 << NOT_BOR | 1 << NOT_POR )
    ; movwf       PCON

MAIN_Config
    lcall       copy_init_data
    ; the ADC result msg is initialized to "[X,X, ,V,\r,\n,\0]"
    ; the prompt terminal msg is initialized to "[T,E,S,T,\r,\n,\0]"
    lcall       USART_Config
    lcall       ADC_Config
    lcall       TMR1_Config


; ==============================================================================
;               Load/initialize prompt and result msg and print prompt
; ==============================================================================

    ; the prompt terminal message is sent with polling method to PC terminal
    lcall        PRINT_PROMPT_MSG

    ; Transmission is now disabled after printing prompt -> transmission will only be
    ; enabled after ADIF goes high signaling the end of an ADC, and then the result
    ; is transcoded in ASCII and saved to the RESULT_MSG string for
    ; subsequent USART transmission. At this point TXEN is set
    banksel     TXSTA
    bcf         TXSTA, TXEN

; ==============================================================================
;                           Interrupts configuration
; ==============================================================================

; clear appropiate interrupt flags on startup
CLR_PERIPH_FLAGS
  banksel     PIR1
  bcf         PIR1, TMR1IF
  bcf         PIR1, ADIF

USART_TXIF_DISABLE          ; upon startup, only the RCIF should be enabled
  banksel     PIE1
  bcf         PIE1, TXIE

ADC_ADIF_DISABLE
  banksel     PIE1
  bcf         PIE1, ADIE

#ifdef INTERRUPTS_ON
PERIPH_INT_ENABLE
  banksel     INTCON
  bsf         INTCON, PEIE  ; ADC/USART peripheral interrupt enable
USART_RCIF_ENABLE
  banksel     PIE1
  bsf         PIE1, RCIE   ; Receive USART flag enable
GLOBAL_INT_ENABLE
  banksel     INTCON
  bsf         INTCON, GIE  ; global interrupt enable
#endif

; ==============================================================================
;                       programme principal (boucle infinie)
; ==============================================================================

main
        nop
        lgoto     main

; ----------------------------------
;          end module code
; ----------------------------------
        end
