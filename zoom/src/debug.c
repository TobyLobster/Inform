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
 * The debugger
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "debug.h"
#include "zscii.h"

#include <signal.h>

#define yylval debug_eval_lval
#ifndef APPLE_IS_ARBITRARY
# include "eval.h"
#else
# include "eval.tab.h"
#endif

debug_breakpoint* debug_bplist       = NULL;
int               debug_nbps         = 0;
debug_routine*    debug_expr_routine = NULL;

int*			  debug_expr      = NULL;
int				  debug_expr_pos  = 0;

static debug_breakpoint_handler bp_handler = NULL;

/*
static debug_breakpoint* return_breakpoint;
static ZFrame*			 return_frame;
 */

typedef struct debug_display
{
  int*  expr;
  char* desc;
  ZWord lastvalue;
  int   erm;
} debug_display;

static int            ndisps = 0;
static debug_display* dbdisp = NULL;

static debug_address addr;

/***                           ----// 888 \\----                           ***/

/* The debugger console */

static int stepinto = 0;

/* Action when a breakpoint occurs */
void debug_run_breakpoint(ZDWord pc)
{
  debug_breakpoint* bp;
  static int banner = 0;
  int x;
  ZFrame* frame;

  bp = debug_get_breakpoint(pc);

  if (bp && bp->usage == 1 && bp->funcbp && !stepinto)
    return;

  addr = debug_find_address(pc);
  if (bp && bp->usage == 1 && bp->funcbp && 
      (!stepinto || addr.routine->defn_fl == 0 || addr.routine->defn_fl == 255))
    {
      return;
    }

  /* Clear any temporary breakpoints */
  for (x=0; x<debug_nbps; x++)
    {
      if (debug_bplist[x].temporary > 0)
	{
	  debug_clear_breakpoint(debug_bplist + x);
	  x--;
	}
    }
  
  /* Clear any return breakpoints */
  if (machine.stack.current_frame) {
	  for (frame = machine.stack.current_frame; frame != NULL; frame = frame->last_frame) {
		  frame->break_on_return = 0;
	  }
  }
  
  stepinto = 0;
  
  if (bp_handler != NULL) {
	  /* Run the handler instead of the standard debugging routines */
	  (*bp_handler)(pc);
	  return;
  }
  
  display_sanitise();
  display_printf("=\n");

  /* Print a quick banner if we're just starting up... */
  if (banner == 0)
    {
      banner = 1;
      
      display_printf("= Welcome to Zoom's symbolic debug mode\n");
      display_printf("= %i symbols, %i known routines, in %i files\n", 
		     debug_syms.nsymbols,
		     debug_syms.nroutines,
		     debug_syms.nfiles);
      display_printf("= Type 'h' for help\n=\n");
    }
  
  /* Display the location information */
  display_printf("== ");
  display_set_style(8);
  display_printf("%s\n", debug_address_string(addr, pc, 0));
  display_set_style(0);

  if (addr.line != NULL &&
      addr.line->fl > 0 &&
      addr.line->ln > 0 && 
      addr.line->fl != 255)
    {
      display_printf("== ");
      display_set_style(8);
      if (addr.line->ln-1 > debug_syms.files[addr.line->fl].nlines)
	display_printf("(Line not found)\n");
      else
	display_printf("%s\n", 
		       debug_syms.files[addr.line->fl].line[addr.line->ln-1]);
      display_set_style(0);
    }

  /* Evaluate any display expressions */
  for (x=0; x<ndisps; x++)
    {
      debug_expr = dbdisp[x].expr;
      debug_expr_pos = 0;
      debug_expr_routine = addr.routine;
      debug_error = NULL;
      debug_eval_parse();

      if (debug_error == NULL)
	{
	  if (debug_eval_result != dbdisp[x].lastvalue ||
	      dbdisp[x].erm == 1)
	    {
	      display_printf("==");
	      display_set_colour(1, 7);
	      display_printf("%s=%s\n", dbdisp[x].desc,
			     debug_print_value(debug_eval_result,
					       debug_eval_type));
	      display_set_colour(4, 7);
	    }
	  dbdisp[x].lastvalue = debug_eval_result;
	  dbdisp[x].erm = 0;
	}
      else
	{
	  if (dbdisp[x].erm == 0)
	    {
	      display_printf("==");
	      display_set_colour(1, 7);
	      display_printf("%s=%s\n", dbdisp[x].desc,
			     debug_error);
	      display_set_colour(4, 7);
	    }
	  dbdisp[x].erm = 1;
	}
      
      if (debug_eval_type != NULL)
	free(debug_eval_type);
      debug_eval_type = NULL;
    }
  
  /* Process commands */
  while (1)
    {
      int cline[128];

      cline[0] = 0;
      
      display_printf("= : ");
      display_readline(cline, 128, 0);

      if (cline[0] == 0)
	{
	  cline[0] = 's';
	  cline[1] = 0;
	}

      switch (cline[0])
	{
	case 'h':
	  display_printf("= Commands accepted by the debugger:\n");
	  display_printf("== b<addr> - set breakpoint\n");
	  display_printf("== c - continue execution\n");
	  display_printf("== d<expr> - display an expression after every breakpoint\n");
	  display_printf("== f - finish function\n");
	  display_printf("== h - this message\n");
	  display_printf("== l - list breakpoints\n");
	  display_printf("== n - single step, over functions\n");
	  display_printf("== p<expr> - evaluate expression\n");
	  display_printf("== s - single step, into functions\n");
	  display_printf("== t - stack backtrace\n");
	  display_printf("==\n");
	  display_printf("== Addresses can have one of two forms:\n");
	  display_printf("=== file:line\n");
	  display_printf("=== function\n");
	  display_printf("== Breakpoints will be set on the first line following that specified\n");
	  display_printf("== Expressions are in standard inform syntax (with some restrictions)\n");
	  break;

	case 'c':
	  display_printf("= Continue\n");
	  goto done;

	case 't':
	  {
	    ZFrame* frm;
	    int frmpc;
	    int count;

	    display_printf("= Backtrace\n");

	    frm   = machine.stack.current_frame;
	    frmpc = pc;
	    count = 0;

	    while (frm != NULL)
	      {
		debug_address addr;

		addr = debug_find_address(frmpc);

		display_printf("== %i) ", count);
		display_set_style(8);
		display_printf("%s", debug_address_string(addr, frmpc, 1));
		display_set_style(0);
		display_printf("\n");

		frmpc = frm->ret;
		frm = frm->last_frame;
		count++;
	      }
	  }
	  break;

	case 'd':
	  debug_expr_routine = addr.routine;
	  debug_expr = cline + 1;
	  debug_expr_pos = 0;
	  debug_error = NULL;
	  debug_eval_parse();
	  if (debug_error == NULL)
	    {
	      int len;
	      char* disp;

	      for (len=0; debug_expr[len] != 0; len++);
	      
	      disp = malloc(sizeof(char)*(len+1));
	      for (len=0; debug_expr[len] != 0; len++)
		disp[len] = debug_expr[len];
	      disp[len] = 0;

	      dbdisp = realloc(dbdisp, sizeof(debug_display)*(ndisps+1));
	      dbdisp[ndisps].desc = disp;
	      dbdisp[ndisps].expr = malloc(sizeof(int)*(len+1));
	      
	      for (len=0; debug_expr[len] != 0; len++)
		dbdisp[ndisps].expr[len] = debug_expr[len];
	      dbdisp[ndisps].expr[len] = 0;
	      dbdisp[ndisps].lastvalue = debug_eval_result;
	      dbdisp[ndisps].erm = 0;

	      ndisps++;

	      display_printf("= Display: %s=%s\n",
			     disp,
			     debug_print_value(debug_eval_result,
					       debug_eval_type));
	    }
	  else
	    {
	      display_printf("=? %s\n", debug_error);
	    }

	  if (debug_eval_type != NULL)
	    free(debug_eval_type);
	  debug_eval_type = NULL;
	  break;

	case 'p':
	  debug_expr_routine = addr.routine;
	  debug_expr = cline + 1;
	  debug_expr_pos = 0;
	  debug_error = NULL;
	  debug_eval_parse();
	  if (debug_error == NULL)
	    {
	      display_printf("= Evaluate: %s\n", 
			     debug_print_value(debug_eval_result,
					       debug_eval_type));
	    }
	  else
	    display_printf("=? Evaluate: %s\n", debug_error);

	  if (debug_eval_type != NULL)
	    free(debug_eval_type);
	  debug_eval_type = NULL;
	  break;

	case 'l':
	  {
	    int x, num;

	    num = 0;

	    display_printf("= User breakpoints:\n");
	    for (x=0; x<debug_nbps; x++)
	      {
		if (debug_bplist[x].usage > (debug_bplist[x].temporary + debug_bplist[x].funcbp))
		  {
		    debug_address bpaddr;

		    bpaddr = debug_find_address(debug_bplist[x].address);
		    num++;
		    display_printf("== %i) %s\n", num, 
				   debug_address_string(bpaddr,
							debug_bplist[x].address,
							1));
		  }
	      }
	  }
	  break;

	case 'b':
	  {
	    char* loc;
	    int x, y;
	    int addr;
	    
	    for (x=1; cline[x] != 0 && cline[x] == ' '; x++);
	    for (y=x; cline[y] != 0; y++);

	    loc = malloc(sizeof(char)*(y-x+1));
	    for (y=x; cline[y] != 0; y++)
	      {
		loc[y-x] = cline[y];
	      }
	    loc[y-x] = 0;

	    addr = debug_find_named_address(loc);

	    if (addr != -1)
	      {
		debug_breakpoint* obp;
		debug_address where;

		where = debug_find_address(addr);

		obp = debug_get_breakpoint(addr);
		if (obp != NULL &&
		    obp->usage > (obp->temporary + obp->funcbp))
		  {
		    display_printf("=? Breakpoint already set at %s\n",
				   debug_address_string(where, addr, 0));
		  }
		else
		  {
		    debug_set_breakpoint(addr, 0, 0);
		    display_printf("= Breakpoint set at %s\n",
				   debug_address_string(where, addr, 0));
		  }
	      }
	    else
	      {
		display_printf("=? Location not found\n");
	      }

	    free(loc);
	  }
	  break;

	case 's':
	case 'n':
	case 'f':
	  {
	    int ln;

	    ln = addr.line_no;
	    if (ln != -1)
	      ln++;
	    if (ln >= addr.routine->nlines)
	      ln = -1;

	    if (cline[0] == 'n')
	      display_printf("= Next\n");
	    else if (cline[0] == 's')
	      {
		display_printf("= Step\n");
		stepinto = 1;
	      }
	    else if (cline[0] == 'f')
	      {
		display_printf("= Finish\n");
	      }
	  
	    /* Set a breakpoint on each line... */
	    if (cline[0] != 'f')
	      {
		for (ln = 0; ln < addr.routine->nlines; ln++)
		  {
		    debug_set_breakpoint(addr.routine->line[ln].address, 1, 0);
		  }
	      }

	    /* Set a breakpoint on the return location of this function */
	    if (machine.stack.current_frame != NULL)
	      {
		debug_set_breakpoint(machine.stack.current_frame->ret, 1, 0);
	      }

	    goto done;
	  }

	default:
	  display_printf("=? Type 'h' for help\n");
	}
    }

 done:
  display_desanitise();
}

