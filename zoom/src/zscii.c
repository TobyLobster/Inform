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
 * Convert ZSCII strings to ASCII
 */

#include <stdlib.h>

#include "zmachine.h"
#include "zscii.h"

static unsigned int *buf  = NULL;
static int maxlen = 0;

/* Default tables */
static unsigned int alpha_a[32] =
{
	0,0,0,0,0,0,
	97, 98, 99,100,101,102,103,104,105,106,107,108,109,
	110,111,112,113,114,115,116,117,118,119,120,121,122
};
static unsigned int alpha_b[32] =
{
	0,0,0,0,0,0,
	65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77,
	78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90
};
static unsigned int alpha_c[32] =
{
	0,0,0,0,0,0,
	0, 10, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 46,
	44, 33, 63, 95, 35, 39, 34, 47, 92, 45, 58, 40, 41
};
static unsigned int* convert_table[3] = { alpha_a, alpha_b, alpha_c };

/* Table that maps alphabet + character to ZSCII character */
static unsigned int** convert = convert_table;

int  zscii_unicode_table[256] =
{
	0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 000-007 */
	0x3f,0x09,0x0a,0x20, 0x3f,0x0a,0x3f,0x3f, /* 008-015 */
	0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 016-023 */
	0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 024-031 */
	0x20,0x21,0x22,0x23, 0x24,0x25,0x26,0x27, /* 032-039 */
	0x28,0x29,0x2a,0x2b, 0x2c,0x2d,0x2e,0x2f, /* 040-047 */
	0x30,0x31,0x32,0x33, 0x34,0x35,0x36,0x37, /* 048-055 */
	0x38,0x39,0x3a,0x3b, 0x3c,0x3d,0x3e,0x3f, /* 056-063 */
	0x40,0x41,0x42,0x43, 0x44,0x45,0x46,0x47, /* 064-071 */
	0x48,0x49,0x4a,0x4b, 0x4c,0x4d,0x4e,0x4f, /* 072-079 */
	0x50,0x51,0x52,0x53, 0x54,0x55,0x56,0x57, /* 080-087 */
	0x58,0x59,0x5a,0x5b, 0x5c,0x5d,0x5e,0x5f, /* 088-095 */
	0x60,0x61,0x62,0x63, 0x64,0x65,0x66,0x67, /* 096-103 */
	0x68,0x69,0x6a,0x6b, 0x6c,0x6d,0x6e,0x6f, /* 104-111 */
	0x70,0x71,0x72,0x73, 0x74,0x75,0x76,0x77, /* 112-119 */
	0x78,0x79,0x7a,0x7b, 0x7c,0x7d,0x7e,0x7f, /* 120-127 */
	0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 128-135 */
	0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 136-143 */
	0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 144-151 */
	0x3f,0x3f,0x3f,0xe4, 0xf6,0xfc,0xc4,0xd6, /* 152-159 */
	0xdc,0xdf,0xbb,0xab, 0xeb,0xef,0xff,0xcb, /* 160-167 */
	0xcf,0xe1,0xe9,0xed, 0xf3,0xfa,0xfd,0xc1, /* 168-175 */
	0xc9,0xcd,0xd3,0xda, 0xdd,0xe0,0xe8,0xec, /* 176-183 */
	0xf2,0xf9,0xc0,0xc8, 0xcc,0xd2,0xd9,0xe2, /* 184-191 */
	0xea,0xee,0xf4,0xfb, 0xc2,0xca,0xce,0xd4, /* 192-199 */
	0xdb,0xe5,0xc5,0xf8, 0xd8,0xe3,0xf1,0xf5, /* 200-207 */
	0xc3,0xd1,0xd5,0xe6, 0xc6,0xe7,0xc7,0xfe, /* 208-215 */
	0xf0,0xde,0xd0,0xa3, 0x153,0x152,0xa1,0xbf, /* 216-223 */
	0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 224-231 */
	0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 232-239 */
	0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 240-247 */
	0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f  /* 248-255 */
};

/* Table that maps (8-bit) ZSCII to unicode */
int* zscii_unicode = zscii_unicode_table;

#ifdef DEBUG
char* zscii_to_ascii(ZByte* string, int* len)
{
	static char* cbuf = NULL;
	int x;
	
	zscii_to_unicode(string, len);
	
	cbuf = realloc(cbuf, 2);
	for (x=0; buf[x] != 0; x++)
    {
		cbuf = realloc(cbuf, (x+2));
		cbuf[x] = zscii_get_char(buf[x]);
    }
	
	cbuf[x] = 0;
	
	return cbuf;
}
#endif

