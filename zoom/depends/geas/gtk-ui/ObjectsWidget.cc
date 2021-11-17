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

#include "ObjectsWidget.hh"
//#include <sstream>
#include "GeasWindow.hh"
#include "general.hh"

using namespace std;

ObjectsWidget::ObjectsWidget(GeasWindow *in_owner)
  : owner (in_owner), name ("Places and Objects:"), lookat ("Look at"), take ("Take"), speakto ("Speak to"), go ("Go to")
{
  sw.set_policy (Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);

  pack_start (name, false, false);
  
  buttons.add(lookat);
  buttons.add(take);
  buttons.add(speakto);
  pack_start (buttons, false, false);

  lookat.signal_clicked().connect (sigc::bind (sigc::mem_fun (*this, &ObjectsWidget::on_button_clicked), 0));
  take.signal_clicked().connect (sigc::bind (sigc::mem_fun (*this, &ObjectsWidget::on_button_clicked), 1));
  speakto.signal_clicked().connect (sigc::bind (sigc::mem_fun (*this, &ObjectsWidget::on_button_clicked), 2));
  go.signal_clicked().connect (sigc::bind (sigc::mem_fun (*this, &ObjectsWidget::on_button_clicked), 3));

  //set_policy (Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);
  m_refListStore = Gtk::ListStore::create (m_columns);

  m_TreeView.set_model (m_refListStore);

  m_TreeView.append_column("Name", m_columns.name);
  m_TreeView.append_column("Type", m_columns.type);
  m_TreeView.get_column(0)->set_resizable(true);
  m_TreeView.get_column(1)->set_resizable(true);

  sw.add(m_TreeView);
  add(sw);

  std::list<Gtk::TargetEntry> srcTargets, destTargets;
  //srcTargets.push_back ( Gtk::TargetEntry ("room_object") );
  //srcTargets.push_back ( Gtk::TargetEntry ("inv_object") );
  //destTargets.push_back ( Gtk::TargetEntry ("room_object") );
  destTargets.push_back ( Gtk::TargetEntry ("inv_object") );

  //m_TreeView.enable_model_drag_source (srcTargets);
  m_TreeView.enable_model_drag_dest (destTargets);
  //m_TreeView.signal_drag_data_get().connect ( sigc::mem_fun (*this, &ObjectsWidget::on_drag_data_get));
  m_TreeView.signal_drag_data_received().connect ( sigc::mem_fun (*this, &ObjectsWidget::on_drag_data_recvd));

}

void ObjectsWidget::on_button_clicked (uint button)
{
  cerr << "on_button_clicked()" << endl;
  Gtk::TreeModel::iterator i = m_TreeView.get_selection()->get_selected();
  if (i == 0)
    {
      cerr << "Is null, canceling\n";
      return;
    }
  //cerr << "1: " << *m_TreeView.get_selection() << endl;
  //cerr << "2: " << m_TreeView.get_selection()->get_selected() << endl;
  //cerr << "2: " << *m_TreeView.get_selection()->get_selected() << endl;
  
  //Glib::ustring obj = (*m_TreeView.get_selection()->get_selected)[m_columns.name];
  Glib::ustring obj = (*i)[m_columns.name];
  //cerr << "Button #" << button << " clicked on " << obj << "\n";
  if (button == 0)
    owner->try_run_command ("look at " + obj);
  else if (button == 1)
    owner->try_run_command ("take " + obj);
  else if (button == 2)
    owner->try_run_command ("speak to " + obj);
  else if (button == 3)
    owner->try_run_command ("go to " + obj);
}

void ObjectsWidget::set_contents (const vector<vector <string> > &v)
{
  m_refListStore->clear();
  for (uint i = 0; i < v.size(); i ++)
    {
      Gtk::TreeModel::Row row = *(m_refListStore->append());
      row[m_columns.name] = v[i][0];
      row[m_columns.type] = v[i][1];
    }
}

ObjectsWidget::~ObjectsWidget() {}

void ObjectsWidget::on_drag_data_get (const Glib::RefPtr<Gdk::DragContext>& context, Gtk::SelectionData& selection_data, guint info, guint time)
{
  //Glib::ustring out_dat = "O" + (*m_TreeView.get_selection()->get_selected())[m_columns.m_col_text];
  Glib::ustring out_dat = (*m_TreeView.get_selection()->get_selected())[m_columns.name];

  std::cerr << "Sending data: '" << out_dat << "'" << std::endl;  
  selection_data.set (selection_data.get_target(), out_dat);
}


void ObjectsWidget::on_drag_data_recvd (const Glib::RefPtr<Gdk::DragContext>& context, int x, int y, const Gtk::SelectionData& selection_data, guint info, guint time)
{
  Gtk::TreeModel::Path path;
  Gtk::TreeViewDropPosition pos;
  //iterator iter = m_refListStore->get_iter (path);
  
  m_TreeView.get_dest_row_at_pos (x, y, path, pos);


  if (selection_data.get_length() >= 0) {
    /*
    string sdata = selection_data.get_data_as_string();
    char src = sdata[0];
    string dobj = sdata.substr (1);
    */
    string dobj = selection_data.get_data_as_string();
    Glib::ustring iobj = ((*m_refListStore->get_iter(path))[m_columns.name]);
    int pushed_button = owner->pushed_button;
   
    if (pushed_button == 1)
      {
	cerr << "Using '" << selection_data.get_data_as_string() << "' on '" 
	     << (*m_refListStore->get_iter(path))[m_columns.name] 
	     <<  "'" << endl;
	owner->try_run_command ("use " + dobj + " on " + iobj);
      }
    else if (pushed_button == 3)
      {
	cerr << "Giving '" << selection_data.get_data_as_string() << "' to '" 
	     << (*m_refListStore->get_iter(path))[m_columns.name]
	     << "'" << endl;
	owner->try_run_command ("give " + dobj + " to " + iobj);
      }
    else
      {
	cerr << "???? '" << selection_data.get_data_as_string() << "' on '" 
	     << (*m_refListStore->get_iter(path))[m_columns.name] 
	     << "'" << endl;
      }
  } else {
    cerr << "Used blank on " 
	 << (*m_refListStore->get_iter(path))[m_columns.name] 
	 << std::endl;
  }
  context->drag_finish (false, false, time);
}