/***                           ----// 888 \\----                           ***/

/* Breakpoints */

int debug_set_breakpoint(int address,
			 int temporary,
			 int funcbp)
{
  debug_breakpoint* bp;
  int pos;

  bp = debug_get_breakpoint(address);
  if (bp != NULL)
    {
      bp->usage++;
      bp->temporary += temporary;
      return 1;
    }

  if (machine.memory[address] == 0xbc)
    return 0; /* Breakpoint already set */
  
#ifdef DEBUG
  printf_debug("Setting BP @ %04x\n", address);
#endif
  
  pos = 0;
  
  /* Find the breakpoint we should insert this new one before */
  while (pos < debug_nbps && debug_bplist[pos].address < address) {
    pos++;
  }

  /* Add a new breakpoint */
  debug_bplist = realloc(debug_bplist,
			 sizeof(debug_breakpoint)*(debug_nbps+1));
  
  if (pos < debug_nbps) {
    /* Move the breakpoints up */
    memmove(debug_bplist + pos + 1, debug_bplist + pos,
	    (debug_nbps-pos)*sizeof(debug_breakpoint));
  }

  /* Store the actual breakpoint */
  debug_bplist[pos].address   = address;
  debug_bplist[pos].original  = machine.memory[address];
  debug_bplist[pos].usage     = 1;
  debug_bplist[pos].temporary = temporary;
  debug_bplist[pos].funcbp    = funcbp;

  /* Add a breakpoint instruction (we use status_nop, as it's just one byte) */
  machine.memory[address] = 0xbc; /* status_nop, our breakpoint */

  debug_nbps++;
  
  return 1;
}

