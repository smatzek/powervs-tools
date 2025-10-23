/* This program calls a shell script to upload a file to COS                  */

/* It can be called like this:                                                */
/* CALL PGM(QGPL/COSUPLOAD) PARM(('/home/qsecofr/myfile.pdf' (*CHAR 256))),   */
/* where "/home/qsecofr/myfile.pdf" is the file to upload.                    */

/* It is based in large part on this QSH Error Trapping thread:               */
/* https://code400.com/forum/forum/iseries-programming-languages/rpg-rpgle    */
/*    /7142-qsh-error-trapping#post66763                                      */
/* which in turn is a reposting of:                                           */
/* Article ID: 17841 Posted January 8th, 2004 in Systeminetwork               */
/* by Scott Klement, which can no longer be found online.                     */

PGM PARM(&FILENAME)
    DCL VAR(&FILENAME) TYPE(*CHAR) LEN(256)
    DCL VAR(&MSGID) TYPE(*CHAR) LEN(7)
    DCL VAR(&MSGDTA) TYPE(*CHAR) LEN(256)
    DCL VAR(&RESULT) TYPE(*CHAR) LEN(4)
    DCL VAR(&STATUS) TYPE(*DEC) LEN(3 0)
    DCL VAR(&CHARSTAT) TYPE(*CHAR) LEN(10)
    DCL VAR(&UPLOADCMD) TYPE(*CHAR) LEN(500)
    DCL VAR(&ERRMSG) TYPE(*CHAR) LEN(512)
    DCL VAR(&SYSNAME) TYPE(*CHAR) LEN(8)
    DCL VAR(&EMAILSUBJ) TYPE(*CHAR) LEN(50)

    /* CHANGE QIBM_QSH_CMD_OUTPUT TO STDOUT ON THE NEXT LINE TO SEE QSH OUTPUT*/
    ADDENVVAR  ENVVAR(QIBM_QSH_CMD_OUTPUT) VALUE(NONE) +
                REPLACE(*YES)

    ADDENVVAR  ENVVAR(QIBM_QSH_CMD_ESCAPE_MSG) VALUE(Y) +
                REPLACE(*YES)

    CHGVAR VAR(&UPLOADCMD) VALUE('/QOpenSys/usr/bin/sh -c "' +
        *CAT '/home/qsecofr/cos-upload-helper.sh ' +
        *CAT &FILENAME *TCAT '"')
    /*DBG: SNDPGMMSG MSGID(CPF9897) MSGF(QCPFMSG) MSGDTA(&UPLOADCMD) */
    STRQSH CMD(&UPLOADCMD)

    MONMSG MSGID(QSH0005 QSH0006 QSH0007) EXEC(DO)
        RCVMSG  MSGTYPE(*LAST) RMV(*YES) MSGDTA(&MSGDTA) +
                        MSGID(&MSGID)
        IF (&MSGID *EQ 'QSH0005') DO
            CHGVAR VAR(&RESULT) VALUE(%SST(&MSGDTA 1 4))
            CHGVAR VAR(&STATUS) VALUE(%BIN(&RESULT))
        ENDDO
        IF (&MSGID *EQ 'QSH0006') DO
            CHGVAR VAR(&RESULT) VALUE(%SST(&MSGDTA 1 4))
            CHGVAR VAR(&STATUS) VALUE(-1)
        ENDDO
        IF (&MSGID *EQ 'QSH0007') DO
            CHGVAR VAR(&STATUS) VALUE(-1)
        ENDDO
        IF (&STATUS *NE 0) THEN(DO)
            CHGVAR VAR(&CHARSTAT) VALUE(&STATUS)
            CHGVAR VAR(&ERRMSG) VALUE('COS upload +
                of file ' *CAT &FILENAME *TCAT ' failed with status ' *BCAT +
                &CHARSTAT *BCAT ' and MSGID ' *BCAT &MSGID)
            SNDPGMMSG  MSGID(CPF9897) MSGF(QCPFMSG) MSGDTA(&ERRMSG)
            RTVNETA SYSNAME(&SYSNAME)
            CHGVAR VAR(&EMAILSUBJ) VALUE('COS upload failure on system ' +
                *CAT &SYSNAME)
            CHGVAR VAR(&ERRMSG) VALUE(&ERRMSG *CAT ' on system ' *CAT &SYSNAME)
            /* Send an email if the COS uploaded failed. */
            SNDSMTPEMM RCP(('youremail@yourdomain.com')) +
                SUBJECT(&EMAILSUBJ) NOTE(&ERRMSG)
        ENDDO
    ENDDO
ENDPGM
