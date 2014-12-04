%{
#include <stdlib.h>
#include <string.h>

#include "rc.h"
#include "rcp.h"
#ifndef APPLE_IS_ARBITRARY
# include "rc_parse.h"
#else
# include "rc_parse.tab.h"
#endif

int _rc_line;
%}

%option noyywrap

%%

#.*\n				_rc_line++;

default				return DEFAULT;
interpreter			return INTERPRETER;
revision			return REVISION;
font				return FONT;
colours				return COLOURS;
game				return GAME;
roman				return ROMAN;
bold				return BOLD;
italic				return ITALIC;
fixed				return FIXED;
symbolic                        return SYMBOLIC;

gamedir                         return GAMEDIR;
savedir				return SAVEDIR;
sounds				return SOUNDS;
graphics			return GRAPHICS;
resources			return GRAPHICS;
blorb   			return GRAPHICS;
size				return SIZE;
antialias                       return ANTIALIAS;

yes				return YES;
no				return NO;

[0-9]{1,3}\.[0-9]{6}		{
				  yylval.str = malloc(strlen(yytext)+1);
				  strcpy(yylval.str, yytext);
				  return GAMEID;
				}
[0-9]{1,3}\.[0-9A-Z]{6}\.[0-9a-fA-F]{4} {
				  yylval.str = malloc(strlen(yytext)+1);
				  strcpy(yylval.str, yytext);
				  return GAMEID;
				}
[0-9]+				{
				  yylval.num = atoi(yytext);
				  return NUMBER;
				}
\"([^"]|(\\\"))*\"		{
				  yylval.str = calloc(strlen(yytext), 1);
				  strncpy(yylval.str, yytext + 1, 
					  strlen(yytext)-2);
				  return STRING;
				}
[A-Z]				{
				  yylval.chr = yytext[0];
				  return CHARACTER;
				}

[ \t]+				/* Yum */
\n				_rc_line++;
.				return (unsigned char) yytext[0];

%%