debug_breakpoint* debug_get_breakpoint(int address)
{
  int top, middle, bottom;
  
  /* Binary search for the breakpoint (they are stored sorted by address) */
  top = debug_nbps-1;
  bottom = 0;
  
  while (top >= bottom) {
    middle = (top + bottom) >> 1;
    
    if (debug_bplist[middle].address > address) {
      /* Need to search the lower half */
      top = middle-1;
    } else if (debug_bplist[middle].address < address) {
      /* Need to search the upper half */
      bottom = middle + 1;
    } else {
      /* Just right */
      return debug_bplist + middle;
    }
  }
  
  /*
  int x;

  for (x=0; x<debug_nbps; x++)
    {
      if (debug_bplist[x].address == address)
	return debug_bplist + x;
    }
   */

  return NULL;
}

int debug_clear_breakpoint(debug_breakpoint* bp)
{
  intptr_t x;

  x = bp - debug_bplist;
  if (x < 0 || x >= debug_nbps)
    return 0;

  bp->usage--;
  if (bp->temporary > 0)
    bp->temporary--;

  if (bp->usage <= 0)
    {
      machine.memory[bp->address] = bp->original;
      debug_nbps--;
      memmove(debug_bplist + x, debug_bplist + x + 1,
	      sizeof(debug_breakpoint)*(debug_nbps-x));
      return 2;
    }

  return 1;
}

/***                           ----// 888 \\----                           ***/

/* Debug file */

debug_symbols debug_syms = { 
  0, NULL, NULL, NULL, NULL, 0, NULL, 0,
  0
};

static void debug_add_symbol(char* name,
			     debug_symbol* sym)
{
  int x;
  char* storename;

  storename = malloc(sizeof(char)*(strlen(name)+1));

  for (x=0; x<strlen(name); x++)
    {
      storename[x] = name[x];
      if (storename[x] >= 'A' && storename[x] <= 'Z')
	storename[x] += 32;
    }
  storename[x] = 0;

  if (hash_get(debug_syms.symbol, (unsigned char*)storename, (int)strlen(name)) != NULL)
    {
      display_printf("=? Symbol space clash - %s\n", name);
    }
  else
    debug_syms.nsymbols++;
  hash_store_happy(debug_syms.symbol,
		   (unsigned char*)storename,
		   (int)strlen(name),
		   sym);
  
  sym->next = debug_syms.first_symbol;
  debug_syms.first_symbol = sym;

  free(storename);
}

#ifdef REMOTE_BREAKPOINT
static void debug_sigusr1(int sig) {
	machine.force_breakpoint = 1;
}
#endif

