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
 * Execution options
 */

#ifndef __OPTIONS_H
#define __OPTIONS_H

typedef struct arguments
{
  char* arg[2];
  char* story_file;
  char* save_file;

  int   warning_level;
  int   track_attr;
  int   track_objs;
  int   track_props;
  int   graphical;

  int   debug_mode;
} arguments;

extern void get_options(int argc, char** argv, arguments* args);

#endif

