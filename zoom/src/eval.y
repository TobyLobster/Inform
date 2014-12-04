/*
 *  A Z-Machine
 *  Copyright (C) 2000 Andrew Hunter
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

/*
 * Inform expression evaluator
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../config.h"
#include "zmachine.h"
#include "debug.h"

#define	yymaxdepth debug_eval_maxdepth
#define	yyparse	debug_eval_parse
#define	yylex	debug_eval_lex
#define	yyerror	debug_eval_error
#define	yylval	debug_eval_lval
#define	yychar	debug_eval_char
#define	yydebug	debug_eval_debug
#define	yypact	debug_eval_pact
#define	yyr1	debug_eval_r1
#define	yyr2	debug_eval_r2
#define	yydef	debug_eval_def
#define	yychk	debug_eval_chk
#define	yypgo	debug_eval_pgo
#define	yyact	debug_eval_act
#define	yyexca	debug_eval_exca
#define yyerrflag debug_eval_errflag
#define yynerrs	debug_eval_nerrs
#define	yyps	debug_eval_ps
#define	yypv	debug_eval_pv
#define	yys	debug_eval_s
#define	yy_yys	debug_eval_yys
#define	yystate	debug_eval_state
#define	yytmp	debug_eval_tmp
#define	yyv	debug_eval_v
#define	yy_yyv	debug_eval_yyv
#define	yyval	debug_eval_val
#define	yylloc	debug_eval_lloc
#define yyreds	debug_eval_reds
#define yytoks	debug_eval_toks
#define yylhs	debug_eval_yylhs
#define yylen	debug_eval_yylen
#define yydefred debug_eval_yydefred
#define yydgoto	debug_eval_yydgoto
#define yysindex debug_eval_yysindex
#define yyrindex debug_eval_yyrindex
#define yygindex debug_eval_yygindex
#define yytable	 debug_eval_yytable
#define yycheck	 debug_eval_yycheck
#define yyname   debug_eval_yyname
#define yyrule   debug_eval_yyrule

int debug_eval_result = 0;
char* debug_eval_type = NULL;
const char* debug_error;
extern debug_routine* debug_expr_routine;

#define UnpackR(x) (machine.packtype==packed_v4?4*((ZUWord)x):(machine.packtype==packed_v8?8*((ZUWord)x):4*((ZUWord)x)+machine.routine_offset))
#define UnpackS(x) (machine.packtype==packed_v4?4*((ZUWord)x):(machine.packtype==packed_v8?8*((ZUWord)x):4*((ZUWord)x)+machine.string_offset))
#define Obj4(x) (((GetWord(machine.header, ZH_objs))) + 126 + ((((ZUWord)x)-1)*14))
#define parent_4  6
#define sibling_4 8
#define child_4   10
#define GetParent4(x) (((x)[parent_4]<<8)|(x)[parent_4+1])
#define GetSibling4(x) (((x)[sibling_4]<<8)|(x)[sibling_4+1])
#define GetChild4(x) (((x)[child_4]<<8)|(x)[child_4+1])
#define GetPropAddr4(x) (((x)[12]<<8)|(x)[13])

struct propinfo
{
  int datasize;
  int number;
  int header;
};

static inline struct propinfo* get_object_propinfo_4(ZByte* prop)
{
  static struct propinfo pinfo;
  
  if (prop[0]&0x80)
    {
      pinfo.number   = prop[0]&0x3f;
      pinfo.datasize = prop[1]&0x3f;
      pinfo.header = 2;

      if (pinfo.datasize == 0)
	pinfo.datasize = 64;
    }
  else
    {
      pinfo.number   = prop[0]&0x3f;
      pinfo.datasize = (prop[0]&0x40)?2:1;
      pinfo.header = 1;
    }

  return &pinfo;
}

static int prop_addr(int object, int prop)
{
  int obj;

  obj = Obj4(object);
  if (obj > 0xffff ||
      obj > machine.story_length)
    {
      debug_error = "Invalid object";
      return 0;
    }

  if (prop < 64)
    {
      int prop_addr;
      struct propinfo* pinfo;

      prop_addr = GetPropAddr4(machine.memory + obj);
      prop_addr += ReadByte(prop_addr)*2+1;
      if (prop_addr > 0xffff ||
          prop_addr > machine.story_length)
	{
	  debug_error = "Invalid object";
	  return 0;
	}
      
      do
        {
	  pinfo = get_object_propinfo_4(Address(prop_addr));

	  if (pinfo->number == prop)
	    {
	      return prop_addr + pinfo->header;
	    }

	  prop_addr += pinfo->datasize + pinfo->header;
	}
      while (pinfo->number != 0);

      return 0;
    }
  else
    {
      ZDWord table_prop;
      int table_ptr;

      table_prop = prop_addr(object, 3);

      if (table_prop == 0)
        return 0;

      table_ptr  = (machine.memory[table_prop]<<8)|
        machine.memory[table_prop+1];

      if (table_ptr == 0)
        return 0;

      while (machine.memory[table_ptr] != 0 ||
             machine.memory[table_ptr+1] != 0)
        {
	  int num;

	  num = (machine.memory[table_ptr]<<8) |
	    machine.memory[table_ptr+1];

	  num &= ~ 0x8000;
	  
	  if (num == prop)
	    {
	      return table_ptr + 3;
	    }

	  table_ptr += 3 + machine.memory[table_ptr+2];
	}

      return 0;
    }
}
%}

%union{
  char* str;
  ZWord number;
}

%token IDENTIFIER
%token NUMBER

%token PROPADDR  // .&
%token PROPLEN   // .#
%token BYTEARRAY // ->
%token WORDARRAY // -->

%left '+' '-'
%left '*' '/' '%' '&' '|' '~'
%left BYTEARRAY WORDARRAY
%left UNARYMINUS
%left PROPADDR PROPLEN
%left '.'

%type<number> Expression NUMBER
%type<str>    IDENTIFIER

%%

Eval:		  Expression
		    {
		      debug_eval_result = $1;
		      debug_eval_type = NULL;
		    }
		| '(' IDENTIFIER ')' Expression
		    {
		      debug_eval_result = $4;
		      debug_eval_type   = $2;
		    }
		;

Expression:	  IDENTIFIER
		  {
		    $$ = debug_symbol_value($1, debug_expr_routine);
		    free($1);
		  }
		| NUMBER
		  {
		    $$ = $1;
		  }

		| '(' Expression ')'
		  {
		    $$ = $2;
		  }

		| Expression '+' Expression
		  {
		    $$ = $1 + $3;
		  }
		| Expression '-' Expression
		  {
		    $$ = $1 - $3;
		  }
		| Expression '*' Expression
		  {
		    $$ = $1 * $3;
		  }
		| Expression '/' Expression
		  {
		    $$ = $1 / $3;
		  }

		| '-' Expression %prec UNARYMINUS
		  {
		    $$ = -$2;
		  }

		| Expression '&' Expression
		  {
		    $$ = $1 & $3;
		  }
		| Expression '|' Expression
		  {
		    $$ = $1 | $3;
		  }
		| '~' Expression
		  {
		    $$ = ~$2;
		  }

		| Expression '.' Expression
		  {
		    int adr;

		    $$ = 0;
		    adr = prop_addr($1, $3);

		    if (adr == 0)
		      {
		        if ($3 >= 64)
		          debug_error = "Property not found";
			
			adr = GetWord(machine.header, ZH_objs) + 2*$3 - 2;
			$$ = (machine.memory[adr]<<8)|machine.memory[adr+1];
		      }
		    else
		      {
		        int len;

		        if ($3 < 64)
			  {
			    len = machine.memory[adr-1];
			    if (len&0x80)
			      {
			        len = $$&0x3f;
			      }
			    else
			      {
			        len = (len&0x40)?2:1;
			      }
			    if (len == 0)
			      len = 64;
			  }
			else
			  {
			    len = machine.memory[adr-1];
			  }

			if (len == 1)
			  $$ = machine.memory[adr];
			else if (len == 2)
			  $$ = (machine.memory[adr]<<8)|machine.memory[adr+1];
			else
			  debug_error = "Property is not the right length for '.'";
		      }
		  }
		| Expression PROPADDR Expression
		  {
		    $$ = prop_addr($1, $3);
		    if ($$ == 0)
		      debug_error = "Property not found";
		  }
		| Expression PROPLEN Expression
		  {
		    int adr;

		    $$ = 0;
		    adr = prop_addr($1, $3);
		    if (adr == 0)
		      debug_error = "Property not found";
		    else
		      {
		        if ($3 < 64)
			  {
			    $$ = machine.memory[adr-1];
			    if ($$&0x80)
			      {
			        $$ = $$&0x3f;
			      }
			    else
			      {
			        $$ = ($$&0x40)?2:1;
			      }
			    if ($$ == 0)
			      $$ = 64;
			  }
			else
			  {
			    $$ = machine.memory[adr-1];
			  }
		      }
		  }
		
		| Expression BYTEARRAY Expression
		  {
		    int addr;

		    addr = (ZUWord)$1 + (ZUWord)$3;
		    if (addr > 0xffff ||
		        addr > machine.story_length)
		      debug_error = "Address outside Z-Machine memory space";
		    else
		      $$ = machine.memory[addr];
		  }
		| Expression WORDARRAY Expression
		  {
		    int addr;

		    addr = (ZUWord)$1 + ((ZUWord)$3*2) + 1;
		    if (addr > 0xffff ||
		        addr > machine.story_length)
		      debug_error = "Address outside Z-Machine memory space";
		    else
		      $$ = (machine.memory[addr-1]<<8) |
		        machine.memory[addr];
		  }
		;

%%
