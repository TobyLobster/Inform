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
 * Main interpreter loop
 */

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#ifdef HAVE_SYS_TIME_H
# include <sys/time.h>
#endif
#include <ctype.h>
#include <string.h>

#include "zmachine.h"
#include "interp.h"
#include "zscii.h"
#include "display.h"
#include "stream.h"
#include "state.h"
#include "tokenise.h"
#include "rc.h"
#include "random.h"
#include "debug.h"
#include "v6display.h"

#if WINDOW_SYSTEM == 2
#include <windows.h>
#include <commdlg.h>

#include "windisplay.h"
#endif

#ifdef SUPPORT_VERSION_6
#define WinNum(x) ((x)==-3?v6_get_window():(x))

#define StyleSet(x, y) switch (argblock.arg[2]) { case 0: x = (y)!=0; \
   break; case 1: if ((y)!=0) x=1; break; case 2: if ((y)!=0) x=0; break; \
   case 3: x ^= (y)!=0; }

static struct v6_wind
{
  int wrapping, scrolling, transcript, buffering;

  int x, y;
  int xsize, ysize;
  int xcur, ycur;
  int leftmar, rightmar;
  ZUWord newline_routine;
  ZWord countdown;
  int style;
  ZUWord colour;

  ZUWord fg_true;
  ZUWord bg_true;

  int font_num;
  ZUWord font_size;

  ZWord line_count;
} windows[8];
#endif

/***                           ----// 888 \\----                           ***/

/* Utilty functions */

#define dobranch \
   if ((result && negate) || (!result && !negate)) \
     { \
       switch (branch) \
	{ \
	case 0: \
	  goto op_rfalse; \
	case 1: \
	  goto op_rtrue; \
	  \
	default: \
	  pc += branch-2; \
          goto loop; \
	} \
     }

static inline void push(ZStack* stack, const ZWord word)
{
  *(stack->stack_top++) = word;
  stack->stack_size--;

  if (stack->current_frame != NULL)
    stack->current_frame->frame_size++;
  
  if (stack->stack_size <= 0)
    {
      int stack_offset = (int)(stack->stack_top - stack->stack);
    
      stack->stack_total += 2048;
      if (!(stack->stack = realloc(stack->stack,
				   stack->stack_total*sizeof(ZWord))))
	{
	  zmachine_fatal("Stack overflow");
	}
      stack->stack_top = stack->stack + stack_offset;
      stack->stack_size += 2048;
    }

#ifdef DEBUG
  if (stack->current_frame)
    printf_debug("Stack: push - size now %i, frame usage %i (pushed #%x)\n",
	   stack->stack_size, stack->current_frame->frame_size,
	   stack->stack_top[-1]);
#endif
}

inline ZWord pop(ZStack* stack)
{
  stack->stack_size++;

  if (stack->current_frame)
    {
      stack->current_frame->frame_size--;
#ifdef SAFE
      if (stack->current_frame->frame_size < 0)
	zmachine_fatal("Stack underflow");
#endif
    }

#ifdef SAFE
  if (stack->stack_top == stack->stack)
    zmachine_fatal("Stack underflow");
#endif
  
#ifdef DEBUG
  if (stack->current_frame)
    printf_debug("Stack: pop - size now %i, frame usage %i (value #%x)\n",
	   stack->stack_size, stack->current_frame->frame_size,
	   stack->stack_top[-1]);
#endif
  
  return *(--stack->stack_top);
}

inline ZWord top(ZStack* stack)
{
    if (stack->current_frame)
    {
#ifdef SAFE
        if (stack->current_frame->frame_size <= 0)
            zmachine_fatal("Stack underflow");
#endif
    }

#ifdef SAFE
    if (stack->stack_top == stack->stack)
        zmachine_fatal("Stack underflow");
#endif

    return *(stack->stack_top-1);
}

ZFrame* call_routine(ZDWord* pc, ZStack* stack, ZDWord start)
{
  ZFrame* newframe;
  int n_locals;
  int x;

  newframe = malloc(sizeof(ZFrame));
  
  newframe->ret          = *pc;
  newframe->flags        = 0;
  newframe->storevar     = 0;
  newframe->discard      = 0;
  newframe->frame_size   = 0;
  newframe->break_on_return = 0;
  if (stack->current_frame != NULL)
    newframe->frame_num  = stack->current_frame->frame_num+1;
  else
    newframe->frame_num  = 1;
  newframe->last_frame   = stack->current_frame;
  newframe->v4read       = NULL;
  newframe->v5read       = NULL;
  newframe->end_func     = 0;
  stack->current_frame   = newframe;
  
  n_locals = GetCode(start);
  newframe->nlocals = n_locals;

  if (machine.memory[0] <= 4)
    {
      for (x=0; x<n_locals; x++)
	{
	  newframe->local[x+1] = (GetCode(start+(x*2)+1)<<8)|
	    GetCode(start+(x*2)+2);
	}
  
      *pc = start+n_locals*2+1;
    }
  else
    {
      if (n_locals > 15)
	{
	  zmachine_warning("Routine with %i locals", n_locals);
	  n_locals = 15;
	}
      for (x=0; x<n_locals; x++)
	{
	  newframe->local[x+1] = 0;
	}

      *pc = start+1;
    }

  return newframe;
}

static inline void store(ZStack* stack, int var, ZWord value)
{
#ifdef DEBUG
  printf_debug("Storing %i in Variable #%x\n", value, var);
#endif
  if (var == 0)
    {
      push(stack, value);
    }
  else if (var < 16)
    {
      stack->current_frame->local[var] = value;
    }
  else
    {
      var-=16;
      machine.globals[var<<1]     = value>>8;
      machine.globals[(var<<1)+1] = value;
    }
}