void debug_load_symbols(char* filename,
			char* pathname)
{
  ZFile* file;
  ZByte* db_file;
  int size;
  int pos;

  int done;
  
  int x;
  
  debug_routine* this_routine = NULL;
  debug_symbol* sym;
  
#ifdef REMOTE_BREAKPOINT
  /* SIGUSR1 indicates that we should break ASAP */
  struct sigaction oldact;
	  
  sigaction(SIGUSR1, NULL, &oldact);
  
  oldact.sa_flags |= SA_RESTART;
  oldact.sa_flags &= ~(SA_NODEFER|SA_SIGINFO);
  oldact.sa_handler = debug_sigusr1;
  
  sigaction(SIGUSR1, &oldact, NULL);
#endif
				
  size = get_file_size(filename);
  file = open_file(filename);

  if (file == NULL)
    {
      display_printf("=! unable to open file '%s'\n", filename);
      return;
    }

  db_file = read_block(file, 0, size);

  close_file(file);

  if (db_file == NULL)
    return;

  display_printf("= loading symbols from '%s'...\n", filename);

  if (db_file[0] != 0xde || db_file[1] != 0xbf)
    {
      display_printf("=! Bad debug file\n");
      free(db_file);
      return;
    }
  
  debug_syms.largest_object = 0;

  pos = 6;

  done = 0;

  if (debug_syms.symbol == NULL)
    debug_syms.symbol = hash_create();
  if (debug_syms.file == NULL)
    debug_syms.file = hash_create();

  sym = malloc(sizeof(debug_symbol));
  sym->type = dbg_global;
  sym->data.global.name = "self";
  sym->data.global.number = 251-16;
  debug_add_symbol(sym->data.global.name, sym);

  sym = malloc(sizeof(debug_symbol));
  sym->type = dbg_global;
  sym->data.global.name = "sender";
  sym->data.global.number = 250-16;
  debug_add_symbol(sym->data.global.name, sym);

  while (pos < size && !done)
    {
      switch (db_file[pos])
	{
	case DEBUG_EOF_DBR:
	  done = 1;
	  break;

	case DEBUG_FILE_DBR:
	  {
	    debug_file* fl;
	    ZFile*      fl_load;
	    ZDWord      fl_len;
	     
	    char* fn;

	    fl = malloc(sizeof(debug_file));

	    fl->number = db_file[pos+1];
	    fl->name = malloc(sizeof(char)*(strlen((char*)(db_file + pos + 2)) + 1));
	    strcpy(fl->name, (char*)(db_file + pos + 2));
	    pos += 3 + strlen(fl->name);
	    fl->realname = malloc(sizeof(char)*(strlen((char*)(db_file + pos)) + 1));
	    strcpy(fl->realname, (char*)(db_file + pos));
	    pos += strlen(fl->realname) + 1;

	    fl->data   = NULL;
	    fl->nlines = 0;
	    fl->line   = NULL;

	    fn = malloc(sizeof(char)*(strlen(fl->realname)+strlen(pathname)+1));
	    strcpy(fn, fl->realname);

	    fl_len = get_file_size(fn);
	    if (fl_len == -1)
	      {
		strcpy(fn, pathname);
		strcat(fn, fl->realname);
		fl_len = get_file_size(fn);
	      }
	    if (fl_len >= 0)
	      {
		fl_load = open_file(fn);
		if (fl_load != NULL)
		  {
		    int x;

		    fl->data = (char*)read_block(fl_load, 0, fl_len);
		    close_file(fl_load);
		    fl->data = realloc(fl->data, sizeof(char)*(fl_len+2));
		    fl->data[fl_len] = 0;
		    
		    fl->nlines++;
		    fl->line = realloc(fl->line, sizeof(char*)*(fl->nlines));
		    fl->line[0] = fl->data;

		    for (x=0; x<fl_len; x++)
		      {
			if (fl->data[x] == 13 || fl->data[x] == 10)
			  {
			    int p;

			    p = x;

			    if (((fl->data[x+1] == 10 || fl->data[x+1] == 13) &&
				 fl->data[x+1] != fl->data[x]))
				x++;

			    fl->data[p] = 0;

			    if (x < fl_len)
			      {
				fl->nlines++;
				fl->line = realloc(fl->line,
						  sizeof(char*)*fl->nlines);
				fl->line[fl->nlines-1] = fl->data + x+1;
			      }
			  }
		      }
		  }
	      }
	    else
	      {
		display_printf("=? unable to load source file '%s'\n", fl->realname);
	      }

	    free(fn);

	    debug_syms.nfiles++;
	    
	    if (debug_syms.nfiles != fl->number)
	      {
		display_printf("=! file '%s' doesn't appear in order\n",
			       fl->name);
		goto failed;
	      }

	    debug_syms.files = realloc(debug_syms.files, 
				       sizeof(debug_file)*(debug_syms.nfiles+1));
	    debug_syms.files[fl->number] = *fl;

	    hash_store_happy(debug_syms.file,
			     (unsigned char*)fl->name,
			     (int)strlen(fl->name),
			     fl);
	  }
	  break;
	  
	case DEBUG_CLASS_DBR:
	  {
	    debug_class c;

	    pos++;

	    c.name = malloc(sizeof(char)*(strlen(db_file + pos)+1));
	    strcpy(c.name, db_file + pos);
	    pos += strlen(db_file+pos) + 1;
	    
	    c.st_fl  = db_file[pos++];
	    c.st_ln  = db_file[pos++]<<8;
	    c.st_ln |= db_file[pos++];
	    c.st_ch  = db_file[pos++];
	    
	    c.end_fl  = db_file[pos++];
	    c.end_ln  = db_file[pos++]<<8;
	    c.end_ln |= db_file[pos++];
	    c.end_ch  = db_file[pos++];	    

	    sym             = malloc(sizeof(debug_symbol));
	    sym->type       = dbg_class;
	    sym->data.class = c;
	    debug_add_symbol(c.name,
			     sym);
	  }
	  break;

	case DEBUG_OBJECT_DBR:
	  {
	    debug_object o;

	    pos++;

	    o.number  = db_file[pos++]<<8;
	    o.number |= db_file[pos++];

	    o.name = malloc(sizeof(char)*(strlen(db_file + pos)+1));
	    strcpy(o.name, db_file + pos);
	    pos += strlen(db_file+pos) + 1;
	    
	    o.st_fl  = db_file[pos++];
	    o.st_ln  = db_file[pos++]<<8;
	    o.st_ln |= db_file[pos++];
	    o.st_ch  = db_file[pos++];
	    
	    o.end_fl  = db_file[pos++];
	    o.end_ln  = db_file[pos++]<<8;
	    o.end_ln |= db_file[pos++];
	    o.end_ch  = db_file[pos++];	    

	    sym              = malloc(sizeof(debug_symbol));
	    sym->type        = dbg_object;
	    sym->data.object = o;
	    debug_add_symbol(o.name,
			     sym);
	    
	    if (o.number > debug_syms.largest_object) debug_syms.largest_object = o.number;
	  }
	  break;
	  
	case DEBUG_GLOBAL_DBR:
	  {
	    debug_global g;

	    pos++;

	    g.number  = db_file[pos++];

	    g.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(g.name, db_file + pos);
	    pos += strlen(db_file + pos) + 1;

	    sym              = malloc(sizeof(debug_symbol));
	    sym->type        = dbg_global;
	    sym->data.global = g;
	    debug_add_symbol(g.name,
			     sym);
	  }
	  break;

	case DEBUG_ATTR_DBR:
	  {
	    debug_attr a;
 
	    pos++;

	    a.number  = db_file[pos++]<<8;
	    a.number |= db_file[pos++];

	    a.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(a.name, db_file + pos);
	    pos += strlen(a.name)+1;

	    sym             = malloc(sizeof(debug_symbol));
	    sym->type       = dbg_attr;
	    sym->data.attr  = a;
	    debug_add_symbol(a.name,
			     sym);
	  }
	  break;

	case DEBUG_PROP_DBR:
	  {
	    debug_prop p;

	    pos++;

	    p.number  = db_file[pos++]<<8;
	    p.number |= db_file[pos++];

	    p.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(p.name, db_file + pos);
	    pos += strlen(p.name)+1;

	    sym             = malloc(sizeof(debug_symbol));
	    sym->type       = dbg_prop;
	    sym->data.prop  = p;
	    debug_add_symbol(p.name,
			     sym);
	  }
	  break;

	case DEBUG_ACTION_DBR:
	  {
	    debug_action a;

	    pos++;

	    a.number  = db_file[pos++]<<8;
	    a.number |= db_file[pos++];

	    a.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(a.name, db_file + pos);
	    pos += strlen(db_file + pos) + 1;

	    sym              = malloc(sizeof(debug_symbol));
	    sym->type        = dbg_action;
	    sym->data.action = a;
	    /* debug_add_symbol(a.name,
	       sym); */
	  }
	  break;

	case DEBUG_FAKEACT_DBR:
	  {
	    debug_fakeact a;

	    pos++;

	    a.number  = db_file[pos++]<<8;
	    a.number |= db_file[pos++];

	    a.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(a.name, db_file + pos);
	    pos += strlen(db_file + pos) + 1;

	    sym               = malloc(sizeof(debug_symbol));
	    sym->type         = dbg_fakeact;
	    sym->data.fakeact = a;
	    /* debug_add_symbol(a.name,
	       sym); */
	  }
	  break;

	case DEBUG_ARRAY_DBR:
	  {
	    debug_array a;

	    pos++;

	    a.offset  = db_file[pos++]<<8;
	    a.offset |= db_file[pos++];

	    a.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(a.name, db_file + pos);
	    pos += strlen(db_file + pos) + 1;

	    sym             = malloc(sizeof(debug_symbol));
	    sym->type       = dbg_array;
	    sym->data.array = a;
	    debug_add_symbol(a.name,
			     sym);
	  }
	  break;

	case DEBUG_HEADER_DBR:
	  pos++;

	  pos += 64;
	  break;

	case DEBUG_LINEREF_DBR:
	  {
	    debug_line l;
	    int rno;
	    int nseq;
	    int x;

	    pos++;

	    rno   = db_file[pos++]<<8;
	    rno  |= db_file[pos++];
	    nseq  = db_file[pos++]<<8;
	    nseq |= db_file[pos++];

	    if (rno != this_routine->number)
	      {
		display_printf("=! routine number of line does not match current routine\n");
		goto failed;
	      }
	    
	    for (x=0; x<nseq; x++)
	      {
		l.fl  = db_file[pos++];
		l.ln  = db_file[pos++]<<8;
		l.ln |= db_file[pos++];
		l.ch  = db_file[pos++];

		l.address  = db_file[pos++]<<8;
		l.address |= db_file[pos++];
		l.address += this_routine->start;

		this_routine->line = realloc(this_routine->line,
					     sizeof(debug_line)*(this_routine->nlines+1));
		this_routine->line[this_routine->nlines] = l;
		this_routine->nlines++;
	      }
	  }
	  break;

	case DEBUG_ROUTINE_DBR:
	  {
	    debug_routine r;

	    pos++;

	    r.number   = db_file[pos++]<<8;
	    r.number  |= db_file[pos++];
	    r.defn_fl  = db_file[pos++];
	    r.defn_ln  = db_file[pos++]<<8;
	    r.defn_ln |= db_file[pos++];
	    r.defn_ch  = db_file[pos++];
	    
	    r.start  = db_file[pos++]<<16;
	    r.start |= db_file[pos++]<<8;
	    r.start |= db_file[pos++];

	    r.name = malloc(sizeof(char)*(strlen(db_file+pos) + 1));
	    strcpy(r.name, db_file + pos);
	    pos += strlen(r.name)+1;

	    r.nvars = 0;
	    r.var   = NULL;

	    while (db_file[pos] != 0)
	      {
		r.var = realloc(r.var, sizeof(char*)*(r.nvars+1));
		r.var[r.nvars] = malloc(sizeof(char)*(strlen(db_file+pos) + 1));
		strcpy(r.var[r.nvars], db_file+pos);
		pos += strlen(r.var[r.nvars]) + 1;
		r.nvars++;
	      }
	    pos++;

	    r.nlines = 0;
	    r.line   = NULL;

	    if (this_routine != NULL &&
		this_routine->start >= r.start)
	      {
		display_printf("=! Out of order routines\n");
	      }
	    
	    debug_syms.routine = realloc(debug_syms.routine,
					 sizeof(debug_routine)*
					 (debug_syms.nroutines+1));

	    debug_syms.routine[debug_syms.nroutines] = r;
	    this_routine = debug_syms.routine + debug_syms.nroutines;

	    debug_syms.nroutines++;

	    sym               = malloc(sizeof(debug_symbol));
	    sym->type         = dbg_routine;
	    sym->data.routine = debug_syms.nroutines-1;
	    debug_add_symbol(this_routine->name,
			     sym);
	  }
	  break;
	  
	case DEBUG_ROUTINE_END_DBR:
	  {
	    int rno;

	    pos++;

	    rno   = db_file[pos++]<<8;
	    rno  |= db_file[pos++];

	    if (rno != this_routine->number)
	      {
		display_printf("=! routine number of EOR does not match current routine\n");
		goto failed;
	      }

	    this_routine->end_fl  = db_file[pos++];
	    this_routine->end_ln  = db_file[pos++]<<8;
	    this_routine->end_ln |= db_file[pos++];
	    this_routine->end_ch  = db_file[pos++];

	    this_routine->end     = db_file[pos++]<<16;
	    this_routine->end    |= db_file[pos++]<<8;
	    this_routine->end    |= db_file[pos++];
	  }
	  break;

	case DEBUG_MAP_DBR:
	  {
	    pos++;

	    while (db_file[pos] != 0)
	      {
		char* name;
		ZDWord address;

		name = db_file + pos;
		pos += strlen(db_file + pos) + 1;

		address  = db_file[pos++]<<16;
		address |= db_file[pos++]<<8;
		address |= db_file[pos++];

		/* Fill in various fields according to what we get... */
		if (strcmp(name, "code area") == 0)
		  {
		    debug_syms.codearea = address;
		  } else if (strcmp(name, "strings area") == 0) {
			  debug_syms.stringarea = address;
		  }
	      }
	    pos++;
	  }
	  break;

	default:
	  display_printf("=! unknown record type %i\n", db_file[pos]);
	  goto failed;
	  return;
	}
    }

  /* Update addresses of routines/lines */
  for (x=0; x<debug_syms.nroutines; x++)
    {
      int y;

      debug_syms.routine[x].start += debug_syms.codearea;
      debug_syms.routine[x].end   += debug_syms.codearea;

      for (y=0; y<debug_syms.routine[x].nlines; y++)
	{
	  debug_syms.routine[x].line[y].address += debug_syms.codearea;
	}
    }

  free(db_file);
  return;

 failed:
  free(db_file);
}

