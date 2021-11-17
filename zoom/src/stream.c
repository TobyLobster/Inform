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
 * Deal with input/output streams
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>

#include "zmachine.h"
#include "stream.h"
#include "display.h"
#include "zscii.h"
#include "v6display.h"

static int  buffering = 1;
static int  buflen    = 0;
static int  bufpos    = 0;
static int* buffer = NULL;

extern int* zscii_unicode;
extern int  zscii_unicode_table[];

static void prints_reformat_width(int len)
{
  int* text;
  int split;
  ZByte* mem;
  int x;

  mem = Address(machine.memory_pos[machine.memory_on-1]);

  do 
    {
      text = malloc(sizeof(int)*len);
      for (x=0; x<len; x++)
	text[x] = zscii_unicode[mem[x+2]];
      
      split = v6_split_point(text, len, 
			     machine.memory_width[machine.memory_on-1],
			     NULL);
      free(text);
      
      if (split != len)
	{
	  mem[0] = split>>8;
	  mem[1] = split;
	  
	  for (x=len; x>split; x--)
	    {
	      mem[x+1+2] = mem[x-1+2];
	    }
	  
	  machine.memory_pos[machine.memory_on-1] += split+2;
	  mem += split+2;
	  len -= split;
	  
	  mem[0] = len>>8;
	  mem[1] = len;

#ifdef DEBUG
	  printf_debug("Stream: memory stream length is now %i (reformatting width)\n", len);
#endif
	}
    }
  while (split != len);
}

static void prints(const unsigned int* const s)
{
  if (machine.memory_on)
    {
      ZByte* mem;
      ZUWord len;
      int x;

      len = Word(machine.memory_pos[machine.memory_on-1]);
      mem = Address(machine.memory_pos[machine.memory_on-1]);
      
      if (machine.memory_width[machine.memory_on-1] == -1)
	{
	  for (x=0; s[x] != 0; x++)
	    {
	      if (s[x] == 10)
		mem[(len++)+2] = 13;
	      else
		mem[(len++)+2] = zscii_get_char(s[x]);
	    }

	  mem[0] = len>>8;
	  mem[1] = len;
	  
#ifdef DEBUG
	  printf_debug("Stream: memory stream length is now %i (>", len);
	  for (x=0; x<len; x++) {
	    printf_debug("%c", mem[x]);
	  }
	  printf("<)\n");
#endif
	}
      else
	{
	  for (x=0; s[x] !=0; x++)
	    {
	      if (s[x] == 10 || s[x] == 13)
		{
		  /* Create a newline */
		  mem[(len++)+2] = ' ';

		  mem[0] = len>>8;
		  mem[1] = len;

		  prints_reformat_width(len);
		  mem = Address(machine.memory_pos[machine.memory_on-1]);
		  len = Word(machine.memory_pos[machine.memory_on-1]);

		  machine.memory_pos[machine.memory_on-1] += len+2;
		  mem += len+2;

		  mem[0] = 0;
		  mem[1] = 0;

		  len = 0;
		}
	      else
		mem[(len++)+2] = zscii_get_char(s[x]);
	    }

	  mem[0] = len>>8;
	  mem[1] = len;
	  
#ifdef DEBUG
	  printf_debug("Stream: memory stream length is now %i\n", len);
#endif

	  prints_reformat_width(len);
	}

      if (machine.version == 6)
	{
	  int* text;
	  ZUWord width;

	  len = Word(machine.memory_pos[machine.memory_on-1]);
	  mem = Address(machine.memory_pos[machine.memory_on-1]);

	  text = malloc(sizeof(int)*len);
	  for (x=0; x<len; x++)
	    text[x] = mem[x+2];
	  
	  width = v6_measure_text(text, len)+1;

	  machine.memory[0x30] = width>>8;
	  machine.memory[0x31] = width;

	  free(text);
	}
      
      return;
    }

  if (machine.screen_on)
    {
      int old_style = 0;
      ZWord flags;

      flags = Word(ZH_flags2);
     
      if (flags&2)
	old_style = display_set_style(8);
      display_prints(s);
      if (flags&2)
	{
	  display_set_style(0);
	  display_set_style(old_style);
	}
    }
  if (machine.transcript_on == 1)
    {
      write_stringu(machine.transcript_file, s);
    }
}

void stream_prints(const unsigned int* s)
{
  int len, x;
  int flush;

#ifdef DEBUG
  printf_debug("Stream: received string >");
  for (x=0; s[x] != 0; x++)
    {
      printf_debug("%c", s[x]);
    }
  printf_debug("<\n");
#endif
  
  if (!buffering)
    {
#ifdef DEBUG
      printf_debug("Stream: (Buffering off)\n");
#endif

      prints(s);
      return;
    }

  for (len=0; s[len] != 0; len++);

  while (bufpos + len + 1 > buflen)
    {
      buflen += 1024;
      buffer = realloc(buffer, sizeof(int)*buflen);
    }

  flush = 0;
  for (x=0; x<len; x++)
    {
      if (s[x] == 10)
	flush = 1;
      buffer[bufpos++] = s[x];
    }
  if (flush)
    stream_flush_buffer();
}

