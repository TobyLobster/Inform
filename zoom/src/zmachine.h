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
 * Data types that describe the Z-Machine
 */

#ifndef __ZMACHINE_H
#define __ZMACHINE_H

#include <stdio.h>

#include "ztypes.h"
#include "hash.h"
#include "file.h"
#include "display.h"
#include "blorb.h"

/*
 * You can #define the following definitions to alter how your version 
 * of Zoom is compiled.
 *
 * DEBUG does produce rather a lot of debugging information (~15Mb
 * from advent.z5, just to open the grate...). However, if you know
 * what you're doing, you may find this useful to fix problems in your 
 * games (or locate problems in Zoom)
 *
 * Undefining SAFE will turn off bounds checking in any operations
 * that use it.
 *
 * GLOBAL_PC will make the program counter be stored in a global
 * variable - this creates a very slight slowdown, but means warnings
 * and errors can give the PC that they occured at
 *
 * CAN_UNDO means that the undo commands are supported
 *
 * SQUEEZEUNDO will cause the undo buffer to be compressed (which is slow)
 *
 * SPEC_10 will cause the interpreter to indicate that it is
 * conformant to the v1.0 specification.
 *
 * GRAPHICAL causes the interpreter to run version 5 games in
 * 'graphical' mode. Beyond Zork supports this, Inform games do
 * not. The v1.0 specification indicates that you shouldn't do this,
 * but games that do not support this mode do not have the 'pictures'
 * bit set, Beyond Zork being the only v5 game that I know of that has 
 * this bit set. This doesn't actually do a lot any more.
 */