/* 
 * Looks up information about a given (Z-Machine) address - finds routine,
 * line information
 */
debug_address debug_find_address(int address)
{
  debug_address res;
  int x;

  res.routine = NULL;
  res.line    = NULL;
  res.line_no = -1;

  for (x=0; x<debug_syms.nroutines; x++)
    {
      if (address > debug_syms.routine[x].start &&
	  address < debug_syms.routine[x].end)
	{
	  res.routine = debug_syms.routine + x;
	  break;
	}
    }

  if (res.routine == NULL)
    return res;

  for (x=0; x<res.routine->nlines; x++)
    {
      if (res.routine->line[x].address > address)
	break;

      res.line_no = x;
      res.line = res.routine->line + x;
    }

  return res;
}

/*
 * Finds the Z-Machine address of something named by the user
 * (eg parserm:3856 for line 3856 of parserm, or InformLibrary.play
 * for the start of the InformLibrary.play() routine)
 */
int debug_find_named_address(const char* name)
{
  static char* ourname = NULL;
  long x, len;
  debug_symbol* sym;

  len = strlen(name);
  ourname = realloc(ourname, sizeof(char)*(len+1));
  strcpy(ourname, name);
  
  /* See if we have a routine... */
  for (x=0; x<len; x++)
    {
      if (ourname[x] >= 'A' && ourname[x] <= 'Z')
	{
	  ourname[x] += 32;
	}
    }

  sym = hash_get(debug_syms.symbol,
		 ourname,
		 (int)len);

  if (sym != NULL &&
      sym->type == dbg_routine)
    {
      return debug_syms.routine[sym->data.routine].start + 1;
    }

  /* Files are case-sensitive (usually. Not on Mac OS, bizarrely) */
  strcpy(ourname, name);

  if (ourname[0] == '#')
    {
      int adr;

      adr = 0;
      
      /* PC value */
      for (x=1; x<len; x++)
	{
	  adr <<= 4;
	  if (ourname[x] >= '0' && ourname[x] <= '9')
	    adr += ourname[x] - '0';
	  else if (ourname[x] >= 'A' && ourname[x] <= 'F')
	    adr += ourname[x] - 'A' + 10;
	  else if (ourname[x] >= 'a' && ourname[x] <= 'f')
	    adr += ourname[x] - 'a' + 10;
	  else
	    break;
	}

      if (x == len && adr >= 0 && adr < machine.story_length)
	return adr;
    }

  for (x=len-1; 
       x>0 && (ourname[x] >= '0' && ourname[x] <= '9');
       x--);

  if (ourname[x] == ':')
    {
      debug_file* fl;
      int line_no;

      ourname[x] = 0;

      line_no = atoi(ourname + x + 1);

      fl = hash_get(debug_syms.file,
		    ourname,
		    (int)strlen(ourname));
      
      if (fl != NULL)
	{
	  for (x=0; x<debug_syms.nroutines; x++)
	    {
	      if ((debug_syms.routine[x].defn_fl == fl->number &&
		   debug_syms.routine[x].end_fl == fl->number) &&
		  debug_syms.routine[x].defn_ln <= line_no &&
		  debug_syms.routine[x].end_ln  >= line_no)
		{
		  int y;
		  debug_routine* r;
		  int found_line = 0;

		  r = debug_syms.routine + x;
		  
		  for (y=0; y<r->nlines; y++)
		    {
		      found_line = y;

		      if (r->line[y].ln >= line_no)
			break;
		    }

		  return r->line[found_line].address;
		}
	    }
	}
    }

  return -1;
}

