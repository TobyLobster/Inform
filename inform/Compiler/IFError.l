%{
//
//  IFError.l
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
    
#include "IFError.h"

int IFLexLastProgress;
char* IFLexLastProgressString;
char* IFLexEndTextString;

struct errorValue {
    IFLex style;
    int line;
    char* file;
};

static struct errorValue currentError;
%}

%option noyywrap
%option nounput
%option noinput

%x MPW_1
%x ERRORMESSAGE
%%

Inform\ 7 { return IFLexCompilerVersion; }
Inform\ 6 { return IFLexCompilerVersion; }

Copy\ blorb\ to:\ \[\[.*\]\]\n {
	// Blorb copy request
	int copyLen = (int)strlen(yytext)-19;
	char* copyTo = calloc(copyLen, 1);
	strncpy(copyTo, yytext + 17, copyLen);
	copyTo[copyLen-1] = 0;
						  
	IFErrorCopyBlorbTo(copyTo);
	free(copyTo);
													
	return IFLexCompilerMessage;
}

\+\+\ ([0-9]+)\%\n {
	// A progress line
	IFLexLastProgress = atoi(yytext+3);
	IFLexLastProgressString = NULL;
	
	return IFLexProgress;
}

\+\+\ ([0-9]+)\%\ \(.*\)\n {
	// A progress line with status text
	IFLexLastProgress = atoi(yytext+3);
	IFLexLastProgressString = yytext+3;
	
	while (IFLexLastProgressString[0] != '(') IFLexLastProgressString++;
	IFLexLastProgressString++;

	return IFLexProgress;
}

\+\+\ Ended:\ .*\n  {
	// An end line with text
	IFLexEndTextString = yytext+10;
	return IFLexEndText;
}

File\ \".*\";\ Line\  {
    // Beginning of an MPW-style error message
    currentError.file = calloc(strlen(yytext)-13, 1);
    strncpy(currentError.file, yytext + 6, strlen(yytext)-14);

    BEGIN(MPW_1);
}
<MPW_1>[0-9]+\t#\  {
    // MPW-style line number
    currentError.line = atoi(yytext);
    BEGIN(ERRORMESSAGE);
}
<MPW_1>. {
    // Not MPW after all, something else thoroughly weird
    free(currentError.file); currentError.file = NULL;
    BEGIN(0);
    return -1;
}

<ERRORMESSAGE>\w*\*\*\*\ Compiler\ error:.*\n {
    char* comerr  = strstr(yytext, "Compiler error:");
    char* message = calloc(strlen(comerr), 1);
    strncpy(message, comerr + 16, strlen(comerr)-17);
    
    IFErrorAddError(currentError.file,
                    currentError.line,
                    IFLexCompilerFatalError,
                    message);

    if (currentError.file) free(currentError.file);
    free(message);
                           
    BEGIN(0);
    return IFLexCompilerFatalError;
}
<ERRORMESSAGE>\w*Fatal\ error:.*\n {
    char* comerr  = strstr(yytext, "Fatal error:");
    char* message = calloc(strlen(comerr), 1);
    strncpy(message, comerr + 13, strlen(comerr)-14);

    IFErrorAddError(currentError.file,
                    currentError.line,
                    IFLexCompilerFatalError,
                    message);

    if (currentError.file) free(currentError.file);
    free(message);

    BEGIN(0);
    return IFLexCompilerFatalError;
}
<ERRORMESSAGE>\w*Error:.*\n {
    char* comerr  = strstr(yytext, "Error:");
    char* message = calloc(strlen(comerr), 1);
    strncpy(message, comerr + 8, strlen(comerr)-9);

    IFErrorAddError(currentError.file,
                    currentError.line,
                    IFLexCompilerError,
                    message);

    if (currentError.file) free(currentError.file);
    free(message);

    BEGIN(0);
    return IFLexCompilerError;
}
<ERRORMESSAGE>\w*Warning:.*\n {
    char* comerr  = strstr(yytext, "Warning:");
    char* message = calloc(strlen(comerr), 1);
    strncpy(message, comerr + 10, strlen(comerr)-11);

    IFErrorAddError(currentError.file,
                    currentError.line,
                    IFLexCompilerWarning,
                    message);

    if (currentError.file) free(currentError.file);
    free(message);

    BEGIN(0);
    return IFLexCompilerWarning;
}
<ERRORMESSAGE>.*\n {
    char* comerr  = yytext;
    char* message = calloc(strlen(comerr), 1);
    strncpy(message, comerr, strlen(comerr)-1);

    IFErrorAddError(currentError.file,
                    currentError.line,
                    IFLexCompilerMessage,
                    message);

    if (currentError.file) free(currentError.file);
    free(message);

    BEGIN(0);
    return IFLexCompilerMessage;
}

(\".*\",\ )?line\ [0-9]+\:\ .*\n {
    // RISC OS style error
    return IFLexCompilerError;
}

\>.*\n	{ return IFLexCompilerMessage; }

. { return -1; }

%%

int IFErrorScanString(const char* string) {
    int len = (int)strlen(string);

    yy_delete_buffer(YY_CURRENT_BUFFER);
    
    YY_BUFFER_STATE b;
    char* oldbuf;
    static char *buf = NULL;
    yy_size_t n;
    int i;

    oldbuf = buf;
    
    /* Get memory for full buffer, including space for trailing EOB's. */
    n = len + 2;
    buf = (char *) malloc( n );
    if ( ! buf )
        YY_FATAL_ERROR( "out of dynamic memory in IFErrorScanString" );

    for ( i = 0; i < len; ++i )
        buf[i] = string[i];

    buf[len] = buf[len+1] = YY_END_OF_BUFFER_CHAR;

    b = yy_scan_buffer( buf, n );
    if ( ! b )
        YY_FATAL_ERROR( "bad buffer in IFErrorScanString" );

    if (oldbuf != NULL) {
        free(oldbuf);
    }

    return yylex();
}