static inline void store_nopush(ZStack* stack, int var, ZWord value)
{
#ifdef DEBUG
    printf_debug("Storing %i in Variable #%x\n", value, var);
#endif
    if (var == 0)
    {
#ifdef SAFE
        if (stack->stack_top == stack->stack)
            zmachine_fatal("Stack underflow");
#endif

        *(stack->stack_top-1) = value;
    }
    else if (var < 16)
    {
        stack->current_frame->local[var] = value;
    }
    else
    {
        var-=16;
        machine.globals[var<<1]     = value>>8;
        machine.globals[(var<<1)+1] = value;
    }
}

void restart_machine(void)
{
  machine.screen_on = 1;
  machine.transcript_on = 0;
  if (machine.transcript_file)
    {
      close_file(machine.transcript_file);
      machine.transcript_file = NULL;
    }
  machine.memory_on = 0;

  if (ReadByte(0) < 4)
    {
      display_set_window(0);
      display_join(0,2);
    }

  zmachine_setup_header();
  display_has_restarted();
}

#define Obj3(x) (machine.memory + GetWord(machine.header, ZH_objs) + 62+(((x)-1)*9))
#define parent_3  4
#define sibling_3 5
#define child_3   6

struct prop
{
  ZByte* prop;
  int    size;
  int    pad;
  int    isdefault;
};

static inline struct prop* get_object_prop_3(ZUWord object, ZWord property)
{
  ZByte* obj;
  ZByte* prop;
  ZByte  size;
  
  static struct prop info;

  obj = Obj3(object);
  prop = machine.memory + ((obj[7]<<8)|obj[8]);

  prop = prop + (prop[0]*2) + 1;

  while ((size = prop[0]) != 0)
    {
      if ((size&0x1f) == property)
	{
	  info.size = (size>>5) + 1;
	  info.prop = prop + 1;
	  info.isdefault = 0;
	  return &info;
	}
      
      prop = prop + (size>>5) + 2;
    }

  info.size = 2;
  info.prop = machine.memory+GetWord(machine.header, ZH_objs) + 2*property-2;
  info.isdefault = 1;

  return &info;
}

#define UnpackR(x) (machine.packtype==packed_v4?4*((ZUWord)x):(machine.packtype==packed_v8?8*((ZUWord)x):4*((ZUWord)x)+machine.routine_offset))
#define UnpackS(x) (machine.packtype==packed_v4?4*((ZUWord)x):(machine.packtype==packed_v8?8*((ZUWord)x):4*((ZUWord)x)+machine.string_offset))
#define Obj4(x) ((machine.memory + (GetWord(machine.header, ZH_objs))) + 126 + ((((ZUWord)x)-1)*14))
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

static inline struct prop* get_object_prop_4(ZUWord object, ZWord property)
{
  ZByte* obj;
  ZByte* prop;
  int    pnum;
  
  static struct prop info;

  if (object != 0)
    {
      obj = Obj4(object);
      prop = Address((ZUWord)GetPropAddr4(obj));
      
      prop += (prop[0]*2) + 1;
      pnum = 128;
      
      while (pnum != 0)
	{
	  int len, pad;
	  
	  if (prop[0]&0x80)
	    {
	      pnum = prop[0]&0x3f;
	      len  = prop[1]&0x3f;
	      pad  = 2;
	      
	      if (len == 0)
		len = 64;
	    }
	  else
	    {
	      pnum = prop[0]&0x3f;
	      len  = (prop[0]&0x40)?2:1;
	      pad  = 1;
	    }
	  
#ifdef DEBUG
	  printf_debug("(Property %i, (looking for %i) length %i: ", pnum,
		 property, len);
	  {
	    int x;
	    
	    for (x=0; x<=len+pad; x++)
	      printf_debug("$%x ", prop[x]);
	    printf_debug(")\n");
	  }
#endif
	  
	  if (pnum == property)
	    {
	      info.size = len;
	      info.prop = prop + pad;
	      info.isdefault = 0;
	      info.pad = pad;
	      return &info;
	    }
	  
	  prop = prop + len + pad;
	}
    }

#ifdef DEBUG
  printf_debug("Using default property at #%x (%i)\n",
	       Word(ZH_objs)+(2*property-2));
#endif
  
  info.size = 2;
  info.prop = Address(Word(ZH_objs) + 2*property-2);
  info.isdefault = 1;
  info.pad = 0;

  return &info;
}

#ifdef TRACKING
static int* tracking_object(ZUWord arg)
{
  ZByte* obj;
  ZByte* prop;
  int len;

  if (ReadByte(0) <= 3)
    {
      obj = Obj3(arg);
      prop = machine.memory + ((obj[7]<<8)|obj[8]) + 1;
      return zscii_to_unicode(prop, &len);
    }
  else
    {
      obj = Obj4(arg);
      prop = Address((ZUWord)GetPropAddr4(obj)+1);
      return zscii_to_unicode(prop, &len);
    }
}

#include <stdarg.h>
static void tracking_print(char* format, ...)
{
  va_list ap;
  char str[512];

  va_start(ap, format);
  vsprintf(str, format, ap);
  va_end(ap);

  printf_debug(stderr, "TRACKING: %s\n", str);
}
#endif

#ifdef SUPPORT_VERSION_3
static void draw_statusbar_123(ZStack* stack)
{
  ZWord score;
  ZWord moves;
  ZByte* obj;
  ZByte* prop;
  int len;

  obj = Obj3(GetVar(16));
  prop = machine.memory + ((obj[7]<<8)|obj[8]) + 1;

  stream_flush_buffer();
  stream_buffering(0);
  
  display_set_window(1); display_set_style(0); display_set_style(8);
  display_set_colour(rc_get_background(), rc_get_foreground());

  display_set_cursor(0, 0);
  display_erase_line(1);
  display_set_cursor(2, 0);

  display_prints((int*)zscii_to_unicode(prop, &len));

  score = GetVar(17);
  moves = GetVar(18);

  display_set_cursor(50, 0);
  if (machine.memory[1]&0x2)
    {
      display_printf("Time: %2i:%02i", (score+11)%12+1, moves);
    }
  else
    {
      display_printf("Score: %i  Moves: %i", score, moves);
    }

  display_set_colour(rc_get_foreground(), rc_get_background()); display_set_style(0);
  display_set_window(0);
  stream_buffering(1);
}
#endif

