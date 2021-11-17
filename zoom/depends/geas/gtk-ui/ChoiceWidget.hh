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


//#include <gtkmm.h>
#include "general.hh"
#include <gtkmm/scrolledwindow.h>
#include <gtkmm/window.h>
#include <gtkmm/treeview.h>
#include <gtkmm/button.h>
#include <gtkmm/liststore.h>
#include <gtkmm/box.h>
#include <gtkmm/label.h>
#include <vector>
#include <string>
#include <gtkmm/main.h>


class ChoiceWidget : public Gtk::Window
{
private:
  Gtk::Label label;
  //std::string choice_title;
  //std::vector<std::string> choices;
  Gtk::ScrolledWindow sw;
  Gtk::TreeView tv;
  Gtk::VBox vb;
  Glib::RefPtr<Gtk::ListStore> m_refListStore;
  Gtk::Button b;
  uint choice;

public:
  struct ModelColumns : public Gtk::TreeModel::ColumnRecord
  {
    Gtk::TreeModelColumn<Glib::ustring> text;
    ModelColumns() { add (text); }
  };
  ModelColumns m_columns;

  ChoiceWidget();
  void on_button_clicked();
  void set_choices (std::string name, const std::vector<std::string> &choices);
  //ChoiceWidget (std::string name, const std::vector<std::string> &choices);
  //virtual ~ChoiceWidget();
  bool has_chosen();
  //uint get_choice() { return choice; }
  uint make_choice(std::string name, const std::vector<std::string> &choices);
};