void stream_printc(int c)
{
  if (!buffering)
    {
      int x[2];

      x[0] = c;
      x[1] = 0;

      display_prints(x);
    }
  else
    {
      if (bufpos + 2 > buflen)
	{
	  buflen+=1024;
	  buffer = realloc(buffer, sizeof(int)*buflen);
	}
      if (c == 10)
	{
	  stream_flush_buffer();
	}
      buffer[bufpos++] = c;
    }
}

void stream_input(const int* s)
{
  if (machine.transcript_on == 1 ||
      machine.transcript_commands == 1)
    {
      write_stringu(machine.transcript_file, s);
      write_string(machine.transcript_file, "\n");
    }
}

int stream_readline(int* buf, int len, long int timeout)
{
  int r;

  stream_flush_buffer();

  if (machine.script_on)
    {
      int pos = 0;
      char rc;
      static const int nl[] = { '\n', 0 };

      display_update();
      
      r = 1;

      while (!end_of_file(machine.script_file) && (rc = read_byte(machine.script_file)) != 10)
	{
	  if (rc >= 32 && rc < 127)
	    buf[pos++] = rc;
	  
	  if (pos >= len)
	    {
	      zmachine_warning("Input stream line exceeds length of input buffer");
	      break;
	    }
	  if (end_of_file(machine.script_file))
	    break;
	}
      
      if (machine.script_file != NULL && end_of_file(machine.script_file)) {
	close_file(machine.script_file);
	machine.script_file = NULL;
	machine.script_on = 0;
      }
      
      if (pos == 0 && machine.script_on == 0) {
	return stream_readline(buf, len, timeout);
      }

      buf[pos++] = 0;
      stream_prints((unsigned int*)buf);
      stream_prints((unsigned int*)nl);
    }
  else
    {
      r = display_readline(buf, len, timeout);
      
      if (r)
	stream_input(buf);
    }
      
  return r;
}

void stream_flush_buffer(void)
{
  static int flushing =  0;

  if (flushing)
    {
      return;
    }

  if (bufpos <= 0)
    return;
#ifdef DEBUG
  printf_debug("Buffer flushed\n");
#endif

  flushing = 1;

  buffer[bufpos] = 0;
  prints(buffer);
  bufpos = 0;

  flushing = 0;
}

void stream_buffering(int buf)
{
  if (!buf && buffering)
    stream_flush_buffer();

  buffering = buf;

#ifdef DEBUG
  printf_debug("Stream: buffering set to %i\n", buf);
#endif
}

void stream_printf(const char* const f, ...)
{
  va_list  ap;
  char     string[512];
  unsigned int* buf;
  int      x;

  va_start(ap, f);
  vsprintf(string, f, ap);
  va_end(ap);

  buf = malloc(sizeof(unsigned int)*(strlen(string)+1));
  for (x=0; string[x] != 0; x++)
    buf[x] = string[x];
  buf[x] = 0;

  stream_prints(buf);
  free(buf);
}

void stream_remove_buffer(const int* s)
{
  int len, x;

  for (len=0; s[len] != 0; len++);

  if (len > bufpos)
    return;

  for (x=len-1; x>=0; x--)
    {
      if (unicode_to_lower(buffer[bufpos-1]) != unicode_to_lower(s[x]))
	return;
      bufpos--;
    }
}

void stream_update_unicode_table(void)
{
  static int*  unitable = NULL;
  int          x;
  ZByte*       ztable;
  
  if (machine.heblen < 3)
    {
      zscii_unicode = zscii_unicode_table;
      return;
    }

  if (GetWord(machine.heb, ZHEB_unitable) == 0)
    {
      zscii_unicode = zscii_unicode_table;
      return;
    }
  
  unitable = realloc(unitable, sizeof(int)*256);    
  
  for (x=0; x<256; x++)
    {
      if ((x>=32 && x<127) ||
	  x==10 || x==13)
	{
	  unitable[x] = x;
	}
      else
	{
	  unitable[x] = 0x3f;
	}
    }

  ztable = Address((ZUWord)GetWord(machine.heb, ZHEB_unitable));

  if (ztable[0] > 96)
    zmachine_fatal("Bad unicode table - greater than 96 characters defined");

  for (x=0; x<ztable[0]; x++)
    {
      unitable[155+x] = (ztable[2*x+1]<<8)|ztable[2*x+2];
    }
  
  if (unitable[13] == 13)
    unitable[13] = 10;

  zscii_unicode = unitable;
}
