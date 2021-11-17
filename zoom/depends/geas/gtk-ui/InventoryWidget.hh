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

#ifndef __inventorywidget_hh
#define __inventorywidget_hh

#include <gtkmm/box.h>
#include <gtkmm/button.h>
#include <gtkmm/scrolledwindow.h>
#include <gtkmm/treeview.h>
#include <gtkmm/liststore.h>
#include <gtkmm/label.h>
#include "general.hh"

class GeasWindow;

class InventoryWidget : public Gtk::VBox
{
private:
  GeasWindow *owner;
  Glib::RefPtr<Gtk::ListStore> m_refListStore; // The tree model
  Gtk::TreeView m_TreeView; // The tree view

  virtual void on_drag_data_get (const Glib::RefPtr<Gdk::DragContext>& context, Gtk::SelectionData& selection_data, guint info, guint time);
  /*
  virtual void on_drag_data_get (Gtk::SelectionData& selection_data, Gdk::ModifierType buttons);
  virtual void on_ldrag_data_get (const Glib::RefPtr<Gdk::DragContext>& context, Gtk::SelectionData& selection_data, guint info, guint time);
  virtual void on_rdrag_data_get (const Glib::RefPtr<Gdk::DragContext>& context, Gtk::SelectionData& selection_data, guint info, guint time);
  */
  void on_drag_data_recvd (const Glib::RefPtr<Gdk::DragContext>& context, int x, int y, const Gtk::SelectionData& selection_data, guint info, guint time);

  Gtk::ScrolledWindow sw;
  Gtk::Label widget_name, widget_desc;

  void handle_button_press_event(GdkEventButton* event);  
  void handle_button_release_event(GdkEventButton* event);  

  //int pushed_button;

public:
  InventoryWidget(GeasWindow *);
  virtual ~InventoryWidget();

  class ModelColumns : public Gtk::TreeModel::ColumnRecord
  {
  public:
    ModelColumns() { add (m_col_text); }
    Gtk::TreeModelColumn <Glib::ustring> m_col_text;
  };

  void set_contents (const std::vector<std::vector<std::string> >&);
  ModelColumns m_columns;
};

#endif
