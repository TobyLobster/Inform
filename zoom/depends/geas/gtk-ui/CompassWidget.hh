/***************************************************************************
 *                                                                         *
 * Copyright (C) 2006 by Mark J. Tilford                                   *
 *                                                                         *
 * This file is part of Geas.                                              *
 *                                                                         *
 * Geas is free software; you can redistribute it and/or modify            *
 * it under the terms of the GNU General Public License as published by    *
 * the Free Software Foundation; either version 2 of the License, or       *
 * (at your option) any later version.                                     *
 *                                                                         *
 * Geas is distributed in the hope that it will be useful,                 *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of          *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           *
 * GNU General Public License for more details.                            *
 *                                                                         *
 * You should have received a copy of the GNU General Public License       *
 * along with Geas; if not, write to the Free Software                     *
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *                                                                         *
 ***************************************************************************/

#ifndef __compasswidget_hh
#define __compasswidget_hh

#include <gtkmm/button.h>
#include <gtkmm/table.h>
#include <vector>
#include <string>
#include <gtkmm/box.h>
#include "general.hh"

class GeasWindow;

class CompassWidget : public Gtk::HBox
{
  GeasWindow *owner;

  std::vector<Gtk::Button*> buttons;
  //std::vector<std::string> button_names;
  Glib::RefPtr<Gdk::Pixbuf> on_imgs, off_imgs;
  Gtk::Table ltable, rtable;

protected:
  void on_button_clicked (uint button);

public:
  CompassWidget (GeasWindow *);

  void set_valid_exits (const std::vector <bool>&);
};


#endif
