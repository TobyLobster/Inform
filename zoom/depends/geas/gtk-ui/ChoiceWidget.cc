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

#include "ChoiceWidget.hh"
#include <iostream>
using namespace std;
#include <gtkmm/main.h>
#include "general.hh"

//ChoiceWidget::ChoiceWidget (string name, const vector<string> &in_choices) :
ChoiceWidget::ChoiceWidget () : label ("What is it?"), vb(false), b ("Select")
{
  m_refListStore = Gtk::ListStore::create(m_columns);
  tv.set_model (m_refListStore);
  tv.append_column ("", m_columns.text);
  tv.property_headers_visible() = false;
  sw.add(tv);
  vb.pack_start (label, false, false);
  vb.pack_start (sw, true, true);
  vb.pack_start (b, false, false);
  //add(sw);
  //pack(b);
  add (vb);

  b.signal_clicked().connect(sigc::mem_fun (*this, &ChoiceWidget::on_button_clicked));

  label.show();
  tv.show();
  sw.show();
  b.show();
  vb.show();
 
  set_default_size (300, 300);
}

void ChoiceWidget::on_button_clicked()
{
  cerr << "on_button_clicked() " << endl;
  Glib::RefPtr<Gtk::TreeSelection> ts = tv.get_selection();
  if (ts->count_selected_rows() == 0) 
    {
      cerr << "No rows selected" << endl;
      return;
    }
  if (ts->count_selected_rows() > 1)
    {
      cerr << "Somehow, more than one choice has been made in the choice box" << endl;
      return;
    }
  //hide();
  //Gtk::TreeModel::iterator i = ts->get_selected();
  // i = ts->get_selected();
  //cerr << "Selected row is #" << (i - ts->begin()) << endl;
  //choice = (Gtk::TreePath (ts->get_selected()).get_indices())->[0];
  //Glib::ArrayHandle<int> ind = Gtk::TreePath(ts->get_selected()).get_indices();
  vector<int> ind = Gtk::TreePath(ts->get_selected()).get_indices();
  choice = ind[0];
  cerr << "Selected row #" << choice << endl;
  hide();
}

uint ChoiceWidget::make_choice (string name, const vector<string> &choices)
{
  set_choices (name, choices);

  show();
  do { gtk_main_iteration_do (true); } while (property_visible());
  return choice;
  //return 0;
}

void ChoiceWidget::set_choices (string name, const vector<string> &in_choices)
{
  label.set_text(name);
  //choices = in_choices;
  m_refListStore->clear();
  for (uint i = 0; i < in_choices.size(); i ++)
    {
      Gtk::TreeRow row = *(m_refListStore->append());
      row[m_columns.text] = in_choices[i];
    }
}
