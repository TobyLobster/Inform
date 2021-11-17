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
 * Functions to do with the game state (save, load & undo)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <time.h>

#include "zmachine.h"
#include "state.h"
#include "file.h"
#include "../config.h"

/* #define DEBUG */

enum header_blocks
{
  IFhd = 0,
  CMem,
  UMem,
  Stks,
  IntD,
  AUTH,
  copy,
  ANNO,

  N_BLOCKS
};

static struct
{
  unsigned char* text;
  enum header_blocks num;
} blocks[N_BLOCKS] =
{
  { "IFhd", IFhd },
  { "CMem", CMem },
  { "UMem", UMem },
  { "Stks", Stks },
  { "IntD", IntD },
  { "AUTH", AUTH },
  { "(c) ", copy },
  { "ANNO", ANNO }
};

static ZByte* stacks = NULL;
static char*  detail = NULL;
static ZWord* stackpos = NULL;

static inline void push(ZStack* stack, const ZWord word)
{
  *(stack->stack_top++) = word;
  stack->stack_size--;

  if (stack->current_frame != NULL)
    stack->current_frame->frame_size++;
  
  if (stack->stack_size <= 0)
    {
      intptr_t stack_offset = stack->stack_top - stack->stack;
    
      stack->stack_total += 2048;
      if (!(stack->stack = realloc(stack->stack,
				   stack->stack_total*sizeof(ZWord))))
	{
	  zmachine_fatal("Stack overflow");
	}
      stack->stack_size += 2048;
      stack->stack_top = stack->stack + stack_offset;
    }

#ifdef DEBUG
  if (stack->current_frame)
    printf_debug("Stack: push - size now %i, frame usage %i (pushed #%x)\n",
	   stack->stack_size, stack->current_frame->frame_size,
	   stack->stack_top[-1]);
#endif
}

static int format_stacks(ZStack* stack, ZFrame* frame)
{
  int size;
  int pos;
  int x;

  size = 0;
  
  if (frame->last_frame != NULL)
    size = format_stacks(stack, frame->last_frame);

#ifdef DEBUG
  printf_debug("Compile: Formatting stack frame (%i locals, %i entries)\n", frame->nlocals, frame->frame_size);
#endif

  pos = size;
  size += 8+frame->nlocals*2+frame->frame_size*2;
  stacks = realloc(stacks, sizeof(ZByte)*((size>>8)+1)*256);

  stacks[pos]   = frame->ret>>16;
  stacks[pos+1] = frame->ret>>8;
  stacks[pos+2] = frame->ret;
  
  stacks[pos+3] = (frame->discard<<4)|frame->nlocals;
  stacks[pos+4] = frame->storevar;
  stacks[pos+5] = frame->flags;

  stacks[pos+6] = frame->frame_size>>8;
  stacks[pos+7] = frame->frame_size;

  pos += 8;

  for (x=0; x<frame->nlocals; x++)
    {
      stacks[pos+2*x]   = frame->local[x+1]>>8;
      stacks[pos+2*x+1] = frame->local[x+1];
    }

  pos = pos + 2*(frame->nlocals);
  for (x=frame->frame_size; x>0; x--)
    {
      stacks[pos++] = (*stackpos)>>8;
      stacks[pos++] = *(stackpos++);
    }

  if (pos>size)
    zmachine_fatal("Programmer is a spoon");

  return size;
}

static inline void xor_memory(void)
{
  ZDWord x,y, len;
  ZByte* page;

  for (x=0; x<machine.dynamic_ceiling; x+=1024)
    {
      len = 1024;
      if (x+1024>=machine.dynamic_ceiling)
	len = machine.dynamic_ceiling-x;
      
      page = read_block(machine.file, 
			x+machine.story_offset, 
			x+len+machine.story_offset);
      if (page == NULL)
	zmachine_fatal("ARgh");

      for(y=0; y<len; y++)
	{
	  machine.memory[y+x] ^= page[y];
	}
      
      free(page);
    }
}

struct save_state {
  int flen;
  ZByte* data;
};

static inline void wblock(ZByte* x, int len, struct save_state* state)
{
  state->flen += len;
  state->data = realloc(state->data, state->flen+16);
  memcpy(state->data + state->flen - len, x, len);
}

static inline void wdword(ZDWord w, struct save_state* state)
{
  state->flen +=4;
  state->data = realloc(state->data, state->flen+16);
  state->data[state->flen-4] = w>>24;
  state->data[state->flen-3] = w>>16;
  state->data[state->flen-2] = w>>8;
  state->data[state->flen-1] = w;
}

static inline void wword(ZUWord w, struct save_state* state)
{
  state->flen += 2;
  state->data = realloc(state->data, state->flen+16);
  state->data[state->flen-2] = w>>8;
  state->data[state->flen-1] = w;
}

