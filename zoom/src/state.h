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

#ifndef __STATE_H
#define __STATE_H

#include "ztypes.h"
#include "zmachine.h"

extern ZByte* state_compile  (ZStack* stack,
			      ZDWord pc,
			      ZDWord* len,
			      int compress);
extern int    state_decompile(ZByte*  state,
			      ZStack* stack,
			      ZDWord* pc,
			      ZDWord  len);
extern int    state_save     (ZFile* file, ZStack* stack, ZDWord  pc);
extern int    state_load     (ZFile* file, ZDWord fsize, ZStack* stack, ZDWord* pc);
extern char*  state_fail     (void);

#endif