#undef  DEBUG        /* Lots of debugging crap */
#define SAFE         /* Perform more bounds checking */
#undef  PAGED_MEMORY /* Not implemented, anyway ;-) */
#define GLOBAL_PC    /* Set to make the program counter global */
#define CAN_UNDO     /* Support the undo commands */
#define UNDO_LEVEL 5 /* Number of levels of undo that we support */
#undef  SQUEEZEUNDO  /* Store undo information in a compressed format (slow) */
#undef  TRACKING     /* Enable object tracking options */
#define SPEC_10      /*
		      * Unset if you don`t believe me when I say this
                      * interpreter is conformant to the ZMachine
		      * specification v1.0
		      */
#define SPEC_11      /* Define to implement spec 1.1 (draft 6) */
#undef  GRAPHICAL    /*
		      * Define to set the default behaviour to mimic
		      * that of the Beyond Zork interpreter
		      */
#define V6ASSERT     /* 
		      * Performs sanity checks to ensure that non-v6
		      * display functions are not called from a v6 game
		      */
#undef  CUTE_STARTUP /* 'Adventure-style' warranty message */

#ifndef REMOTE_BREAKPOINT
#undef REMOTE_BREAKPOINT /* Send SIGUSR1 to force a breakpoint at the next execution point */
#endif

/*
 * Versions to support (note that support for version 5 includes
 * support for versions 7 and 8 as well
 */
#define SUPPORT_VERSION_3
#define SUPPORT_VERSION_4
#define SUPPORT_VERSION_5
#define SUPPORT_VERSION_6

/* File format */

enum ZHeader_bytes
{
  ZH_version   = 0x00,
  ZH_flags,
  ZH_release   = 0x02,
  ZH_base_high = 0x04,
  ZH_initpc    = 0x06,
  ZH_dict      = 0x08,
  ZH_objs      = 0x0a,
  ZH_globals   = 0x0c,
  ZH_static    = 0x0e,
  ZH_flags2    = 0x10,
  ZH_serial    = 0x12,
  ZH_abbrevs   = 0x18,
  ZH_filelen   = 0x1a,
  ZH_checksum  = 0x1c,
  ZH_intnumber = 0x1e,
  ZH_intvers,
  ZH_lines,
  ZH_columns,
  ZH_width         = 0x22,
  ZH_height        = 0x24,
  ZH_fontwidth     = 0x26, /* height in v6 */
  ZH_fontheight,           /* width in v6 */
  ZH_routines,
  ZH_staticstrings = 0x2a,
  ZH_defback       = 0x2c,
  ZH_deffore,
  ZH_termtable,
  ZH_widthos3      = 0x30,
  ZH_revnumber     = 0x32,
  ZH_alphatable    = 0x34,
  ZH_extntable     = 0x36
};

enum ZHEB_bytes
{
  ZHEB_len      = 0,
  ZHEB_xmouse   = 2,
  ZHEB_ymouse   = 4,
  ZHEB_unitable = 6,
  ZHEB_flags3   = 8,
  ZHEB_truefore = 10,
  ZHEB_trueback = 12
};

/* Internal data structures */

typedef struct ZMap
{
  ZDWord  actual_size;
  ZByte*  mapped_pages;
  ZByte** pages;
} ZMap;

struct ZStack;

typedef struct ZArgblock
{
  int n_args;
  ZWord arg[8];
} ZArgblock;

typedef struct ZFrame
{
  /* Return address */
  ZDWord ret;

  ZByte  nlocals;    /* Number of locals */
  ZByte  flags;      /* Arguments supplied */
  ZByte  storevar;   /* Variable to store result in on return */
  ZByte  discard;    /* Nonzero if result should be discarded */
  
  ZWord  frame_size; /* Evaluation size */

  ZWord  local[16];
  ZUWord frame_num;
  
  int break_on_return; /* Used by the debugger */

  void (*v4read)(ZDWord*, struct ZStack*, ZArgblock*);
  void (*v5read)(ZDWord*, struct ZStack*, ZArgblock*, int);
  int  end_func;
  ZArgblock readblock;
  int       readstore;
  
  struct ZFrame* last_frame;
} ZFrame;

typedef struct ZStack
{
  ZDWord  stack_total;
  ZDWord  stack_size;
  ZWord*  stack;
  ZWord*  stack_top;
  ZFrame* current_frame;
} ZStack;

typedef struct ZMachine
{
  ZUWord   static_ceiling;
  ZUWord   dynamic_ceiling;
  ZDWord   high_start;
  ZDWord   story_offset;
  ZDWord   story_length;

  ZByte*   header;
  ZByte*   dynamic_memory;

  ZFile*   file;
  const char*story_file;

  ZByte* undo    [UNDO_LEVEL];
  ZDWord undo_len[UNDO_LEVEL];

  ZByte  version;

#ifdef PAGED_MEMORY
  ZMap     memory; /* Still not implemented */
#else
  ZByte*   memory;
#endif

  ZByte*   globals;

  ZStack   stack;

  int*     abbrev     [96];
  int      abbrev_addr[96];

  ZByte*   dict;

  hash     cached_dictionaries;

  enum {
    packed_v3,
    packed_v4,
    packed_v6,
    packed_v8
  } packtype;

  ZDWord routine_offset;
  ZDWord string_offset;

  int display_active;
  ZDisplay* dinfo;

  int graphical;

  /* Header extension block */
  ZByte* heb;
  ZUWord heblen;

  /* Output streams */
  int    mouse_on;
  int    screen_on;
  int    transcript_on;
  int    transcript_commands;
  ZFile* transcript_file;

  int    memory_on;
  ZUWord memory_pos  [16];
  int    memory_width[16];
  
  int    buffering;

  /* Input streams */
  int    script_on;
  ZFile* script_file;

#ifdef GLOBAL_PC
  ZDWord zpc;
#endif
  
  /* Autosaving */
  ZDWord autosave_pc;

  /* Commandline options */
  int warning_level;

#ifdef TRACKING
  int track_objects;
  int track_properties;
  int track_attributes;
#endif

  ZFile*     blorb_file;
  IffFile*   blorb_tokens;
  BlorbFile* blorb;
  
  int force_breakpoint;
} ZMachine;

typedef struct ZDictionary
{
  char sep[256];
  hash words;
} ZDictionary;

extern void  zmachine_load_story    (const char* filename, ZMachine* machine);
extern void  zmachine_load_file     (ZFile* file, ZMachine* machine);
extern void  zmachine_setup_header  (void);
extern void  zmachine_resize_display(ZDisplay* dis);
extern void  zmachine_fatal         (const char* format, ...) __dead2 __printflike(1, 2);
extern void  zmachine_warning       (const char* format, ...) __printflike(1, 2);
extern void  zmachine_info          (const char* format, ...) __printflike(1, 2);
extern void  zmachine_mark_statusbar(void);
extern char* zmachine_get_serial    (void);
extern void  zmachine_dump_stack    (ZStack* stack);

extern ZWord   pop         (ZStack*);
extern ZWord   top         (ZStack*);
extern ZFrame* call_routine(ZDWord* pc, ZStack* stack, ZDWord start);
     
/* Utility macros */

#ifdef DEBUG
extern ZWord debug_print_var(ZWord val, int var);
#define DebugVar(x, y) debug_print_var(x, y)
#else
#define DebugVar(x, y) x
#endif

#define GetVar(y)  DebugVar(((y)==0?pop(stack):(((unsigned char) (y))<16?stack->current_frame->local[(y)]:(machine.globals[((y)<<1)-32]<<8)|machine.globals[((y)<<1)-31])), y)
#define GetVarNoPop(y) DebugVar(((y)==0?top(stack):(((unsigned char) (y))<16?stack->current_frame->local[(y)]:(machine.globals[((y)<<1)-32]<<8)|machine.globals[((y)<<1)-31])), y)
#define GetCode(x)  machine.memory[(x)]
#define Word(x)     ((machine.memory[(x)]<<8)|machine.memory[(x)+1])
#define ReadByte(x) (machine.memory[(x)])
#define GetWord(m, x) ((m[x]<<8)|(m[x+1]))
#define Address(x) (machine.memory + (x))

extern ZMachine machine;

#endif