char* debug_address_string(debug_address addr, int pc, int format)
{
  static char* res = NULL;
  char num[10];
  int len;
  
  len = 0;
  res = realloc(res, sizeof(char));
  res[0] = 0;

  if (addr.routine != NULL &&
      addr.line    != NULL)
    {
      if (format == 1)
	{
	  len += strlen(addr.routine->name)+5;
	  res = realloc(res, sizeof(char)*(len+1));
	  strcat(res, addr.routine->name);
	  strcat(res, "() (");
	}

      if (addr.routine->defn_fl > 0 && addr.routine->defn_fl != 255)
	{
	  len += strlen(debug_syms.files[addr.routine->defn_fl].name)+1;
	  res = realloc(res, sizeof(char)*(len+1));
	  strcat(res, debug_syms.files[addr.routine->defn_fl].name);
	  strcat(res, ":");
	}

      sprintf(num, "%i", addr.line->ln);
      
      len += strlen(num);
      res = realloc(res, sizeof(char)*(len+1));
      strcat(res, num);

      if (format == 1)
	strcat(res, ")");
      else
	{
	  len += strlen(addr.routine->name)+3;
	  res = realloc(res, sizeof(char)*(len+1));
	  strcat(res, " (");
	  strcat(res, addr.routine->name);
	  strcat(res, ")");
	}
    }
  else if (addr.routine != NULL)
    {
      len += strlen(addr.routine->name)+1;
      res = realloc(res, sizeof(char)*(len+1));
      strcat(res, addr.routine->name);
      strcat(res, ":");

      sprintf(num, "#%05x", pc);
      len += strlen(num);
      res = realloc(res, sizeof(char)*(len+1));
      strcat(res, num);
    }
  else
    {
      if (format == 1)
	{
	  len += 4;
	  res = realloc(res, sizeof(char)*(len+1));
	  strcat(res, "??? ");
	}

      sprintf(num, "#%05x", pc);
      len += strlen(num);
      res = realloc(res, sizeof(char)*(len+1));
      strcat(res, num);      
    }

  return res;
}

