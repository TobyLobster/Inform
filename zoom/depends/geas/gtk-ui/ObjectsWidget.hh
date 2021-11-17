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

#ifndef __objectswidget_hh
#define __objectswidget_hh

#include <gtkmm/box.h>
#include <gtkmm/button.h>
#include <gtkmm/scrolledwindow.h>
#include <gtkmm/treeview.h>
#include <gtkmm/liststore.h>
#include <gtkmm/label.h>
#include <vector>
#include <string>
#include "general.hh"

class GeasWindow;

class ObjectsWidget 
  : public Gtk::VBox
{
private:
  GeasWindow *owner;
  Gtk::TreeView m_TreeView;
  Glib::RefPtr<Gtk::ListStore> m_refListStore;
  Gtk::HBox buttons;
  Gtk::Label name;
  Gtk::Button lookat, take, speakto, go;
  Gtk::ScrolledWindow sw;

public:
  struct ModelColumns : public Gtk::TreeModel::ColumnRecord
  {
    Gtk::TreeModelColumn<Glib::ustring> name, type;
    ModelColumns() { add (name); add (type); }
  };
  ModelColumns m_columns;

  void set_contents (const std::vector<std::vector <std::string> > &);

  ObjectsWidget(GeasWindow *);
  virtual ~ObjectsWidget();

  virtual void on_drag_data_get (const Glib::RefPtr<Gdk::DragContext>& context, Gtk::SelectionData& selection_data, guint info, guint time);
  virtual void on_drag_data_recvd (const Glib::RefPtr<Gdk::DragContext>& context, int x, int y, const Gtk::SelectionData& selection_data, guint info, guint time);
  virtual void on_button_clicked (uint b);

};

#endif