inline static int true_colour(int col)
{
  switch (col)
    {
    case 0:
      return 0x0000;
    case 1:
      return 0x001f;
    case 2:
      return 0x03e0;
    case 3:
      return 0x03ff;
    case 4:
      return 0x7c00;
    case 5:
      return 0x7c1f;
    case 6:
      return 0x7fe0;
    case 7:
      return 0x7fff;

    case 8:
      return 0x5ad6;
    case 9:
      return 0x4631;
    case 10:
      return 0x2d6b;
      
    case 13:
      return -4;

    default:
      return 0x0000;
    }
}

inline static int convert_colour(int col)
{
  switch (col)
    {
    case 2:
      return 0;
    case 3:
      return 1;
    case 4:
      return 2;
    case 5:
      return 3;
    case 6:
      return 4;
    case 7:
      return 5;
    case 8:
      return 6;
    case 9:
      return 7;
    case 10:
      return 8;
    case 11:
      return 9;
    case 12:
      return 10;
    case 1:
      return -1;
    case 0:
      return -2;
    case -1:
      return -3;

    default:
      zmachine_warning("Colour %i out of range", col);
      return -1;
    }
}

char save_fname[256] = "savefile.qut";
char script_fname[256] = "script.txt";

#if WINDOW_SYSTEM != 3 && WINDOW_SYSTEM !=4
static void get_fname(char* name, int len, int save)
{
#if WINDOW_SYSTEM != 2
  int fname[256];
  int x, y;

  static const int file[] = { 'F', 'i', 'l', 'e', ':', ' ', 0 };

  for (x=0; name[x] != 0; x++)
    fname[x] = name[x];
  fname[x] = 0;
  if (len > 255)
    len = 255;
  len -= strlen(rc_get_savedir())+1;
    
  stream_prints(file);
  stream_readline(fname, len, 0);

  if (fname[0] != '/')
    {
      strcpy(name, rc_get_savedir());
      strcat(name, "/");
    }
  else
    name[0] = 0;

  for (x=0; name[x] != 0; x++);
  for (y=0; fname[y] != 0; y++, x++)
    name[x] = fname[y];
  name[x] = 0;
#else
  char fname[256];
  OPENFILENAME fn;
  static char filter[] = "Quetzal files (*.qut)\0*.qut\0Data files (*.dat)\0*.dat\0Text files (*.txt)\0*.txt\0All files (*.*)\0*.*\0\0";
  BOOL result;
  int x;

  strcpy(fname, name);
  
  fn.lStructSize       = sizeof(fn);
  fn.hwndOwner         = mainwin;
  fn.hInstance         = NULL;
  fn.lpstrFilter       = filter;
  fn.lpstrCustomFilter = NULL;
  fn.nFilterIndex      = 1;
  fn.lpstrFile         = fname;
  fn.nMaxFile          = 256;
  fn.lpstrFileTitle    = NULL;
  fn.lpstrInitialDir   = rc_get_savedir();
  fn.lpstrTitle        = NULL;
  fn.nFileOffset       = 0;
  fn.nFileExtension    = 0;
  fn.Flags             = OFN_HIDEREADONLY;
  fn.lpstrDefExt       = "qut";

  for (x=0; x<strlen(fname); x++)
    {
      if (fname[x] == '\\')
	{
	  fn.nFileOffset = x+1;
	  fn.lpstrInitialDir = NULL;
	}
    }

  for (x=0; x<strlen(fname); x++)
    {
      if (fname[x] == '.')
	fn.nFileExtension = x+1;
    }

  if (fn.nFileExtension != 0)
    {
      char* ext;

      ext = fname + fn.nFileExtension;

      if (strcmp(ext, "qut") == 0)
	{
	  fn.nFilterIndex = 1;
	}
      else if (strcmp(ext, "dat") == 0)
	{
	  fn.nFilterIndex = 2;
	}
      else if (strcmp(ext, "txt") == 0)
	{
	  fn.nFilterIndex = 3;
	}
      else
	{
	  fn.nFilterIndex = 4;
	}
    }
  
  if (save)
    result = GetSaveFileName(&fn);
  else
    result = GetOpenFileName(&fn);

  if (result)
    {
      strcpy(name, fn.lpstrFile);
    }
  else
    {
      strcpy(name, "");
    }
#endif
}
#endif

#if WINDOW_SYSTEM != 3 && WINDOW_SYSTEM != 4
ZFile* get_file_write(int* fsize,
		      char* save_fname,
                      ZFile_type purpose)
{
  int fs, ok;

  {
    ok = 1;
    get_fname(save_fname, 255, 1);

    fs = get_file_size(save_fname);
    
    if (fs != -1)
      {
	int yn[5];
	
	yn[0] = 0;
	ok = 0;
	stream_printf("That file already exists!\nAre you sure? (y/N) ");
	stream_readline(yn, 1, 0);
	
	if (unicode_to_lower(yn[0]) == 'y')
	  ok = 1;
	else
	  {
	    return NULL;
	  }
      }
  }
  while (!ok);

  if (fsize != NULL)
    (*fsize) = fs;

  return open_file_write(save_fname);
}

ZFile* get_file_read(int* fsize,
		     char* save_fname,
                     ZFile_type purpose)
{
  int fs;

  get_fname(save_fname, 255, 0);
  
  fs = get_file_size(save_fname);

  if (fsize != NULL)
    (*fsize) = fs;

  return open_file(save_fname);
}
#endif

