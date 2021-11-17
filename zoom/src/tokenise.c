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
 * Tokenise a word/string
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zmachine.h"
#include "tokenise.h"
#include "hash.h"
#include "zscii.h"

struct dict_entry
{
  ZUWord address;
};

ZDictionary* dictionary_cache(const ZUWord dict_pos)
{
  ZByte*       dct;
  ZWord        dpos;
  ZDictionary* dict;
  int x;
  int text_len;

  /* See if we've already parsed this dictionary */
  dict = hash_get(machine.cached_dictionaries,
		  (unsigned char*) &dict_pos,
		  sizeof(ZUWord));
  if (dict != NULL)
    {
      return dict;
    }

#ifdef DEBUG
  printf_debug("Caching dictionary $%x\n", dict_pos);
#endif
  
  dct = machine.memory + dict_pos;
  
  /* Parse the dictionary */
  dict = malloc(sizeof(ZDictionary));
  dict->words = hash_create();
  for (x=0; x<256; x++)
    dict->sep[x] = 0;

  dict->sep[0] = 1;
  dict->sep[32] = 1;
  /* Mark word seperators */
  for (x=0; x<dct[0]; x++)
    {
#ifdef DEBUG
      printf_debug("%i is a seperator\n", dct[x+1]);
#endif
      dict->sep[dct[x+1]] = 1;
    }
  
  /* Parse dictionary entries */
  dpos      = dict_pos+1+dct[0];
  dct      += 1+dct[0];

  if (ReadByte(0) <= 3)
    text_len = 4;
  else
    text_len = 6;

  {
    int entry_length;
    ZWord no_entries;

    entry_length = dct[0];
    no_entries   = (dct[1]<<8)|dct[2];

    if (no_entries < 0)
      {
	zmachine_warning("Unsorted dictionaries not supported correctly");
	no_entries = -no_entries; /* Unsorted dictionary */
      }

    if (entry_length < text_len)
      zmachine_fatal("Bad dictionary: entry length is less than %i", text_len);

    for (x=0; x<no_entries; x++)
      {
	struct dict_entry* entry;

	entry = malloc(sizeof(struct dict_entry));
	entry->address = dpos+3+entry_length*x;

#ifdef DEBUG
	printf_debug("Adding word $%x%x $%x%x (@%x) - ",
		     dct[3+entry_length*x],
		     dct[3+entry_length*x+1],
		     dct[3+entry_length*x+2],
		     dct[3+entry_length*x+3],
		     entry->address);
	{
		int blob,y;
		unsigned char packed[12];
		int* unicode = zscii_to_unicode(dct + 3+entry_length*x, &blob);
		
		for (y=0; unicode[y] !=0; y++); /* y = length of string */
		
		pack_zscii(unicode,
				   y,
				   packed,
				   9);

		printf_debug("%s (", zscii_to_ascii(dct + 3+entry_length*x, &blob));
	  
		for (y=0; y<text_len; y++) {
			printf_debug("%02x", (dct + (3+entry_length*x))[y]);
		}
		
		printf_debug(" - ");
		for (y=0; y<text_len; y++) {
			printf_debug("%02x", packed[y]);
		}
		printf_debug(")\n");
	}
#endif

	hash_store_happy(dict->words, dct + (3+entry_length*x), text_len, entry);
      }
  }

  hash_store_happy(machine.cached_dictionaries,
		   (unsigned char*)&dict_pos,
		   sizeof(ZUWord),
		   dict);

  return dict;
}

int cache = 1;