static inline void wbyte(ZUWord w, struct save_state* state)
{
  state->flen += 1;
  state->data = realloc(state->data, state->flen+16);
  state->data[state->flen-1] = w;
}

ZByte* state_compile(ZStack* stack, ZDWord pc, ZDWord* len, int compress)
{
  struct save_state state;
  int size;
  char anno[256];
  time_t now;
  ZByte version;
  
  state.data = NULL;
  state.flen = 0;
  
  *len = -1;
  version = ReadByte(0);

  pc--; /*
	 * Quetzal spec is unclear on this... Experience with patched
	 * frotz suggests this is the thing to do
	 */

#ifdef SAFE
  if (version < 3)
    {
      /* Shouldn't be able to run 'em, either */
      zmachine_warning("Can't save files for versions <3");
      return NULL;
    }
#endif
  
  /* header */
  wblock(blocks[IFhd].text, 4, &state);
  wdword(13, &state);
  wword(Word(ZH_release), &state);
  wblock(Address(ZH_serial), 6, &state);
  wword(Word(ZH_checksum), &state);
#ifdef DEBUG
  printf_debug("Save: release %i, checksum %i\n", Word(ZH_release), Word(ZH_checksum));
#endif
  wbyte(pc>>16, &state);
  wbyte(pc>>8, &state);
  wbyte(pc, &state);

  wbyte(0, &state);

  /* Dynamic memory */
  if (compress)
    {
      ZByte* comp = NULL;
      int clen = 0;
      int x, run;
      ZByte running;

#ifdef DEBUG
      printf_debug("Compile: compressing memory from 0 to %x\n", machine.dynamic_ceiling);
#endif
      
      xor_memory();

      run = 0;
      for (x=0; x<machine.dynamic_ceiling; x++)
	{
	  /*
	   * Hmm, I got this bit wrong first time around, thinking
	   * that there was *three* bytes after a 0 (a length and a
	   * type). 
	   */
	  running = machine.memory[x];

	  if (running == 0)
	    run++;
	  else
	    {
	      if (run > 0)
		{
		  while (run > 256)
		    {
		      comp = realloc(comp, clen+2);
		      comp[clen++] = 0;
		      comp[clen++] = 0xff;
		      run -= 256;
		    }
#ifdef SAFE
		  if (run < 0)
		    zmachine_fatal("Programmer is a spoon");
#endif
		  if (run > 0)
		    {
		      comp = realloc(comp, clen+2);
		      comp[clen++] = 0;
		      comp[clen++] = run-1;
		    }

		  run = 0;
		}
	      
	      comp = realloc(comp, clen+1);
	      comp[clen++] = running;
	    }
	}

      wblock(blocks[CMem].text, 4, &state);
      wdword(clen, &state);
      wblock(comp, clen, &state);

      if (clen&1)
	wbyte(0, &state);

      free(comp);
      
      xor_memory();
    }
  else
    {
#ifdef DEBUG
      printf_debug("Compile: storing memory from 0 to %x\n", machine.dynamic_ceiling);
#endif
      wblock(blocks[UMem].text, 4, &state);
      wdword(machine.dynamic_ceiling, &state);
      wblock(Address(0), machine.dynamic_ceiling, &state);

      if (machine.dynamic_ceiling&1)
	wbyte(0, &state);
    }

  /* Stack frames */
  stackpos = stack->stack;
  size = format_stacks(stack, stack->current_frame);
  wblock(blocks[Stks].text, 4, &state);
  wdword(size, &state);
  wblock(stacks, size, &state);

  free(stacks);
  stacks = NULL;

  /* Annotations */
  now = time(NULL);
  wblock(blocks[ANNO].text, 4, &state);
  if (version <= 3)
    {
      char score[64];

      if (machine.memory[1]&0x2)
	{
	  sprintf(score, "(Time: %2i:%02i)", (GetVar(17)+11)%12+1,
		  GetVar(18));
	}
      else
	{
	  sprintf(score, "(Score: %i Moves %i)", GetVar(17),
		  GetVar(18));
	}
      sprintf(anno, "Version %i game, saved from Zoom version "
	      VERSION " @%s\n%s", version, ctime(&now), score);
    }
  else
    {
      sprintf(anno, "Version %i game, saved from Zoom version "
	      VERSION " @%s", version, ctime(&now));
    }
  wdword((int)strlen(anno), &state);
  wblock(anno, (int)strlen(anno), &state);
  if (strlen(anno)&1)
    wbyte(0, &state);
  
  *len = state.flen;
  return state.data;
}
  