#if defined(SUPPORT_VERSION_4) || defined(SUPPORT_VERSION_3)
static int save_1234(ZDWord  pc,
		     ZStack* stack,
		     int     st)
{
  ZWord tmp;
  ZFile* f;

  stream_printf("\nPlease supply a filename for save\n");
  f = get_file_write(NULL, save_fname, ZFile_save);
  
  if (st >= 0)
    store(stack, st, 2);

  if (state_save(f, stack, pc))
    {
      if (st == 0)
	tmp = GetVar(st);
      return 1;
    }

  if (state_fail())
    stream_printf("(Save failed, reason: %s)\n", state_fail());
  else
    stream_printf("(Save failed, reason unknown)\n");

  if (st == 0)
    tmp = GetVar(st);
  return 0;
}

static int restore_1234(ZDWord* pc, ZStack* stack)
{
  ZFile* f;
  ZDWord sz;

  stream_printf("\nPlease supply a filename for restore\n");
  f = get_file_read(&sz, save_fname, ZFile_save);
  
  if (state_load(f, sz, stack, pc))
    {
      restart_machine();
      return 1;
    }

  if (state_fail())
    stream_printf("(Restore failed, reason: %s)\n", state_fail());
  else
    stream_printf("(Restore failed, reason unknown)\n");
  
  return 0;
}
#endif

static void zcode_op_output_stream(ZStack* stack,
				   ZArgblock* args)
{
  ZByte* mem;
  ZWord w;

  stream_flush_buffer();
  
  switch (args->arg[0])
    {
    case 0:
      return;
      
    case 1:
      machine.screen_on = 1;
      break;
    case -1:
      machine.screen_on = 0;
      break;

    case 2:
      if (machine.transcript_file == NULL)
	{
	  machine.transcript_file = get_file_write(NULL, script_fname, ZFile_transcript);
	  write_stringf(machine.transcript_file, "*** Transcript generated by Zoom\n\n");	
	}

      if (machine.transcript_file != NULL) {
	machine.transcript_on = 1;

	w = Word(ZH_flags2);
	w |= 1;
	machine.memory[ZH_flags2] = w>>8;
	machine.memory[ZH_flags2+1] = w;
      }
      break;
    case -2:
      machine.transcript_on = 0;

      w = Word(ZH_flags2);
      w &= ~1;
      machine.memory[ZH_flags2] = w>>8;
      machine.memory[ZH_flags2+1] = w;
      break;

    case 3:
      if (args->arg[1] == 0)
	zmachine_fatal("output_stream 3 must be supplied with a memory address");
      machine.memory_on++;
      if (machine.memory_on > 16)
	zmachine_fatal("Maximum recurse level for memory redirect is 16");
      machine.memory_pos[machine.memory_on-1] = args->arg[1];
      machine.memory_width[machine.memory_on-1] = -1;

      if (args->n_args > 2)
	{
	  if (args->arg[2] >= 0)
	    machine.memory_width[machine.memory_on-1] = 
	      windows[args->arg[2]].xsize;
	  else
	    machine.memory_width[machine.memory_on-1] = -args->arg[2];
	}

      mem = Address((ZUWord)machine.memory_pos[machine.memory_on-1]);
      mem[0] = 0;
      mem[1] = 0;
      break;
    case -3:
      machine.memory_on--;
      if (machine.memory_on < 0)
	{
	  machine.memory_on = 0;
	  zmachine_warning("Tried to stop writing to memory when no memory redirect was in effect");
	}

      if (machine.memory_width[machine.memory_on] != -1)
	{
	  ZByte* lastpos;
	  int len;

	  /* Mark the last line */
	  lastpos = Address(machine.memory_pos[machine.memory_on]);
	  len = (lastpos[0]<<8)|(lastpos[1]);
	  lastpos[len+2] = 0;
	  lastpos[len+3] = 0;
	}

      break;

    case 4:
      if (machine.transcript_file == NULL)
	{
	  machine.transcript_file = get_file_write(NULL, script_fname, ZFile_recording);
	
	  if (machine.transcript_file) {
	    machine.transcript_commands = 1;
	  }
	}

      if (machine.transcript_file != NULL)
	machine.transcript_commands = 1;
      break;
      
      break;
    case -4:
      machine.transcript_commands = 0;
      break;
      
    default:
      zmachine_warning("Stream number %i not supported by this interpreter (for versions 4, 5, 7 & 8)", args->arg[0]);
    }
}

static void zcode_op_readchar(ZDWord* pc,
			      ZStack* stack,
			      ZArgblock* args,
			      int st)
{
  int chr;
  
  if (args->arg[7] != 0)
    {
      ZWord ret;
      
      ret = pop(stack);
      
      if (ret != 0)
	{
	  store(stack, st, 0);
	  return;
	}
    }

  chr = display_readchar(args->arg[1]*100);
  if (chr == 0)
    {
      if (args->arg[2] != 0)
	{
	  ZFrame* newframe;
	  
	  newframe = call_routine(pc, stack, UnpackR(args->arg[2]));
	  args->arg[7] = 1;
	  newframe->storevar  = 0;
	  newframe->flags     = 0;
	  newframe->readblock = *args;
	  newframe->readstore = st;
	  newframe->v5read    = zcode_op_readchar;
	  return;
	}
    }

  if (chr == 254 || chr == 253)
    {
      if (machine.heb != NULL && machine.heblen >= 2)
	{
	  int x,y;

	  if (machine.version != 6)
	    {
	      x = display_get_mouse_x();
	      y = display_get_mouse_y();
	    }
	  else
	    {
	      x = display_get_pix_mouse_x();
	      y = display_get_pix_mouse_y();
	    }
	  
	  machine.heb[ZHEB_xmouse]   = x>>8;
	  machine.heb[ZHEB_xmouse+1] = x;
	  machine.heb[ZHEB_ymouse]   = y>>8;
	  machine.heb[ZHEB_ymouse+1] = y;
	}
    }
  
  store(stack, st, chr);
}


