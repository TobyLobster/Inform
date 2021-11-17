%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../config.h"
#include "zmachine.h"
#include "rc.h"
#include "rcp.h"
#include "hash.h"

#define YYERROR_VERBOSE 1

extern int _rc_line;
extern hash rc_hash;

extern void rc_error(char*);
extern int  rc_lex(void);

int rc_merging = 0;

#define EMPTY_GAME(x) x.fg_col = -1; x.bg_col = -1; x.interpreter = -1; x.revision = -1; x.name = NULL; x.fonts = NULL; x.n_fonts = -1; x.colours = NULL; x.n_colours = -1; x.gamedir = x.savedir = x.sounds = x.graphics = NULL; x.xsize = x.ysize = -1; x.antialias = -1;

static inline rc_game merge_games(const rc_game* a, const rc_game* b)
{
  rc_game r;

  if (a->fg_col == -1)
	r.fg_col = b->fg_col;
  else
    r.fg_col = a->fg_col;
  if (a->bg_col == -1)
	r.bg_col = b->bg_col;
  else
    r.bg_col = a->bg_col;

  if (a->interpreter == -1)
    r.interpreter = b->interpreter;
  else
    r.interpreter = a->interpreter;

  if (a->antialias == -1)
    r.antialias = b->antialias;
  else
    r.antialias = a->antialias;

  if (a->revision == -1)
    r.revision = b->revision;
  else
    r.revision = a->revision;

  if (a->name == NULL)
    r.name = b->name;
  else
    r.name = a->name;

  if (a->fonts == NULL)
    {
      r.fonts = b->fonts;
      r.n_fonts = b->n_fonts;
    }
  else if (b->fonts == NULL)
    {
      r.fonts = a->fonts;
      r.n_fonts = a->n_fonts;
    }
  else
    {
      int x;

      r.n_fonts = a->n_fonts + b->n_fonts;
      r.fonts = malloc(r.n_fonts*sizeof(rc_font));
      
      for (x=0; x<a->n_fonts; x++)
      	r.fonts[x] = a->fonts[x];
      for (x=0; x<b->n_fonts; x++)
        r.fonts[x+a->n_fonts] = b->fonts[x];

      free(a->fonts);
      free(b->fonts);
    }

  if (a->colours == NULL)
    {
      r.colours   = b->colours;
      r.n_colours = b->n_colours;
    }
  else if (b->colours == NULL)
    {
      r.colours   = a->colours;
      r.n_colours = a->n_colours;      
    }
  else
    rc_error("Can only have one set of colours per block");

  if (a->gamedir == NULL)
    r.gamedir = b->gamedir;
  else
    r.gamedir = a->gamedir;

  if (a->savedir == NULL)
    r.savedir = b->savedir;
  else
    r.savedir = a->savedir;

  if (a->sounds == NULL)
    r.sounds = b->sounds;
  else
    r.sounds = a->sounds;
  if (a->graphics == NULL)
    r.graphics = b->graphics;
  else
    r.graphics = a->graphics;

  if (a->xsize == -1)
    r.xsize = b->xsize;
  else
    r.xsize = a->xsize;
  if (a->ysize == -1)
    r.ysize = b->ysize;
  else
    r.ysize = a->ysize;
  
  return r;
}
%}

%union {
  char*       str;
  int         num;
  char        chr;

  rc_font     font;
  rc_game     game;
  rc_colour   col;
  stringlist* slist;
}

%token DEFAULT
%token INTERPRETER
%token REVISION
%token FONT
%token COLOURS
%token GAME
%token ROMAN
%token BOLD
%token ITALIC
%token FIXED
%token SYMBOLIC
%token GAMEDIR
%token SAVEDIR
%token SOUNDS
%token GRAPHICS
%token SIZE
%token ANTIALIAS
%token YES
%token NO

%token <str> GAMEID
%token <num> NUMBER
%token <str> STRING
%token <chr> CHARACTER

%type <col>   ColourDefn
%type <game>  ColourList
%type <slist> RevisionList
%type <slist> GoodRevisionList
%type <num>   FontQual
%type <num>   FontDefn
%type <font>  FontType
%type <game>  RCOption
%type <game>  RCOptionList
%type <game>  RCBlock
%type <num>   YesOrNo

%{
static int check_collision(char* ourid, char* name)
{
  rc_game* game;

  game = hash_get(rc_hash, ourid, (int)strlen(ourid));
  if (game != NULL && strcmp(name, game->name) != 0)
    {
      if (!rc_merging)
	zmachine_info("Namespace collision: identifier '%s' (for game '%s') already used for game '%s'", ourid, name, game->name);
      return 0;
    }

  return 1;
}
%}

%%

RCFile:		  RCDefn
		| RCFile RCDefn
		;