ZWord debug_symbol_value(const char*    symbol,
			 debug_routine* r)
{
  static char* sym = NULL;
  debug_symbol* res;
  long x, len;

  len = strlen(symbol);
  sym = realloc(sym, sizeof(char)*(len+1));
  for (x=0; x<len; x++)
    {
      if (symbol[x] >= 'A' && symbol[x] <= 'Z')
	sym[x] = symbol[x] + 32;
      else
	sym[x] = symbol[x];
    }
  sym[len] = 0;

  if (r != NULL)
    {
      for (x=0; x<r->nvars; x++)
	{
	  if (strcmp(r->var[x], symbol) == 0)
	    {
	      return machine.stack.current_frame->local[x+1];
	    }
	}
    }

  res = hash_get(debug_syms.symbol,
		 sym,
		 (int)len);

  if (res != NULL)
    {
      switch (res->type)
	{
	case dbg_class:
	  return -1;

	case dbg_object:
	  return res->data.object.number;

	case dbg_global:
	  return machine.globals[res->data.global.number<<1]<<8 |
	    machine.globals[(res->data.global.number<<1)+1];
	  
	case dbg_attr:
	  return -1;

	case dbg_prop:
	  return res->data.prop.number;
	  
	case dbg_array:
	  return GetWord(machine.header, ZH_globals) + res->data.array.offset;

	default:
	  break;
	}
    }

  debug_error = "Symbol not found";
  return 0;
}

/* Expression evaluation */
void debug_eval_error(const char* erm)
{
  debug_error = erm;
}