/*
 * Convert a ZSCII string (packed) to Unicode (unpacked)
 */
unsigned int* zscii_to_unicode(ZByte* string, int* len)
{
	int abet = 0;
	int x = 0;
	int y = 0;
	int zlen, z;
	ZWord zchar = 0;
	int fin = 0;
		
	zlen = 0;
	
	if (maxlen <= 0)
    {
		maxlen += 512;
		buf = realloc(buf, sizeof(unsigned int)*maxlen);
    }
	
	while (!fin)
    {
		ZUWord word;
		
		fin = (string[x]&0x80) != 0;
		
		word = ((unsigned)string[x]<<8)|(unsigned)string[x+1];
		
		for (z=0; z<3; z++)
		{
			int c;
			
			c = (word&0x7c00)>>10;
			
			if ((y+8) > maxlen)
			{
				maxlen += 1024;
				buf = realloc(buf, sizeof(int)*maxlen);
			}
			
			switch (abet)
			{
				/* Standard alphabets */
				case 2:
					if (c == 6)
					{
						/* Next 2 chars make up a Z-Character */
						abet=4;
						break;
					}
				case 1:
				case 0:
					if (c >= 6)
					{
						if (convert[abet][c] < 256)
							buf[y++] = zscii_unicode[convert[abet][c]];
						else
							buf[y++] = convert[abet][c];
						
						if (buf[y-1] == 9)
						{
							y--;
							buf[y++] = ' ';
							buf[y++] = ' ';
							buf[y++] = ' ';
						}
						if (buf[y-1] == 11)
						{
							y--;
							buf[y++] = ' ';
							buf[y++] = ' ';
						}
						abet=0;
					}
					else
					{
						switch (c)
						{
							case 0: /* Space */
								buf[y++] = ' ';
								break;
								
							case 1: /* Next char is an abbreviation */
							case 2:
							case 3:
								zchar=(c-1)<<5;
								abet=3;
								break;
								
							case 4: /* Shift to alphabet 1 */
								abet=1;
									break;
								case 5: /* Shift to alphabet 2 */
									abet=2;
									break;
								default:
									/* Ignore */
									break;
						}
					}
					break;
					
				case 3: /* Abbreviation */
				{
					int z;
					int* abbrev;
					int addr;
					ZByte* table;
					
					zchar |= c;
					
					/* 
						* Annoyingly, some games seem to rewrite the abbreviation
					 * table at runtime. This may cause weird things to happen
					 * if a game is sick enough to use abbreviations in
					 * abbreviations, too.
					 */
					table = machine.memory + GetWord(machine.header, ZH_abbrevs);
					addr = ((table[zchar*2]<<9)|(table[zchar*2+1]<<1));
					
					if (machine.abbrev_addr[zchar] != addr)
					{
					   if (addr >= 0 && addr < machine.story_length)
					   {
						  /* 
						  * Hack, this function was never designed to be called
						   * recursively
						   */
						  unsigned int* oldbuf;
						  int oldmaxlen;
						  int ablen;
						  
						  oldbuf = buf;
						  oldmaxlen = maxlen;
						  maxlen = 0;
						  buf = NULL;
						  
						  zlen = y;
						  abbrev = zscii_to_unicode((ZByte*)machine.memory +
													addr,
													&ablen);
						  
						  buf = oldbuf;
						  maxlen = oldmaxlen;
						  
						  for (z=0; abbrev[z]!=0; z++)
							  zlen++;
						  
						  while ((zlen+2) > maxlen)
						  {
							  maxlen += 1024;
							  buf = realloc(buf, sizeof(int)*(maxlen));
						  }
						  
						  for (z=0; abbrev[z] != 0; z++)
						  {
							  buf[y++] = abbrev[z];
						  }
						  
						  free(abbrev);
					   }
					  else
					  {
						zmachine_fatal("Found a bad entry in the abbreviation table for entry %i", zchar);
					  }
					}
					else if (machine.abbrev[zchar])
					{
						abbrev = machine.abbrev[zchar];
						
						for (z=0; abbrev[z]!=0; z++)
							zlen++;
						
						while ((zlen+2) > maxlen)
						{
							maxlen+=1024;
							buf = realloc(buf, sizeof(int)*(maxlen));
						}
						
						for (z=0; abbrev[z] != 0; z++)
						{
							buf[y++] = abbrev[z];
						}
					}
					else
					{
					  zmachine_fatal("Found a bad entry in the abbreviation table for entry %i", zchar);
					}
				}
					
					abet = 0;
						break;
						
					case 4: /* First byte of a Z-Char */
						zchar = c<<5;
							abet = 5;
							break;
							
						case 5: /* Second byte of a Z-Char */
							zchar |= c;
								abet = 0;
								
								if (zchar < 256)
								{
									switch(zchar)
									{
										default:
											buf[y++] = zscii_unicode[zchar];
											
											if (buf[y-1] == 9)
											{
												y--;
												buf[y++] = ' ';
												buf[y++] = ' ';
												buf[y++] = ' ';
											}
									}
								}
									else
									{
#ifdef SPEC_11
										if (zchar > 767)
										{
											/* Unicode character, this is a bit of a PITA */
											int ulen;
											int i;
																						
											ulen = zchar - 767;
											x += 2;
											
											for (i=0; i<ulen; i++)
											{
												if ((y+1) > maxlen)
												{
													maxlen += 1024;
													buf = realloc(buf, sizeof(int)*maxlen);
												}
												
												buf[y++] = (~((((unsigned)string[x])<<8)|((unsigned)string[x+1])))&0xffff;
												x += 2;
											}
											
											if (z == 2)
												goto onward; /* Blech */
										}
#else
										buf[y++] = zchar;
#endif
									}
									break;
			}
			
			word <<= 5;
		}
		
		x += 2;
onward: 
			; /* Stupid ANSI standard, or is this an ISO thing? */
    }
	
	*len = x;
	buf[y] = 0;
	
	return buf;
}

