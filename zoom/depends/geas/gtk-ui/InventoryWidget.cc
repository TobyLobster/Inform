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

#include "InventoryWidget.hh"
#include <iostream>
//#include <sstream>
#include "GeasWindow.hh"
#include "general.hh"

using namespace std;

InventoryWidget::InventoryWidget(GeasWindow *in_owner) : owner (in_owner), widget_name ("Inventory:"), widget_desc ("Left Drag: Use, Right Drag: Give")
{
  sw.set_policy (Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);

  pack_start (widget_name, false, false);
  pack_start (widget_desc, false, false);

  m_refListStore = Gtk::ListStore::create (m_columns);

  m_TreeView.set_model (m_refListStore);

  m_TreeView.append_column ("Items", m_columns.m_col_text);

  std::list<Gtk::TargetEntry> srcTargets, destTargets;
  //srcTargets.push_back ( Gtk::TargetEntry ("room_object") );
  srcTargets.push_back ( Gtk::TargetEntry ("inv_object") );
  destTargets.push_back ( Gtk::TargetEntry ("room_object") );
  destTargets.push_back ( Gtk::TargetEntry ("inv_object") );

  m_TreeView.enable_model_drag_source (srcTargets);
  m_TreeView.enable_model_drag_dest (destTargets);
  m_TreeView.signal_drag_data_get().connect ( sigc::mem_fun (*this, &InventoryWidget::on_drag_data_get));
  m_TreeView.signal_drag_data_received().connect ( sigc::mem_fun (*this, &InventoryWidget::on_drag_data_recvd));
  //m_TreeView.set_headers_visible (false);

  m_TreeView.signal_button_press_event().connect_notify (sigc::mem_fun (*this, &InventoryWidget::handle_button_press_event));
  m_TreeView.signal_button_release_event().connect_notify (sigc::mem_fun (*this, &InventoryWidget::handle_button_release_event));

  sw.add (m_TreeView);
  add(sw);

  show_all_children();
}

void InventoryWidget::set_contents (const vector<vector<string> > &v)
{
  m_refListStore->clear();
  for (uint i = 0; i < v.size(); i ++)
    {
      Gtk::TreeModel::Row row = *(m_refListStore->append());
      row[m_columns.m_col_text] = v[i][0];
    }
}


InventoryWidget::~InventoryWidget() {}

void InventoryWidget::handle_button_press_event(GdkEventButton* event)
{
  owner->pushed_button = event->button;
  //std::cerr << "Pushed button '" << event->button << "'" << std::endl;
}

void InventoryWidget::handle_button_release_event(GdkEventButton* event)
{
  //std::cerr << "Released button '" << event->button << "'" << std::endl;
}


const char *get_typeid(const Gdk::DragContext &obj) { return typeid(obj).name(); }

void InventoryWidget::on_drag_data_get (const Glib::RefPtr<Gdk::DragContext>& context, Gtk::SelectionData& selection_data, guint info, guint time)
{
  //Glib::ustring out_dat = "I" + (*m_TreeView.get_selection()->get_selected())[m_columns.m_col_text];
  Glib::ustring out_dat = (*m_TreeView.get_selection()->get_selected())[m_columns.m_col_text];
  //std::cerr << "Typeid is " << typeid (context).name() << std::endl;
  ////std::cerr << "Typeid is " << get_typeid (&context) << std::endl;

  std::cerr << "Sending data: '" << out_dat << "'" << std::endl;  
  selection_data.set (selection_data.get_target(), out_dat);
}

void InventoryWidget::on_drag_data_recvd (const Glib::RefPtr<Gdk::DragContext>& context, int x, int y, const Gtk::SelectionData& selection_data, guint info, guint time)
{
  Gtk::TreeModel::Path path;
  Gtk::TreeViewDropPosition pos;
  //iterator iter = m_refListStore->get_iter (path);

  cerr << "About to call mTV.gdrap" << endl;
  if (m_TreeView.get_dest_row_at_pos (x, y, path, pos))
    {
      cerr << "   (returned true)" << endl;
      if (selection_data.get_length() >= 0) {
	//string sdata = selection_data.get_data_as_string();
	//char src = sdata[0];
	//string dobj = sdata.substr (1);
	string dobj = selection_data.get_data_as_string();
	Glib::ustring iobj = ((*m_refListStore->get_iter(path))[m_columns.m_col_text]);
	int pushed_button = owner->pushed_button;
	
	if (pushed_button == 1)
	  {
	    cerr << "Using '" << selection_data.get_data_as_string() << "' on '" 
		 << (*m_refListStore->get_iter(path))[m_columns.m_col_text] 
		 <<  "'" << endl;
	    owner->try_run_command ("use " + dobj + " on " + iobj);
	  }
	else if (pushed_button == 3)
	  {
	    cerr << "Giving '" << selection_data.get_data_as_string() << "' to '" 
		 << (*m_refListStore->get_iter(path))[m_columns.m_col_text] 
		 << "'" << endl;
	    owner->try_run_command ("give " + dobj + " to " + iobj);
	  }
	else
	  {
	    cerr << "???? '" << selection_data.get_data_as_string() << "' on '" 
		 << (*m_refListStore->get_iter(path))[m_columns.m_col_text] 
		 << "'" << endl;
	  }
      } else {
	cerr << "o_d_d_r () 4a" << endl;
	//if (m_refListStore->get_iter(path))
	cerr << "Used blank on " 
	     << (*m_refListStore->get_iter(path))[m_columns.m_col_text] 
	     << std::endl;
      }
    }
  else
    {
      cerr << "   (returned false)" << endl;
    }
  context->drag_finish (false, false, time);
}