static void zcode_op_aread_5678(ZDWord* pc,
				ZStack* stack,
				ZArgblock* args,
				int st)
{
  ZByte* mem;
  unsigned int* buf;
  int x;
  int bufLen;
  
  mem = machine.memory + (ZUWord) args->arg[0];

  if (((ZUWord)args->arg[0]) < 64) {
    zmachine_warning("zcode_op_aread called with a buffer in the header area!");
  }
  
  if (mem[0] <= 0) {
    zmachine_fatal("zcode_op_aread called with the memory buffer size set to %i", mem[0]);
  }
  
  if (mem[1] > mem[0]) {
    zmachine_warning("zcode_op_aread called with an invalid buffer: the number of characters the buffer already contains must be less than the total length of the buffer");
    return;
  }
  
  bufLen = mem[0];
  buf = malloc(sizeof(int)*(bufLen+1));

  if (args->arg[7] != 0)
    {
      ZWord ret;
      
      /* Returning from a timeout routine */

      ret = pop(stack);

      if (ret != 0)
	{
	  mem[1] = 0;
	  free(buf);
	  return;
	}
    }
  
  if (mem[1] != 0)
    {
      /* zmachine_warning("aread: using existing buffer (display may
       * get messed up)"); */
      
      for (x=0; x<mem[1] && x<mem[0]; x++)
	{
	  buf[x] = zscii_unicode[mem[x+2]];
	}
      buf[x] = 0;

      stream_remove_buffer((int*)buf);
    }
  else
    buf[0] = 0;

  stream_flush_buffer();

  if (Word(ZH_termtable) != 0)
    {
      unsigned char* table = NULL;
      int pos, tablelen;

      tablelen = 0;

      for (pos = Word(ZH_termtable);
	   ReadByte(pos) != 0;
	   pos++)
	{
	  if (ReadByte(pos) < 129 || (ReadByte(pos) > 154 &&
				  ReadByte(pos) < 252))
	    {
	      zmachine_warning("Only characters in the range 129-154 (and 252-255) are valid terminating characters");
	    }
	  table = realloc(table, tablelen+2);
	  table[tablelen++] = ReadByte(pos);
	  table[tablelen]   = 0;
	}

      display_terminating(table);
    }
  else
    display_terminating(NULL);

  if (args->arg[2] == 0)
    {
      int res;
      
      res = stream_readline((int*)buf, bufLen, 0);
      display_terminating(NULL);

      if (res == 254 || res == 253)
	{
	  if (machine.heb != NULL && machine.heblen >= 2)
	    {
	      int x,y;
	      
	      if (machine.version != 6)
		{
		  x = display_get_mouse_x();
		  y = display_get_mouse_y();
		}
	      else
		{
		  x = display_get_pix_mouse_x();
		  y = display_get_pix_mouse_y();
		}
	      
	      machine.heb[ZHEB_xmouse]   = x>>8;
	      machine.heb[ZHEB_xmouse+1] = x;
	      machine.heb[ZHEB_ymouse]   = y>>8;
	      machine.heb[ZHEB_ymouse+1] = y;
	    }
	}

      store(stack, st, res);
    }
  else
    {
      int res;

      res = stream_readline((int*)buf, bufLen, args->arg[2]*100);
      display_terminating(NULL);
      store(stack, st, res);
      
      if (!res)
	{
	  ZFrame* newframe;
	  int x;

	  mem[1] = 0;
	  for (x=0; buf[x] != 0 && x < bufLen; x++)
	    {
	      mem[1]++;
	      buf[x] = unicode_to_lower(buf[x]);
	      mem[x+2] = zscii_get_char(buf[x]);
	    }

	  newframe = call_routine(pc, stack, UnpackR(args->arg[3]));
	  args->arg[7] = 1;
	  newframe->storevar  = 0;
	  newframe->flags     = 0;
	  newframe->readblock = *args;
	  newframe->readstore = st;
	  newframe->v5read    = zcode_op_aread_5678;
	  free(buf);
	  return;
	}
      else
	{
	  if (res == 254 || res == 253)
	    {
	      if (machine.heb != NULL && machine.heblen >= 2)
		{
		  int x,y;

		  if (machine.version != 6)
		    {
		      x = display_get_mouse_x();
		      y = display_get_mouse_y();
		    }
		  else
		    {
		      x = display_get_pix_mouse_x();
		      y = display_get_pix_mouse_y();
		    }
		  
		  machine.heb[ZHEB_xmouse]   = x>>8;
		  machine.heb[ZHEB_xmouse+1] = x;
		  machine.heb[ZHEB_ymouse]   = y>>8;
		  machine.heb[ZHEB_ymouse+1] = y;
		}
	    }
	}
    }

  mem[1] = 0;
  for (x=0; buf[x] != 0; x++)
    {
      mem[1]++;
      buf[x] = unicode_to_lower(buf[x]);
      mem[x+2] = zscii_get_char(buf[x]);
    }

  if (args->n_args > 1 && args->arg[1] != 0)
    {
      tokenise_string(buf,
		      Word(ZH_dict),
		      Address((ZUWord) args->arg[1]),
		      0,
		      2);

#ifdef DEBUG
      {
	ZByte* tokbuf;
	tokbuf = Address((ZUWord)args->arg[1]);
	printf_debug("Dump of parse buffer $%x\n", args->arg[1]);
	for (x=0; x<tokbuf[1]; x++)
	  {
	    printf_debug("  Token $%x%x word at %i, length %i\n",
			 tokbuf[2+x*4],
			 tokbuf[3+x*4],
			 tokbuf[5+x*4],
			 tokbuf[4+x*4]);
	  }
      }
#endif
    }

  free(buf);
}

