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

#ifndef __DEBUG_H
#define __DEBUG_H

#include "zmachine.h"
#include "file.h"
#include "hash.h"

/* === Debug data structures === */

typedef struct debug_breakpoint debug_breakpoint;
typedef struct debug_symbols    debug_symbols;
typedef struct debug_symbol     debug_symbol;
typedef struct debug_file       debug_file;
typedef struct debug_line       debug_line;

/* Symbols */
typedef struct debug_class      debug_class;
typedef struct debug_object     debug_object;
typedef struct debug_global     debug_global;
typedef struct debug_array      debug_array;
typedef struct debug_attr       debug_attr;
typedef struct debug_prop       debug_prop;
typedef struct debug_fakeact    debug_fakeact;
typedef struct debug_action     debug_action;
typedef struct debug_routine    debug_routine;

/* Information structures */
typedef struct debug_address    debug_address;

/* External debuggers */
typedef void(*debug_breakpoint_handler)(ZDWord pc);
typedef enum debug_step_type {
	debug_step_over,
	debug_step_into,
	debug_step_out
} debug_step_type;

struct debug_file
{
  int number;
  char* name;
  char* realname;

  char*  data;
  int    nlines;
  char** line;
};

struct debug_class
{
  char* name;
  
  int st_fl, st_ln, st_ch;
  int end_fl, end_ln, end_ch;
};

struct debug_object
{
  int number;
  char* name;
  
  int st_fl, st_ln, st_ch;
  int end_fl, end_ln, end_ch;
};

struct debug_global
{
  int   number;
  char* name;
};

struct debug_array
{
  int offset;
  char* name;
};

struct debug_attr
{
  int   number;
  char* name;
};

struct debug_prop
{
  int   number;
  char* name;
};

struct debug_fakeact
{
  int number;
  char* name;
};

struct debug_action
{
  int number;
  char* name;
};

struct debug_line
{
  int fl, ln, ch;
  ZDWord address;
};

struct debug_routine
{
  int number;
  
  int defn_fl, defn_ln, defn_ch;
  ZDWord start;

  ZDWord end;
  int end_fl, end_ln, end_ch;

  char* name;

  int    nvars;
  char** var;

  int         nlines;
  debug_line* line;
};

struct debug_symbol
{
  enum
    {
      dbg_class,
      dbg_object,
      dbg_global,
      dbg_attr,
      dbg_prop,
      dbg_action,
      dbg_fakeact,
      dbg_array,
      dbg_routine
    }
  type;

  union
  {
    debug_class    class;
    debug_object   object;
    debug_global   global;
    debug_attr     attr;
    debug_prop     prop;
    debug_action   action;
    debug_fakeact  fakeact;
    debug_array    array;
    int            routine;
  } data;

  debug_symbol* next;
};

struct debug_breakpoint
{
  ZDWord address;
  ZByte  original;

  int    usage;
  int    temporary;
  int    funcbp;
};

struct debug_symbols
{
  int nsymbols;
  hash symbol;
  hash file;

  debug_symbol* first_symbol;

  debug_routine* routine;
  int            nroutines;
  debug_file*    files;
  int            nfiles;

  ZDWord         codearea;
  ZDWord		 stringarea;
  ZDWord		 largest_object;
};

struct debug_address
{
  debug_routine* routine;
  debug_line*    line;

  int            line_no;
};

extern debug_breakpoint* debug_bplist;
extern int               debug_nbps;
extern debug_symbols     debug_syms;
extern int               debug_eval_result;
extern char*             debug_eval_type;
extern const char*       debug_error;

extern int*				 debug_expr;
extern int				 debug_expr_pos;
extern debug_routine*    debug_expr_routine;

#define DEBUG_EOF_DBR 0
#define DEBUG_FILE_DBR 1
#define DEBUG_CLASS_DBR 2
#define DEBUG_OBJECT_DBR 3
#define DEBUG_GLOBAL_DBR 4
#define DEBUG_ATTR_DBR 5
#define DEBUG_PROP_DBR 6
#define DEBUG_FAKEACT_DBR 7
#define DEBUG_ACTION_DBR 8
#define DEBUG_HEADER_DBR 9
#define DEBUG_LINEREF_DBR 10
#define DEBUG_ROUTINE_DBR 11
#define DEBUG_ARRAY_DBR 12
#define DEBUG_MAP_DBR 13
#define DEBUG_ROUTINE_END_DBR 14

/* === Debug functions === */

/* Breakpoints */
extern int               debug_set_breakpoint  (int address,
						int temporary,
						int funcbp);
extern int               debug_clear_breakpoint(debug_breakpoint* bp);
extern debug_breakpoint* debug_get_breakpoint  (int address);

extern void              debug_run_breakpoint(ZDWord pc);

/* === Inform debug file functions === */

/* Initialisation/loading */
extern void              debug_load_symbols    (char* filename,
						char* pathname);

/* Information retrieval */
extern debug_address     debug_find_address      (int   address);
extern int               debug_find_named_address(const char* name);
extern char*             debug_address_string    (debug_address addr, 
						  int pc,
						  int format);

/* === Expression evaluation === */
extern int               debug_eval_parse  (void);
extern void              debug_eval_error  (const char*);
extern int               debug_eval_lex    (void);
extern ZWord             debug_symbol_value(const char*    symbol,
					    debug_routine* r);
extern char*             debug_print_value (ZWord          value,
					    char*          type);

/* === Alternative breakpoint handling === */
extern void debug_set_bp_handler(debug_breakpoint_handler handler);
extern void debug_set_temp_breakpoints(debug_step_type step);

#endif

