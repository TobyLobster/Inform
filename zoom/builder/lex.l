%{
#include <stdlib.h>
#include <string.h>

#include "operation.h"
#ifndef APPLE_IS_ARBITRARY
# include "gram.h"
#else
# include "gram.tab.h"
#endif
	
int yyline;
int codeline;
%}

%option noyywrap

%%

#.*\n				yyline++;

OPCODE				return OPCODE;
VERSION				return VERSION;
STORE				return STORE;
BRANCH				return BRANCH;
CANJUMP				return CANJUMP;
STRING				return STRINGFLAG;
LONG				return LONG;
ARGS				return ARGS;
REALLYVAR			return REALLYVAR;
all				return ALL;

0OP				yylval.optype = zop;   return OPTYPE;
1OP				yylval.optype = unop;  return OPTYPE;
2OP				yylval.optype = binop; return OPTYPE;
VAR				yylval.optype = varop; return OPTYPE;
EXT				yylval.optype = extop; return OPTYPE;

[0-9]+				{
				  int x;
				  int num = 0;

				  for (x=0; yytext[x] != 0; x++)
				    {
				      num*=10;
				      num+=yytext[x]-'0';
				    }
				  yylval.number = num;

				  return NUMBER;
				}
0x[0-9A-Fa-f]+			{
				  int x;
				  int num = 0;

				  for (x=2; yytext[x] != 0; x++)
				    {
				      num*=16;
				      if (yytext[x]>='a' && yytext[x]<='f')
				        {
					  num+=yytext[x]-('a'-10);
					}
				      else if (yytext[x]>='A' &&  yytext[x]<='F')
				        {
					  num+=yytext[x]-('A'-10);
					}
				      else
				        {
					  num+=yytext[x]-'0';
					}
				    }
				  yylval.number = num;

				  return NUMBER;
				}
\"[^"]*\"			{
				  int x;
				  yylval.string = NULL;

				  for (x=1; yytext[x] != '"'; x++)
				    {
				      yylval.string =
				        realloc(yylval.string, x+1);
				      yylval.string[x-1] = yytext[x];
				    }
				  yylval.string[x-1] = 0;

				  return STRING;
				}

"%{"(\n|[^%]|(%[^}]))*"%}"	{
				  int x;
				  yylval.string = NULL;

				  codeline = yyline;

				  for (x=2; 
				       x<(strlen(yytext))-2;
				       x++)
				    {
				      yylval.string =
				        realloc(yylval.string, x+1);
				      yylval.string[x-2] = yytext[x];
				      if (yytext[x] == 10)
				        yyline++;
				    }
				  yylval.string[x-2] = 0;

				  return CODEBLOCK;
				}


[ \t]+				/* Yum! */
\n				yyline++;

.				return yytext[0];

%%