static ZDWord scan_table(ZUWord word,
			 ZUWord addr,
			 ZUWord len,
			 ZUWord form)
{
  int p;

  if (form&0x80)
    {
      for (p=0; p<len; p++)
	{
	  if (Word(addr) == word)
	    return addr;
	  addr += form&0x7f;
	}
    }
  else
    {
      for (p=0; p<len; p++)
	{
	  if (ReadByte(addr) == word)
	    return addr;
	  addr += form&0x7f;
	}
    }

  return -1;
}

static void zcode_op_sread_4(ZDWord* pc,
			     ZStack* stack,
			     ZArgblock* args)
{
  ZByte* mem;
  static int* buf;
  int x;

  stream_flush_buffer();

  mem = machine.memory + (ZUWord) args->arg[0];

  if (args->arg[7] != 0)
    {
      ZWord ret;
      
      /* Returning from a timeout routine */

      ret = pop(stack);

      if (ret != 0)
	{
	  mem[1] = 0;
	  return;
	}
    }
  else
    {
      buf = malloc(sizeof(int)*(mem[0]+1));
      buf[0] = 0;
    }
  
  if (args->arg[2] == 0)
    {
      stream_readline(buf, mem[0], 0);
    }
  else
    {
      int res;
      
      res = stream_readline(buf, mem[0], args->arg[2]*100);
      
      if (!res)
	{
	  ZFrame* newframe;
	  int x;

	  for (x=0; buf[x] != 0; x++)
	    {
	      buf[x] = unicode_to_lower(buf[x]);
	      mem[x+1] = zscii_get_char(buf[x]);
	    }
	  mem[x+1] = 0;

	  newframe = call_routine(pc, stack, UnpackR(args->arg[3]));
	  args->arg[7] = 1;
	  newframe->storevar  = 0;
	  newframe->flags     = 0;
	  newframe->readblock = *args;
	  newframe->v4read    = zcode_op_sread_4;
	  return;
	}
    }

  for (x=0; buf[x] != 0; x++)
    {
      buf[x] = unicode_to_lower(buf[x]);
      mem[x+1] = zscii_get_char(buf[x]);
    }
  mem[x+1] = 0;

  if (args->n_args > 1)
    {
      tokenise_string((int*)buf,
		      Word(ZH_dict),
		      machine.memory + (ZUWord) args->arg[1],
		      0,
		      1);

#ifdef DEBUG
      {
	ZByte* tokbuf;
	tokbuf = machine.memory + (ZUWord) args->arg[1];
	for (x=0; x<tokbuf[1]; x++)
	  {
	    printf_debug("Token $%x%x word at %i, length %i\n",
			 tokbuf[2+x*4],
			 tokbuf[3+x*4],
			 tokbuf[5+x*4],
			 tokbuf[4+x*4]);
	  }
      }
#endif
    }

  free(buf);
}

/***                           ----// 888 \\----                           ***/
/* Version 6 utilities */
#ifdef SUPPORT_VERSION_6

static int newline_function(const int* remaining, int rem_len);

void zcode_v6_initialise(void)
{
  int x;
  
  machine.dinfo = display_get_info();

  for (x=0; x<8; x++)
    {
      v6_set_window(x);

      windows[x].wrapping   = 1;
      windows[x].scrolling  = 1;
      windows[x].buffering  = 1;
      windows[x].transcript = 0;
      windows[x].x = windows[x].y = 1;
      windows[x].xsize = machine.dinfo->width; 
      windows[x].ysize = machine.dinfo->height;

      windows[x].font_num = 0;

      v6_set_style(0);
      windows[x].style = 0;
      v6_set_colours(machine.dinfo->fore, machine.dinfo->back);
      windows[x].colour = ((machine.dinfo->back+2)<<8)|(machine.dinfo->fore+2);
      windows[x].fg_true = true_colour(machine.dinfo->fore);
      windows[x].bg_true = true_colour(machine.dinfo->back);
    }

  windows[0].wrapping = 1;

  v6_set_newline_function(newline_function);
}

static int*  pending_text = NULL;
static int   pending_len;

static void newline_return(ZDWord*    pc,
			   ZStack*    stack,
			   ZArgblock* args,
			   int        st)
{
  if (pending_text != NULL)
    {
      int* oldtext;

      oldtext = pending_text; pending_text = NULL;
      v6_prints(oldtext);
      free(oldtext);
    }

  v6_set_newline_function(newline_function);
}

static int newline_function(const int* remaining,
			    int   rem_len)
{
  int win;

  win = v6_get_window();

  v6_set_newline_function(NULL);

  if (windows[win].countdown > 0)
    {
      windows[win].countdown--;

      if (windows[win].countdown == 0)
	{
	  ZFrame* newframe;

	  if (pending_text != NULL)
	    zmachine_fatal("Programmer is a spoon");

	  pending_text = malloc((rem_len+1)*sizeof(int));
	  pending_len  = rem_len;
	  memcpy(pending_text, remaining, rem_len*sizeof(int));
	  pending_text[rem_len] = 0;

	  newframe = call_routine(&machine.zpc, &machine.stack,
				  UnpackR(windows[win].newline_routine));
	  newframe->storevar = 255;
	  newframe->discard  = 1;
	  newframe->end_func = 1;

	  zmachine_runsome(machine.version, machine.zpc);
	  newline_return(NULL, NULL, NULL, 0);
	  
	  return 2;
	}

      if (windows[win].line_count > -999)
	{
	  v6_set_newline_function(newline_function);
	  windows[win].line_count--;
	  if (windows[win].line_count == 0)
	    return 1;
	  return 0;
	}
      else if (windows[win].line_count == -999)
	{
	  v6_set_newline_function(newline_function);
	  return 0;
	}
    }
  v6_set_newline_function(newline_function);
  return -1;
}

