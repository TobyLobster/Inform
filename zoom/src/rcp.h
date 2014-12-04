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
 * Deal with the .zoomrc file
 */

#define	yymaxdepth rc_maxdepth
#define	yyparse rc_parse
#define	yylex rc_lex
#define	yyerror rc_error
#define	yylval rc_lval
#define	yychar rc_char
#define	yydebug rc_debug
#define	yypact rc_pact
#define	yyr1 rc_r1
#define	yyr2 rc_r2
#define	yydef rc_def
#define	yychk rc_chk
#define	yypgo rc_pgo
#define	yyact rc_act
#define	yyexca rc_exca
#define yyerrflag rc_errflag
#define yynerrs rc_nerrs
#define	yyps rc_ps
#define	yypv rc_pv
#define	yys rc_s
#define	yy_yys rc_yys
#define	yystate rc_state
#define	yytmp rc_tmp
#define	yyv rc_v
#define	yy_yyv rc_yyv
#define	yyval rc_val
#define	yylloc rc_lloc
#define yyreds rc_reds
#define yytoks rc_toks
#define yylhs rc_yylhs
#define yylen rc_yylen
#define yydefred rc_yydefred
#define yydgoto rc_yydgoto
#define yysindex rc_yysindex
#define yyrindex rc_yyrindex
#define yygindex rc_yygindex
#define yytable	 rc_yytable
#define yycheck	 rc_yycheck
#define yyname   rc_yyname
#define yyrule   rc_yyrule

#define yyss        rc_yyss
#define yysslim     rc_yysslim
#define yyssp       rc_yyssp
#define yystacksize rc_yystacksize
#define yyvs        rc_yyvs
#define yyvsp       rc_yyvsp

typedef struct stringlist
{
  char* string;
  struct stringlist* next;
} stringlist;
