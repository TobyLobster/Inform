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

#include "general.hh"
#include <gtkmm/scrolledwindow.h>
#include <gtkmm/treeview.h>
#include <gtkmm/liststore.h>
#include <vector>
#include <string>

class VariableWidget : public Gtk::ScrolledWindow
{
private:
  Gtk::TreeView m_TreeView;
  Glib::RefPtr <Gtk::ListStore> m_refListStore;
  
public:
  struct ModelColumns : public Gtk::TreeModel::ColumnRecord
  {
    Gtk::TreeModelColumn<Glib::ustring> var;
    ModelColumns() { add (var); }
  };

  ModelColumns m_columns;

  void set_contents (const std::vector<std::string> &);

  VariableWidget();
  virtual ~VariableWidget() {}
};