static inline void zcode_setup_window(int window)
{
  v6_set_window(window);
  v6_define_window(window,
		   windows[window].x, windows[window].y,
		   windows[window].leftmar, 
		   windows[window].rightmar,
		   windows[window].xsize, windows[window].ysize);
  v6_set_scroll(windows[window].scrolling);
  v6_set_more(window, windows[window].scrolling);
  v6_set_wrap(window, windows[window].wrapping);
  if (windows[window].line_count == -999)
    v6_set_more(window, 0);
  stream_buffering(windows[window].buffering);

#ifdef DEBUG
  printf_debug("Window %i setup: scrolling %i, buffering %i, line count %i\n",
	       window,
	       windows[window].scrolling,
	       windows[window].buffering,
	       windows[window].line_count);
#endif
}

static inline int zcode_v6_push_stack(ZStack* stack,
				      ZUWord  stk,
				      ZUWord  value)
{
  ZByte* s;
  ZByte* val;
  ZUWord len;
  
  if (stk == 0)
    {
      push(stack, value);
      return 1;
    }

  s = Address(stk);
  len = (s[0]<<8)|s[1];

  if (len <= 1)
    return 0;

  val = s + (len*2);
  val[0] = value>>8;
  val[1] = value;
  
  len--;
  s[0] = len>>8;
  s[1] = len;

  return 1;
}

static inline int v6_window(int win)
{
  if (win > 7)
    zmachine_fatal("No such window: %i", win);
  if (win == -3)
    win = v6_get_window();
  if (win < -2)
    zmachine_fatal("Bad value for window: %i", win);
  
  return win;
}
#endif

/***                           ----// 888 \\----                           ***/
/* The interpreter itself */

#include "varop.h"

#if defined(SUPPORT_VERSION_4) || defined(SUPPORT_VERSION_5) || defined(SUPPORT_VERSION_6) || defined(SUPPORT_VERSION_7) || defined(SUPPORT_VERSION_8)
/* #include "doubleop.h" -- This gets far too large */

/*
 * (non-specialised, slow, version)
 */
int zmachine_decode_doubleop(ZStack* stack,
			     ZByte* param,
			     ZArgblock* argblock)
{
  ZUWord params;
  int padding = 2;
  int x, type;

  params = (param[0]<<8)|param[1];
  x=0;
  argblock->n_args = 0;
  do
    {
      type = (params>>(14-x*2))&3;

      switch (type)
	{
	case 0:
	  argblock->arg[x] = (param[padding]<<8)|param[padding+1];
	  padding+=2;
	  argblock->n_args++;
	  break;
	  
	case 1:
	  argblock->arg[x] = param[padding];
	  padding+=1;
	  argblock->n_args++;
	  break;
	  
	case 2:
	  argblock->arg[x] = GetVar(param[padding]);
	  padding+=1;
	  argblock->n_args++;
	  break;
	}

      x++;
    }
  while (type != 3 && x<8);

  return padding-2;
}
#endif

static clock_t start_clock, end_clock;

void zmachine_run(const int version,
		  char* savefile)
{
#ifdef GLOBAL_PC
# define pc machine.zpc
#else
  ZDWord         pc;
#endif
  ZStack*        stack;

  int x;

  pc    = GetWord(machine.header, ZH_initpc);
  stack = &machine.stack;

  machine.dinfo = display_get_info();
#if defined(SUPPORT_VERSION_6)
  if (version == 6)
    {
      zcode_v6_initialise();
    }
#endif

  zmachine_setup_header();

  for (x=0; x<UNDO_LEVEL; x++)
    {
      machine.undo[x] = NULL;
    }

#if defined(SUPPORT_VERSION_6)
  if (version == 6)
    {
      call_routine(&pc, stack,
		   (4*GetWord(machine.header, ZH_initpc)) +
		   machine.routine_offset);
    }
#endif

  switch (version)
    {
#if defined(SUPPORT_VERSION_4) || defined(SUPPORT_VERSION_5)
    case 4:
    case 5:
      machine.packtype = packed_v4;
      break;
#ifdef SUPPORT_VERSION_5
    case 8:
      machine.packtype = packed_v8;
      break;
#endif
#endif

#if defined(SUPPORT_VERSION_5) || defined(SUPPORT_VERSION_6)
    case 6:
    case 7:
      machine.packtype = packed_v6;
      machine.routine_offset = 8*Word(ZH_routines);
      machine.string_offset = 8*Word(ZH_staticstrings);
      break;
#endif

#if defined(SUPPORT_VERSION_3)
    case 3:
      machine.packtype = packed_v3;
      break;
#endif

    default:
      zmachine_fatal("Version %i not supported", version);
    }

  if (savefile != NULL)
    {
      ZFile* zf;
      ZDWord sz;

      sz = get_file_size(savefile);
      zf = open_file(savefile);
      if (state_load(zf, sz, stack, &pc))
	{
	  zmachine_setup_header();
	}
      else
	{
	  if (state_fail())
	    stream_printf("(Restore failed, reason: %s)\n", state_fail());
	  else
	    stream_printf("(Restore failed, reason unknown)\n");
	  display_readchar(5000);
	}
    }

  machine.version = version;

  zmachine_runsome(version, pc);
}