int state_save(ZFile* f, ZStack* stack, ZDWord pc)
{
  ZDWord flen;
  ZByte* data;

  detail = NULL;

  if (!f)
    return 0;

  data = state_compile(stack, pc, &flen, 1);

  if (data == NULL)
    return 0;
  
  /* Output the file itself */
  write_block(f, (unsigned char*)"FORM", 4);
  write_dword(f, flen+4);
  write_block(f, (unsigned char*)"IFZS", 4);
  write_block(f, data, flen); 
  close_file(f);

  free(data);
  data = NULL;
  flen = 0;
  
  return 1;
}

int state_decompile(ZByte* st, ZStack* stack, ZDWord* pc, ZDWord len)
{
  static struct
  {
    unsigned char text[4];
    ZByte* pos;
    ZDWord len;
  } blocks[N_BLOCKS] =
    {
      { "IFhd", 0,0 },
      { "CMem", 0,0 },
      { "UMem", 0,0 },
      { "Stks", 0,0 },
      { "IntD", 0,0 },
      { "AUTH", 0,0 },
      { "(c) ", 0,0 },
      { "ANNO", 0,0 }
    };
  ZDWord pos;
  int x;

  for (x=0; x<N_BLOCKS; x++)
    {
      blocks[x].pos = NULL;
      blocks[x].len = 0;
    }
  
  pos = 4;

  while (pos<len)
    {
      ZDWord blen;
      
      blen = (st[pos]<<24) | (st[pos+1]<<16) | (st[pos+2]<<8) | (st[pos+3]);
#ifdef DEBUG
      printf_debug("Decompile: found block ");
      {
	int x;
	for (x=-4; x<0; x++) printf_debug("%c", st[pos+x]);
      }
      printf_debug("\n");
#endif

      for (x=0; x<N_BLOCKS; x++)
	{
	  if (memcmp(st + pos - 4, blocks[x].text, 4) == 0)
	    {
	      blocks[x].pos = st + pos+4;
	      blocks[x].len = blen;
	    }
	}

      if ((blen&1) == 1)
	blen++;
      pos += blen+8;
    }

  /* Check that all required blocks are present and correct */
  if (blocks[IFhd].pos == 0 ||
      (blocks[CMem].pos == 0 && blocks[UMem].pos == 0) ||
      blocks[Stks].pos == 0)
    {
#ifdef DEBUG
      printf_debug("Decompile: missing block\n");
      printf_debug("IFhd = %i\n", blocks[IFhd].pos);
      printf_debug("CMem = %i\n", blocks[CMem].pos);
      printf_debug("UMem = %i\n", blocks[UMem].pos);
      printf_debug("Stks = %i\n", blocks[Stks].pos);
#endif
      detail = "Required block missing from savefile";
      return 0;
    }

  /* Check that this file corresponds to the file that we are running */
  {
    ZUWord release, checksum;

    release = (blocks[IFhd].pos[0]<<8)|blocks[IFhd].pos[1];
    checksum = (blocks[IFhd].pos[8]<<8)|blocks[IFhd].pos[9];

    if ((ZUWord)Word(ZH_release) != release ||
	(ZUWord)Word(ZH_checksum) != checksum)
      {
#ifdef DEBUG
	printf_debug("Decompile: bad release/checksum (savefile rel=%i, our rel=%i, savefile checksum=%i, our checksum=%i)\n",
	       release, Word(ZH_release), checksum, Word(ZH_checksum));
#endif
	detail = "Savefile is not for this game";
	return 0;
      }

    if (memcmp(Address(ZH_serial), blocks[IFhd].pos + 2, 6) != 0)
      {
#ifdef DEBUG
	printf_debug("Decompile: bad serial number");
#endif
	detail = "Savefile is not for this game";
	return 0;
      }

    if (blocks[UMem].pos != NULL && blocks[UMem].len != machine.dynamic_ceiling)
      {
#ifdef DEBUG
	printf_debug("Decompile: Memory sizes do not match");
#endif
	detail = "Corrupt savefile";
	return 0;
      }

    if (blocks[IFhd].len != 13)
      {
#ifdef DEBUG
	printf_debug("Decompile: IFhd len is %i", blocks[IFhd].len);
#endif
	detail = "Savefile is not compatible quetzal 1.3b format";
	return 0;
      }
  }

  /*
   * This file is looking good, time to go for it and load the thing
   *
   * <- This is the point of no return - if the file turns out to be bad 
   * here, for example by having duff compressed data, the restore
   * will not be sucessful.
   */

  if (blocks[UMem].pos != NULL)
    {
      /* UMem is easy :-)) */
      memcpy(Address(0), blocks[UMem].pos, blocks[UMem].len);
    }
  else
    {
      /* CMem is all yuck :-( */
      ZDWord x, adr;
      ZByte* cmem;

      cmem = blocks[CMem].pos;
      adr = 0;
      
      for (x=0; x<blocks[CMem].len; x++)
	{
	  if (cmem[x] == 0)
	    {
	      ZDWord len, y;

	      if (x+1 == blocks[CMem].len)
		zmachine_fatal("Corrupt CMem block");

	      len = cmem[++x]+1;
	      for (y=0; y<len; y++)
		machine.memory[adr++] = 0;
	    }
	  else
	    machine.memory[adr++] = cmem[x];
	}

      if (adr > machine.dynamic_ceiling)
	{
	  zmachine_fatal("Compressed memory is larger than dynamic memory (by %i bytes)", adr - machine.dynamic_ceiling);
	}
      while (adr < machine.dynamic_ceiling)
	{
	  machine.memory[adr++] = 0;
	}

      xor_memory();
    }

  /* Clean out all the old frames */
  while (stack->current_frame != NULL)
    {
      ZFrame* oldframe;

      oldframe = stack->current_frame;
      stack->current_frame = oldframe->last_frame;

      stack->stack_size += oldframe->frame_size;
      stack->stack_top  -= oldframe->frame_size;
      
      free(oldframe);
    }

  /* Load in the new frames */
  {
    ZByte* frame;
    ZDWord pos;

    frame = blocks[Stks].pos;
    pos = 0;
    
    while (pos < blocks[Stks].len)
      {
	ZDWord  pc;
	ZByte   flags;
	ZByte   store;
	ZByte   args;
	ZUWord  frame_size;
	ZFrame* newframe;
	int x;

	pc         = (frame[pos]<<16)|(frame[pos+1]<<8)|frame[pos+2];
	flags      = frame[pos+3];
	store      = frame[pos+4];
	args       = frame[pos+5];
	frame_size = (frame[pos+6]<<8)|frame[pos+7];

	newframe = malloc(sizeof(ZFrame));

	newframe->ret          = pc;
	newframe->flags        = args;
	newframe->storevar     = store;
	newframe->discard      = (flags&0x10)!=0;
	newframe->nlocals      = flags&0x0f;
	newframe->frame_size   = 0;
	newframe->v4read       = NULL;
	newframe->v5read       = NULL;
	newframe->break_on_return = 0;
	newframe->end_func     = 0;
	if (stack->current_frame != NULL)
	  newframe->frame_num  = stack->current_frame->frame_num+1;
	else
	  newframe->frame_num  = 0;
	newframe->last_frame   = stack->current_frame;

	stack->current_frame   = newframe;

	pos += 8;
	for (x=0; x<newframe->nlocals; x++)
	  {
	    newframe->local[x+1] = (frame[pos]<<8)|frame[pos+1];
	    pos+=2;
	  }
	for (x=0; x<frame_size; x++)
	  {
	    push(stack, (frame[pos]<<8)|frame[pos+1]);
	    pos += 2;
	  }
      }
  }

  /* Finally, restore PC */
  *pc = (blocks[IFhd].pos[10]<<16)|
    (blocks[IFhd].pos[11]<<8)|
    blocks[IFhd].pos[12];
  (*pc)++; /* Quetzal unclear on this */
  
  return 1;
}

