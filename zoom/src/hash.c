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
 * Hash table
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "hash.h"

/* #define DEBUG */

/* Power of 2 */
#define NUM_BUCKETS       8

/* Number of collisions before a hash becomes 'unhappy' */
#define UNHAPPY_THRESHOLD 4

#ifdef DEBUG
extern void printf_debug(const char* format, ...) __printflike(1, 2);
#endif

struct bucket
{
  char *key;
  int   keylen;
  void *data;

  int count;
  
  struct bucket *next;
};

hash hash_create(void)
{
  struct hash *hash;
  int x;

  hash = malloc(sizeof(struct hash));
  hash->n_buckets    = NUM_BUCKETS;
  hash->bucket       = malloc(sizeof(struct bucket *)*NUM_BUCKETS);
  hash->unhappy      = 0;

  for (x=0; x<NUM_BUCKETS; x++)
    {
      hash->bucket[x] = NULL;
    }

#ifdef DEBUG
  printf_debug("*** Hash - created new hash (%i elements)\n", hash->n_buckets);
#endif
  
  return hash;
}

/* Blantantly nicked from the comp.compression FAQ... */
static unsigned long crc32_table[256] = { 0, 0, 0, 0 };

#define CRC32_POLY 0x04c11db7     /* AUTODIN II, Ethernet, & FDDI */

static void init_crc32()
{
        int i, j;
        unsigned long c;

        for (i = 0; i < 256; ++i) {
                for (c = i << 24, j = 8; j > 0; --j)
                        c = c & 0x80000000 ? (c << 1) ^ CRC32_POLY : (c << 1);
                crc32_table[i] = c & 0xffffffff;
        }
}

unsigned long hash_hash(unsigned char *buf,
			int            len)
{
  unsigned char *p;
  unsigned long  crc;
  
  if (!crc32_table[1])    /* if not already done, */
    init_crc32();   /* build table */
  crc = 0xffffffff;       /* preload shift register, per CRC-32 spec */
  for (p = buf; len > 0; ++p, --len)
    crc = ((crc << 8) ^ crc32_table[(crc >> 24) ^ *p]) & 0xffffffff;
  return ~crc & 0xffffffff;     /* transmit complement, per CRC-32 spec */  
}

static struct bucket *hash_lookup(hash           hash,
				  unsigned char* key,
				  int            keylen,
				  unsigned long  value)
{
  struct bucket *next;
  struct bucket *match;

  next = hash->bucket[value];
  match = NULL;

  while (next != NULL && match == NULL)
    {
      if (next->keylen == keylen)
	{
	  if (memcmp(next->key, key, keylen) == 0)
	    match = next;
	}
      next = next->next;
    }

  return match;
}

void hash_store_happy(hash  hash,
		      unsigned char *key,
		      int   keylen,
		      void *data)
{
  hash_store(hash, key, keylen, data);

  if (hash->unhappy)
    {
      int new_size;

      new_size = hash->n_buckets*2;
      if (new_size<64)
	new_size *= 2;
 
#ifdef DEBUG
      printf_debug("*** Hash - unhappy hash, resizing to %i\n", new_size);
#endif
     
      hash_resize(hash, new_size);
    }
}

void hash_store(hash  hash,
		unsigned char *key,
		int         len,
		void       *data)
{
  unsigned long  value;
  struct bucket *bucket;

  value = hash_hash(key,
		    len)&(hash->n_buckets-1);

  bucket = hash_lookup(hash, key, len, value);

  if (bucket == NULL)
    {
      bucket = malloc(sizeof(struct bucket));

#ifdef DEBUG
      printf_debug("*** Hash - storing new value in bucket 0x%lx\n", value);
#endif

      bucket->key = malloc(len+1);
      bucket->keylen = len;
      memcpy(bucket->key, key, len);
      bucket->next = hash->bucket[value];
      hash->bucket[value] = bucket;

      if (bucket->next != NULL)
	{
	  bucket->count = bucket->next->count + 1;

	  if (bucket->count > UNHAPPY_THRESHOLD)
	    hash->unhappy = 1;
	}
      else
	bucket->count = 0;
    }
#ifdef DEBUG
  else
    {
      printf_debug("*** Hash - replacing value in bucket %s in 0x%lx\n", key, value);
    }
#endif

  bucket->data = data;
}

void hash_free(hash hash)
{
  int x;

  for (x=0; x<hash->n_buckets; x++)
    {
      struct bucket *next;

      next = hash->bucket[x];

      while (next != NULL)
	{
	  struct bucket *last;

	  last = next;
	  next = next->next;

	  free(last);
	}
    }

  free(hash);
}

void hash_iterate(hash hash,
			int (*func)(unsigned char *key,
				    int   keylen,
				    void *data,
				    void *arg),
			void *arg)
{
  int x;
  int res;

  res = 0;
  
  for (x=0; x<hash->n_buckets && res == 0; x++)
    {
      struct bucket *next;
      
      next = hash->bucket[x];
      
      while (next != NULL && res == 0)
	{
	  res = (func)(next->key,
		       next->keylen,
		       next->data,
		       arg);
	  
	  next = next->next;
	}
    }
}

void *hash_get(hash  hash,
	       unsigned char* key,
	       int   len)
{
  unsigned long  value;
  struct bucket *bucket;

  
  value = hash_hash(key,
		    len)&(hash->n_buckets-1);

  bucket = hash_lookup(hash, key, len, value);

  if (bucket != NULL)
    return bucket->data;

  return NULL;
}

static int resize_func(unsigned char *key,
		       int   keylen,
		       void *data,
		       void *new_hash)
{
  if (data != NULL)
    hash_store((hash) new_hash, key, keylen, data);

  return 0;
}

void hash_resize(hash hsh,
		 int  n_buckets)
{
  hash new_hash;
  
  if (n_buckets > 32768)
    {
      /* We'll max out here for the time being */
      return;
    }

  new_hash = hash_create();

#ifdef DEBUG
  printf_debug("*** Hash - resizing to %i\n", n_buckets);
#endif

  free(new_hash->bucket);

  *new_hash = *hsh;

  hsh->n_buckets = n_buckets;
  hsh->bucket    = calloc(n_buckets,
			  sizeof(struct bucket *));
  hsh->unhappy   = 0;

  hash_iterate(new_hash, resize_func, hsh);
  
  hash_free(new_hash);
}