static inline ZUWord lookup_word(unsigned int*  word,
                                 int            wordlen,
                                 ZUWord         dct)
{
  ZByte packed[12];
  int zscii_len;
  int text_len;
  ZDictionary* cached;
  ZWord  no_entries, entry_length;
  int x;

#ifdef DEBUG
  printf_debug("Looking up '");
  {
    int x;
    for (x=0; x<wordlen; x++)
      printf_debug("%c", word[x]);
  }
  printf_debug("'... ");
#endif

  if (ReadByte(ZH_version) <= 3)
    {
      zscii_len = 6;
      text_len = 4;
    }
  else
    {
      zscii_len = 9;
      text_len = 6;
    }
  pack_zscii(word, wordlen, packed, zscii_len);
  
#ifdef DEBUG
  {
	  int x;
	  for (x=0; x<text_len; x++) {
		  printf_debug("(%02x)", packed[x]);
		  printf_debug("... ");
	  }
  }
#endif
  
  cached = dictionary_cache(dct);
  if (!cached)
    zmachine_fatal("Bad dictionary");
  
  dct += 1+ReadByte(dct);
  
  entry_length = ReadByte(dct);
  no_entries   = Word(dct+1);
  dct += 3;
  
  if (cache && (no_entries > 0 || dct > machine.dynamic_ceiling))
    {
      struct dict_entry* ent;

#ifdef DEBUG
      printf_debug("Using cached version of dictionary $%x\n", dct);
#endif

      ent = hash_get(cached->words, packed, text_len);
      if (ent == NULL)
	return 0;
      return ent->address;
    }
  else
    {
      if (no_entries < 0)
	no_entries = -no_entries;

#ifdef DEBUG
      printf_debug("Using linear search of dictionary $%x\n", dct);
#endif
      
      for (x=0; x<no_entries; x++)
	{	  
	  if (memcmp(Address(dct), packed, text_len) == 0)
	    return dct;

	  dct += entry_length;
	}

      return 0;
    }
}

void tokenise_string(unsigned int* string,
		     ZUWord dct,
		     ZByte* tokbuf,
		     int    flag,
		     int    add)
{
  ZDictionary*       dict;
  unsigned int*      word;
  int                strpos, wordlen, wordstart;
  int                wordno, tokpos;
  ZUWord             ent;
  int                zscii_len, text_len;

  if (ReadByte(ZH_version) <= 3)
    {
      zscii_len = 6;
      text_len = 4;
    }
  else
    {
      zscii_len = 9;
      text_len = 6;
    }

  dict = dictionary_cache(dct);

  strpos = 0;
  tokpos = 2;
  wordno = 0;

  while (string[strpos] != 0 && wordno < tokbuf[0])
    {
      word = string + strpos;
      wordstart = strpos;
      wordlen = 0;

      /* Read up to the next seperator */
      while (dict->sep[string[strpos]] == 0)
	{
	  strpos++;
	  wordlen++;
	}

      /* Look the word up */
      if (wordlen>0)
	{	  
	  ent = lookup_word(word, wordlen, dct);

#ifdef DEBUG
	  if (ent != 0)
	    printf_debug("Found\n");
	  else
	    printf_debug("Not found\n");
#endif

	  if (ent != 0)
	    {
	      tokbuf[tokpos++] = ent>>8;
	      tokbuf[tokpos++] = ent;

	      tokbuf[tokpos++] = wordlen;
	      tokbuf[tokpos++] = wordstart + add;

	      wordno++;
	    }
	  else
	    {
	      if (!flag)
		{
		  tokbuf[tokpos++] = 0;
		  tokbuf[tokpos++] = 0;
		  
		  tokbuf[tokpos++] = wordlen;
		  tokbuf[tokpos++] = wordstart + add;
		}
	      else
		tokpos+=4; /* Leave the entry as-is */

	      wordno++;
	    }
	}

      if (string[strpos] != 0)
	{
#ifdef DEBUG
	  printf_debug("Whitespace %x\n", string[strpos]);
#endif
	  ent = 0;
	  if (string[strpos] != 32)
	    ent = lookup_word(string + strpos, 1, dct);

	  if (ent != 0)
	    {
	      tokbuf[tokpos++] = ent>>8;
	      tokbuf[tokpos++] = ent;

	      tokbuf[tokpos++] = 1;
	      tokbuf[tokpos++] = strpos + add;

	      wordno++;
	    }
	  else if (string[strpos] != 32)
	    {
	      if (!flag)
		{
		  tokbuf[tokpos++] = 0;
		  tokbuf[tokpos++] = 0;
		  
		  tokbuf[tokpos++] = 1;
		  tokbuf[tokpos++] = strpos + add;
		}
	      else
		{
		  tokpos += 4;
		}

	      wordno++;
	    }

	  strpos++;
	}
    }

  tokbuf[1] = wordno;
}