/*
 * Pack a ZSCII string, suitable for comparing to a dictionary item
 *
 * A packlen of 6 gives us v3 format, and 9 gives us v5
 */
static unsigned char zscii_table[256] =
{
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 8 */
	0x00,0x00,0xc7,0x00, 0x00,0x00,0x00,0x00, /* 16 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 24 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 32 */
	0x00,0xd4,0xd9,0xd7, 0x00,0x00,0x00,0xd8, /* 40 */
	0xde,0xdf,0x00,0x00, 0xd3,0xdc,0xd2,0xda, /* 48 */
	0xc8,0xc9,0xca,0xcb, 0xcc,0xcd,0xce,0xcf, /* 56 */
	0xd0,0xd1,0xdd,0x00, 0x00,0x00,0x00,0xd5, /* 64 */
	0x00,0x86,0x87,0x88, 0x89,0x8a,0x8b,0x8c, /* 72 */
	0x8d,0x8e,0x8f,0x90, 0x91,0x92,0x93,0x94, /* 80 */
	0x95,0x96,0x97,0x98, 0x99,0x9a,0x9b,0x9c, /* 88 */
	0x9d,0x9e,0x9f,0x00, 0xdb,0x00,0x00,0xd6, /* 96 */
	0x00,0x46,0x47,0x48, 0x49,0x4a,0x4b,0x4c, /* 104 */
	0x4d,0x4e,0x4f,0x50, 0x51,0x52,0x53,0x54, /* 112 */
	0x55,0x56,0x57,0x58, 0x59,0x5a,0x5b,0x5c, /* 120 */
	0x5d,0x5e,0x5f,0x00, 0x00,0x00,0x00,0x00, /* 128 */
	
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 8 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 16 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 24 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 32 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 40 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 48 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 56 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 64 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 72 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 80 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 88 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 96 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 104 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 112 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 120 */
	0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00  /* 128 */
};

/* Table that maps 8-bit characters to packed characters. Lower 6 bits are the characters, the other bits are the alphabet */
static unsigned char* zscii = zscii_table;

