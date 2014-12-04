%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "operation.h"

#define YYERROR_VERBOSE

extern int yyline;
extern int codeline; 

oplist zmachine;
extern int  yyerror(char*);
extern int  yylex(void);
%}

%token OPCODE
%token NUMBER
%token STRING
%union {
  int   number;
  char* string;
  enum optype optype;

  operation* op;
  opflags    flags;
}

%token <optype> OPTYPE
%token          VERSION

%token          BRANCH
%token          CANJUMP
%token          STORE
%token          STRINGFLAG
%token          LONG
%token          ARGS
%token          REALLYVAR
%token          ALL

%token <number> NUMBER
%token <string> STRING
%token <string> CODEBLOCK

%type <op>      OpCode
%type <flags>   FlagList
%type <number>  SupportedVersions 
%type <number>  VersionList
%type <number>  Flag
%type <string>  OptionalCode

%%

ZMachine:	  OpCode
		    {
		      if ((zmachine.numops&255)==0)
		        {
			  zmachine.op = realloc(zmachine.op,
			                        sizeof(operation**)*
						  (zmachine.numops+256));
			}
		      zmachine.op[zmachine.numops] = $1;
		      zmachine.numops++;
		    }
		| ZMachine OpCode
		    {
		      if ((zmachine.numops&255)==0)
		        {
			  zmachine.op = realloc(zmachine.op,
			                        sizeof(operation**)*
						  (zmachine.numops+256));
			}
		      zmachine.op[zmachine.numops] = $2;
		      zmachine.numops++;
		    }
		;

OpCode:		  OPCODE STRING OPTYPE ':' NUMBER FlagList VERSION SupportedVersions OptionalCode
		    {
		      $$ = malloc(sizeof(operation));

		      $$->name     = $2;
		      $$->type     = $3;
		      $$->value    = $5;
		      $$->flags    = $6;
		      $$->versions = $8;
		      $$->code     = $9;
		      $$->codeline = codeline;
		    }
		;

OptionalCode:	  /* Empty */
		    { $$ = NULL; }
		| CODEBLOCK
		    {
		      $$ = $1;
		    }
		;

FlagList:	  /* Empty */
		    {
		      $$.isbranch   = $$.isstore = $$.isstring = $$.islong = 
		        $$.canjump  = 0;
		      $$.fixed_args = -1;
		    }
		| FlagList Flag
		    {
		      $$ = $1;
		      
		      switch ($2)
		        {
			case 0:
			  $$.isbranch = 1;
			  break;

			case 1:
			  $$.isstore = 1;
			  break;

			case 2:
			  $$.isstring = 1;
			  break;

			case 3:
			  $$.islong = 1;
			  break;

			case 4:
			  $$.canjump = 1;
			  break;

			case 5:
			  $$.reallyvar = 1;
			  break;

			default:
			  $$.fixed_args = $2-32;
			  break;
			}
		    }
		;

Flag:		  BRANCH
		    {
		      $$ = 0;
		    }
		| STORE
		    {
		      $$ = 1;
		    }
		| STRINGFLAG
		    {
		      $$ = 2;
		    }
		| LONG
		    {
		      $$ = 3;
		    }
		| CANJUMP
		    {
		      $$ = 4;
		    }
		| REALLYVAR
		    {
		      $$ = 5;
		    }
		| ARGS ':' NUMBER
		    {
		      $$ = 32+$3;
		    }
		;

SupportedVersions:
		  ALL
		    {
		      $$ = -1;
		    }
		| VersionList
		    {
		      $$ = $1;
		    }
		;

VersionList:	  NUMBER
		    {
		      $$ = 1<<$1;
		    }
		| VersionList ',' NUMBER
		    {
		      $$ = $1 | (1<<$3);
		    }
		;

%%

int yyerror(char *s)
{
  printf("%s (line %i)\n", s, yyline);
  abort();
}