int state_load(ZFile* f, ZDWord fsize,  ZStack* stack, ZDWord* pc)
{
  ZByte* file;
  ZDWord formsize;

  detail = NULL;

  if (f == NULL)
    {
      detail = "Unable to open file";
      return 0;
    }

  if (fsize < 0)
    {
      detail = "Savefile not found";
      close_file(f);
      return 0;
    }
  if (fsize < 8)
    {
      detail = "Savefile is WAY too small";
      close_file(f);
      return 0;
    }

  file = read_block(f, 0, fsize);
  if (file == NULL)
    {
      detail = "Unable to read from file";
      return 0;
    }
  close_file(f);

  if (memcmp(file, "FORM", 4) != 0 ||
      memcmp(file + 8, "IFZS", 4) != 0)
    {
#ifdef DEBUG
      printf_debug("Load: Not a quetzal file\n");
#endif
      detail = "Not a quetzal file";
      return 0;
    }
  formsize = (file[4]<<24)|(file[5]<<16)|(file[6]<<8)|file[7];
  if (formsize > fsize-8)
    {
#ifdef DEBUG
      printf_debug("Load: File is truncated\n");
#endif
      detail = "File is truncated";
      return 0;
    }
  if (formsize < fsize-8)
    {
      zmachine_warning("Garbage at end of quetzal file");
    }
  
  return state_decompile(file + 12, stack, pc, formsize-4);
}

char* state_fail(void)
{
  return detail;
}