void pack_zscii(unsigned int* string, int strlen, ZByte* packed, int packlen)
{
	int  zpos, byte;
	int  strpos;
	int  wordlen;
	char zchr[40];
	
	strpos = 0;
	
	for (zpos=0; zpos<packlen;)
    {
	  if (strpos >= strlen) {
		/* Add padding */
		zchr[zpos++] = 5;
	  } else {
		unsigned char zchar;
		int alphabet, chr;
		
		/* Convert the character to ZSCII */
		zchar = zscii_get_char(string[strpos]);
		
		/* Encoding using an alphabet/character encoding if available */
		alphabet = zscii[zchar]>>6;
		chr = zscii[zchar]&0x1f;
		
		switch (alphabet) {
		  case 0:
			/* Encode directly */
			zchr[zpos++] = 5;
			zchr[zpos++] = 6;
			zchr[zpos++] = zchar>>5;
			zchr[zpos++] = zchar&0x1f;
			break;
			
		  case 1:
			zchr[zpos++]= chr;
			break;
			
		  case 2:
			zchr[zpos++] = 4;
			zchr[zpos++] = chr;
			break;
			
		  case 3:
			zchr[zpos++] = 5;
			zchr[zpos++] = chr;
			break;
			
			/* Other cases are impossible. IMPOSSIBLE I SAY. There is no spoon. */
		}
		
		/* 
		 * (In spec 1.1, it's possible to encode an arbitrary unicode character, but not
		 * sensible unless two-character commands are demanded by the story, so we don't 
		 * bother) 
		 */
	  }
	  
	  /* Next character in the string */
	  strpos++;
    }
	
	/* Pack the Z-characters */
	wordlen = packlen/3;
	for (byte=0; byte<wordlen; byte++)
    {
		packed[byte<<1] = (zchr[byte*3]<<2)|(zchr[byte*3+1]>>3);
		packed[(byte<<1)+1] = (zchr[byte*3+1]<<5)|zchr[byte*3+2];
    }
	packed[wordlen*2-2] |= 0x80;
}

/*
 * Works out the length (in characters) of a packed Z-string
 */
int zstrlen(ZByte* string)
{
	int x = 0;
	
	/*
	 * ObRant: The new Unicode encoding is poorly thought out...
	 * it *MASSIVELY* complicates string decoding, because suddenly
	 * the top bit of a packed word doesn't always indicate the end
	 * of a string. Well, massively is relative, o'course. Practically
	 * any increase is massive over two lines of code :-/. HUGE PITA.
	 */
	
#ifdef ZSPEC_11
	int pos = 0;
	int buf[3] = { 0,0,0 };
	
	while ((string[x]&0x80) == 0)
    {
		/* ARRRGH! */
		ZUWord word;
		int y, a, b;
		
		word = (string[x]<<8)|string[x];
		
		a = 1; b = 2;
		for (y=0; y<3; y++)
		{
			a++; if (a == 3) a = 0;
			b++; if (b == 3) b = 0;
			
			buf[y] = (word&0x1f);
			word >>= 5;
			
			if (buf[z] == 6)
			{
				int ulen;
				
				ulen = (buf[a]<<5)|buf[b];
			}
		}
		
		x += 2;
    }
#else
	/* Sniff. Easy to debug. Easy to write. */
	while ((string[x]&0x80) == 0)
		x+=2;
#endif
	
	return x*3+3;
}

/*
 * Installs the alphabet table associated with the currently loaded story
 */
void zscii_install_alphabet(void)
{
	if (ReadByte(0)>=5)
    {
		ZUWord table;
		
		table = Word(ZH_alphatable);
		if (table)
		{
			static unsigned int** conv = NULL;
			static unsigned char* zsc = NULL;
			ZByte* alpha;
			int x, y;
			int alphabet, character;
			
			alpha = Address(table);
			
			if (conv == NULL)
			{
			  conv = malloc(sizeof(unsigned int*)*3);
			  for (x=0; x<3; x++) {
				conv[x] = malloc(sizeof(int)*32);
				
				for (y=0; y<32; y++) conv[x][y] = 0;
			  }
			}
			
			zsc = realloc(zsc, sizeof(char)*256);
			for (x=0; x<256; x++)
				zsc[x] = 0x0;
			
			for (alphabet=0; alphabet<3; alphabet++)
			{
			  /* First 6 characters are always 0 */
				for (character=0; character<6; character++)
					conv[alphabet][character] = 0;
				
			  /* Conversion mapping for the alphabet itself */
			  for (character=0; character<26; character++)
				{
					conv[alphabet][character+6]      = *(alpha++);
					zsc[conv[alphabet][character+6]] = (character+6)|((alphabet+1)<<6);
				}
			}
			
			/* These characters are always newline/space */
			zsc[conv[2][7]] = 0;
			zsc[conv[2][6]] = 0;
			conv[2][7] = 10;
			conv[2][6] = 32;
			
			zsc[10] = 7|(3<<6);
			zsc[32] = 6|(3<<6);
						
			convert = conv;
			zscii = zsc;
		}
		else
		{
			convert = convert_table;
			zscii = zscii_table;
		}
    }
	else
    {
		convert = convert_table;
		zscii = zscii_table;
    }
}