int debug_eval_lex(void)
{
  int start;

  if (debug_expr[debug_expr_pos] == 0)
    return 0;

  while (debug_expr[debug_expr_pos] == ' ')
    debug_expr_pos++;

  start = debug_expr_pos;

  if ((debug_expr[debug_expr_pos] >= 'A' && debug_expr[debug_expr_pos] <= 'Z') ||
      (debug_expr[debug_expr_pos] >= 'a' && debug_expr[debug_expr_pos] <= 'z'))
    {
      int x;

      /* IDENTIFIER */
      while ((debug_expr[debug_expr_pos] >= 'A' && debug_expr[debug_expr_pos] <= 'Z') ||
	     (debug_expr[debug_expr_pos] >= 'a' && debug_expr[debug_expr_pos] <= 'z') ||
	     (debug_expr[debug_expr_pos] >= '0' && debug_expr[debug_expr_pos] <= '9') ||
	     debug_expr[debug_expr_pos] == '_')
	{
	  debug_expr_pos++;
	}

      yylval.str = malloc(sizeof(char)*(debug_expr_pos-start+1));
      for (x=start; x<debug_expr_pos; x++)
	{
	  yylval.str[x-start] = debug_expr[x];
	}
      yylval.str[debug_expr_pos-start] = 0;

      return IDENTIFIER;
    }
  
  if (debug_expr[debug_expr_pos] >= '0' && debug_expr[debug_expr_pos] <= '9')
    {
      /* NUMBER */
      yylval.number = 0;

      while (debug_expr[debug_expr_pos] >= '0' && debug_expr[debug_expr_pos] <= '9')
	{
	  yylval.number *= 10;
	  yylval.number += debug_expr[debug_expr_pos] - '0';
	  debug_expr_pos++;
	}
      return NUMBER;
    }

  if (debug_expr[debug_expr_pos] == '$')
    {
      /* NUMBER */
      yylval.number = 0;
      debug_expr_pos++;

      while ((debug_expr[debug_expr_pos] >= '0' && debug_expr[debug_expr_pos] <= '9') ||
	     (debug_expr[debug_expr_pos] >= 'A' && debug_expr[debug_expr_pos] <= 'F') ||
	     (debug_expr[debug_expr_pos] >= 'a' && debug_expr[debug_expr_pos] <= 'f'))
	{
	  yylval.number *= 16;
	  if (debug_expr[debug_expr_pos] >= '0' && debug_expr[debug_expr_pos] <= '9')
	    yylval.number += debug_expr[debug_expr_pos] - '0';
	  else if (debug_expr[debug_expr_pos] >= 'A' && debug_expr[debug_expr_pos] <= 'F')
	    yylval.number += debug_expr[debug_expr_pos] - 'A' + 10;
	  else if (debug_expr[debug_expr_pos] >= 'a' && debug_expr[debug_expr_pos] <= 'f')
	    yylval.number += debug_expr[debug_expr_pos] - 'a' + 10;

	  debug_expr_pos++;
	}

      return NUMBER;
    }

  if (debug_expr[debug_expr_pos] == '-')
    {
      if (debug_expr[debug_expr_pos+1] == '>')
	{
	  debug_expr_pos+=2;
	  return BYTEARRAY;
	}
      if (debug_expr[debug_expr_pos+1] == '-' && debug_expr[debug_expr_pos+2] == '>')
	{
	  debug_expr_pos += 3;
	  return WORDARRAY;
	}
    }

  if (debug_expr[debug_expr_pos] == '.')
    {
      if (debug_expr[debug_expr_pos+1] == '&')
	{
	  debug_expr_pos+=2;
	  return PROPADDR;
	}
      if (debug_expr[debug_expr_pos+1] == '#')
	{
	  debug_expr_pos+=2;
	  return PROPLEN;
	}
    }

  debug_expr_pos++;
  if (debug_expr[debug_expr_pos-1] < 256)
    return debug_expr[debug_expr_pos-1];
  return '?';
}

char* debug_print_value(ZWord value, char* type)
{
  static char res[256];

  if (type == NULL)
    type = "signed";

  if (strcmp(type, "unsigned") == 0)
    {
      sprintf(res, "%u", value);
    }
  if (strcmp(type, "hex") == 0)
    {
      sprintf(res, "$%x\n", value);
    }
  else
    {
      sprintf(res, "%i", value);
    }

  return res;
}

void debug_set_bp_handler(debug_breakpoint_handler handler) {
	static int initialised = 0;
	int x;
	
	bp_handler = handler;
	
	if (!initialised) {
		initialised = 1;
		
		for (x=0; x<debug_syms.nroutines; x++) {
			debug_set_breakpoint(debug_syms.routine[x].start+1,
								 0, 1);
		}
	}
}

void debug_set_temp_breakpoints(debug_step_type step) {
	int ln;
	ZFrame* frame;
	
	if (addr.routine != NULL) {	
		ln = addr.line_no;
		if (ln != -1) {
			ln++;
		}
	
		if (ln >= addr.routine->nlines) {
			ln = -1;
		}
		
		if (step == debug_step_into) {
			stepinto = 1;
		}
		
		/* Set a breakpoint on each line... */
		if (step != debug_step_out) {
			for (ln = 0; ln < addr.routine->nlines; ln++) {
				debug_set_breakpoint(addr.routine->line[ln].address, 1, 0);
			}
		}
	}
	
	/* Set a breakpoint on the return location of this function */
	if (machine.stack.current_frame) {
		for (frame = machine.stack.current_frame->last_frame; frame != NULL; frame = frame->last_frame) {
			frame->break_on_return = 1;
		}
	}
}
