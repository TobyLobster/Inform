/*
 *  Builder - builds a ZCode interpreter
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
 * Representation of a ZCode operation
 */

#ifndef __OPERATION_H
#define __OPERATION_H

enum optype
{
  zop, unop, binop, varop, extop
};

typedef struct
{
  int isbranch;
  int isstore;
  int isstring;
  int islong;
  int canjump;
  int reallyvar;

  int fixed_args;
} opflags;

typedef struct
{
  char*       name;
  enum optype type;
  int         value;
  opflags     flags;
  int         versions; /* Bitfield */
  char*       code;
  int         codeline;
} operation;

typedef struct oplist
{
  int         numops;
  operation** op;
} oplist;

#endif