RCDefn:		  DEFAULT STRING RCBlock
		    {
		      rc_game* game;

		      if (!rc_merging)
			{
			  game = malloc(sizeof(rc_game));
			  *game = $3;
			  game->name = $2;
			  hash_store(rc_hash,
				     (unsigned char*)"default",
				     7,
				     game);
			}
		    }
		| DEFAULT RCBlock
		    {
		      rc_game* game;

		      if (!rc_merging)
			{
			  game = malloc(sizeof(rc_game));
			  *game = $2;
			  game->name = "%s";
			  hash_store(rc_hash,
				     (unsigned char*)"default",
				     7,
				     game);
			}

		    }
		| GAME STRING RevisionList
		    {
		      if ($3 != NULL)
		        {
		          rc_game* game;
		          stringlist* next;

		          game = malloc(sizeof(rc_game));
		          EMPTY_GAME((*game));
		          game->name = $2;

		          next = $3;
		          while (next != NULL)
		            {
			      if (check_collision(next->string, game->name))
			        {
			          hash_store(rc_hash,
					     (unsigned char*)next->string,
					     (int)strlen(next->string),
					     game);
			        }
			      next = next->next;
	                    }
			}
		      else
		        {
		          zmachine_info(".zoomrc has erroneous entry for game '%s' (line %i)", $2, _rc_line);
			}
		    }
		| GAME STRING RevisionList RCBlock
		    {
		      if ($3 != NULL)
		        {
		          rc_game* game;
		          stringlist* next;

		          game = malloc(sizeof(rc_game));
		          *game = $4;
		          game->name = $2;

		          next = $3;
		          while (next != NULL)
		            {
			      if (check_collision(next->string, game->name))
			        {
			          hash_store(rc_hash,
					     (unsigned char*)next->string,
					     (int)strlen(next->string),
					     game);
			        }
			      next = next->next;
	                    }
		        }
		      else
		        {
		          zmachine_info(".zoomrc has erroneous entry for game '%s' (line %i)", $2, _rc_line);
			}
		    }
		;

RCBlock:	  '{' RCOptionList '}'
		    {
		      $$ = $2;
		    }
                | '{' '}'
                    {
		      EMPTY_GAME($$);
                    }
		| '{' ErrorList
		    {
		      yyerrok;
		      zmachine_info(".zoomrc options block ending at line %i makes no sense", _rc_line);
		      EMPTY_GAME($$);
		    }
		| '{' RCOptionList ErrorList
		    {
		      yyerrok;
		      $$ = $2;

		      zmachine_info(".zoomrc options block at line %i has syntax errors", _rc_line);
		    }
		;

RCOptionList:	  RCOption
		| RCOptionList RCOption
		    {
		      $$ = merge_games(&$1, &$2);
		    }
		;

YesOrNo:	  YES { $$ = 1; }
		| NO  { $$ = 0; }
		;

RCOption:	  INTERPRETER NUMBER
		    {
		      EMPTY_GAME($$);
		      $$.interpreter = $2;
		    }
                | ANTIALIAS YesOrNo
		    {
		      EMPTY_GAME($$);
		      $$.antialias = $2;
		    }
		| REVISION CHARACTER
		    {
		      EMPTY_GAME($$);
		      $$.revision = $2;
		    }
		| FONT NUMBER STRING FontType
		    {
		      EMPTY_GAME($$);
		      $$.fonts = malloc(sizeof(rc_font));
		      $$.n_fonts = 1;
		      $$.fonts[0] = $4;

		      $$.fonts[0].name = $3;
		      $$.fonts[0].num  = $2;
		    }
		| COLOURS ColourList
		    {
		      $$ = $2;
		    }
                | GAMEDIR STRING
		    {
		      EMPTY_GAME($$);
		      $$.gamedir = $2;
		    }
                | SAVEDIR STRING
		    {
		      EMPTY_GAME($$);
		      $$.savedir = $2;
		    }
		| SOUNDS STRING
		    {
		      EMPTY_GAME($$);
		      $$.sounds = $2;
		    }
		| GRAPHICS STRING
		    {
		      EMPTY_GAME($$);
		      $$.graphics = $2;
		    }
		| SIZE NUMBER ',' NUMBER
		    {
		      EMPTY_GAME($$);
		      $$.xsize = $2;
		      $$.ysize = $4;
		    }
		;

FontType:	  FontDefn
		    {
		      $$.name = NULL;
		      $$.attributes[0] = $1;
		      $$.n_attr = 1;
		      $$.num = 0;
		    }
		| FontType ',' FontDefn
		    {
		      $$ = $1;
		      $$.n_attr++;
		      $$.attributes[$$.n_attr-1] = $3;
		    }
		;

FontDefn:	  FontQual
		    {
		      $$ = $1;
		    }
		| FontDefn '-' FontQual
		    {
		      $$ = $1|$3;
		    }
		;

FontQual:	  ROMAN    { $$ = 0; }
		| BOLD     { $$ = 1; }
		| ITALIC   { $$ = 2; }
		| FIXED    { $$ = 4; }
                | SYMBOLIC { $$ = 8; }
		;

ColourList:	  ColourDefn
		    {
		      EMPTY_GAME($$);
		      $$.colours = malloc(sizeof(rc_colour));
		      $$.colours[0] = $1;
		      $$.n_colours = 1;
		    }
		| ColourList ',' ColourDefn
		    {
		      $$ = $1;
		      $$.n_colours++;
		      $$.colours = realloc($$.colours, 
				           sizeof(rc_colour)*$$.n_colours);
		      $$.colours[$$.n_colours-1]=$3;
		    }
		;

ColourDefn:	  '(' NUMBER ',' NUMBER ',' NUMBER ')'
		    {
		      $$.r = $2&0xff;
		      $$.g = $4&0xff;
		      $$.b = $6&0xff;
		    }
		;

RevisionList:	  GoodRevisionList
		| BadRevisionList
		    { $$ = NULL; }
		;

BadRevisionList:  ErrorList
		    { yyerrok; }
		;

GoodRevisionList: GAMEID 
		    {
		      $$ = malloc(sizeof(stringlist));
		      $$->next = NULL;
		      $$->string = $1;
		    }
		| RevisionList ',' GAMEID
		    {
		      if ($1 == NULL)
		        {
		          $$ = NULL;
			}
	              else
		        {
		          $$ = malloc(sizeof(stringlist));
		          $$->next = $1;
		          $$->string = $3;
			}
		    }
		;

ErrorList:	  error '}' { yyerrok; }
		;

%%