void zmachine_runsome(const int version, 
		      int start_counter)
{
#ifndef GLOBAL_PC
  ZDWord         pc;
#endif
  /* 
   * 'register' here is intended as a hint to the optimiser... I list these
   * things in order of priority, so a compiler with a shortage of registers 
   * can behave appropriately.
   */
  register ZByte     instr;
  register int       st     = 0;
  int                padding= 0;
  int                tmp;
  int                negate = 0;
  int                result = 0;
  ZDWord             branch = 0;
  /* Historical reasons */
#define arg1 argblock.arg[0]
#define arg2 argblock.arg[1]
#define uarg1 ((ZUWord)argblock.arg[0])
#define uarg2 ((ZUWord)argblock.arg[1])
  ZArgblock          argblock;
  register ZStack*   stack;
  int *              string;

  int x;
  
  /*
   * PowerMac Dual 1.25Ghz:
   *
   * Without computed gotos:
   * ZMark version 0.2, by Andrew Hunter
   * 
   * IntMark1: 2.18 secs
   * IntMark2: 2.29 secs
   * JumpMark: 2.96 secs
   * CallMark: 0.38 secs
   * NopMark: 1.09 secs
   * 
   * With computed gotos:
   * 
   * ZMark version 0.2, by Andrew Hunter
   * 
   * IntMark1: 2.23 secs
   * IntMark2: 2.30 secs
   * JumpMark: 3.16 secs
   * CallMark: 0.40 secs
   * NopMark: 1.32 secs
   *
   * (Hmm, gcc 3.3 is a major improvement over 2.95: NopMark used to be 5x slower with computed gotos)
   *
   * Bizarrely, speed seems to have improved now I've added the sigusr1 stuff
   */
  
  /*
   * The 'computed gotos' style interpreter is faster to compile, but can 
   * run a bit slower under certain circumstances. Instead of switch statements,
   * we use tables of gotos and then a large list of labels. This is non-portable
   * to other compilers (but Zoom won't compile without gcc at the moment anyway).
   *
   * I'm going to look into improving this
   */

#ifdef HAVE_COMPUTED_GOTOS
# define TABLES_ONLY
# include "interp_z3.h"
# include "interp_z4.h"
# include "interp_z5.h"
# include "interp_z6.h"
# undef TABLES_ONLY

  register const void** decode;
  const void** decode_ext;
  register const void** exec;
  const void** exec_ext;
#endif

  pc = start_counter;
  stack = &machine.stack;
	  
#ifdef HAVE_COMPUTED_GOTOS
  switch (version)
    {
# ifdef SUPPORT_VERSION_3
    case 3:
      decode = decode_v3;
      decode_ext = decode_ext_v3;
      exec = exec_v3;
      exec_ext = exec_ext_v3;
      break;
# endif
# ifdef SUPPORT_VERSION_3
    case 4:
      decode = decode_v4;
      decode_ext = decode_ext_v4;
      exec = exec_v4;
      exec_ext = exec_ext_v4;
      break;
# endif
# ifdef SUPPORT_VERSION_3
    case 5:
    case 7:
    case 8:
      decode = decode_v5;
      decode_ext = decode_ext_v5;
      exec = exec_v5;
      exec_ext = exec_ext_v5;
      break;
# endif
# ifdef SUPPORT_VERSION_3
    case 6:
      decode = decode_v6;
      decode_ext = decode_ext_v6;
      exec = exec_v6;
      exec_ext = exec_ext_v6;
      break;
# endif

    default:
      zmachine_fatal("Unsupported Z-Machine version");
      return;
    }

 loop:
#ifdef REMOTE_BREAKPOINT
	  /* Really need to find a way to do this without a performance impact */
	  if (machine.force_breakpoint) {
		  machine.force_breakpoint = 0;
		  debug_set_breakpoint(pc, 1, 0);
	  }
#endif
	  
  instr = GetCode(pc);
 execute_instr:
  goto *decode[instr];

 badop:
  zmachine_fatal("Unknown opcode: %x", instr);

 execute_ext_op:
  instr = GetCode(pc+1);
  goto *decode_ext[instr];

# include "interp_gen.h"

# ifdef SUPPORT_VERSION_3
#  include "interp_z3.h"
# endif
# ifdef SUPPORT_VERSION_4
#  include "interp_z4.h"
# endif
# ifdef SUPPORT_VERSION_5
#  include "interp_z5.h"
# endif
# ifdef SUPPORT_VERSION_6
#  include "interp_z6.h"
# endif

#else
  for(;;)
    {
#ifdef REMOTE_BREAKPOINT
	  /* Really need to find a way to do this without a performance impact */
	  if (machine.force_breakpoint) {
		  machine.force_breakpoint = 0;
		  debug_set_breakpoint(pc, 1, 0);
	  }
#endif

      instr = GetCode(pc);

#ifdef DEBUG
      printf_debug("PC = %x\n", pc);
#endif

#ifdef SAFE
      if (pc < 0 || pc > machine.story_length)
	zmachine_fatal("PC set to a value outside the story file");
#endif

      /*
       * This bit is a tad confusing :-) What's going on here is that
       * first the interpreter checks for a 'general' instruction,
       * (using a specialised interpreter generated by builder)
       * common to all interpreters. If it finds one, it executes it
       * and loops. If it doesn't find one, it then checks for a
       * version-specific instruction.
       *
       * The reason this is all done with gotos rather than functions
       * is one of speed - the cost of function calls is enough to
       * negate the benefit of specialisation!
       *
       * Note that this can be specialised further; this is a
       * compromise on size and compile time. First, the specialiser
       * currently does not output specialised code for decoding 2OPs
       * in their variable form, prefering to call the decoder
       * function (this is not a big performance hit, though, as the
       * decoder itself is specialised). Second, the 'general' and
       * 'version-specific' interpreters could be combined into
       * one. Unfortunately, this rather increases code size, and only 
       * provides benefits on operations that change between versions.
       * Third, we could use different interpreters for versions 5, 7, 
       * & 8 - this would speed up manipulation of packed addresses
       * (though once again for a size penalty)
       */

    execute_instr:

#include "interp_gen.h"
      
    version:
      switch(version)
	{
#ifdef SUPPORT_VERSION_3
	case 3:
#include "interp_z3.h"
#endif
#ifdef SUPPORT_VERSION_4
	case 4:
#include "interp_z4.h"
#endif
#ifdef SUPPORT_VERSION_5
	case 5:
	case 7:
	case 8:
#include "interp_z5.h"
#endif
#ifdef SUPPORT_VERSION_6
	case 6:
#include "interp_z6.h"
#endif
	default:
	  zmachine_fatal("Unsupported version");
	}
      loop: ;
    }
#endif
}
