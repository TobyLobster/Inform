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

#include "CompassWidget.hh"
#include "GeasWindow.hh"
#include "general.hh"

using namespace std;

#define ARRAYSIZE(ar)  (sizeof (ar) / sizeof (*ar))

const string compass_widget_dir_labels [] = { "NW", "N", "NE", "W", "out", "E", "SW", "S", "SE", "U", "D" };

const string compass_widget_dir_names [] = 
  { "northwest", "north", "northeast", "west", "out", "east", "southwest", 
    "south", "southeast", "up", "down" };



CompassWidget::CompassWidget (GeasWindow *in_owner) : 
  owner (in_owner), 
  //on_imgs (Gdk::Pixbuf::create_from_file ("geas-dirs-ona.png")), 
  //off_imgs (Gdk::Pixbuf::create_from_file ("geas-dirs-offa.png")),
  ltable (3, 3, true), rtable (2, 1, true)
{
  for (uint i = 0; i < ARRAYSIZE (compass_widget_dir_labels); i ++)
    {
      //buttons.push_back (Gtk::Button (compass_widget_dir_labels[i]));
      /*
      buttons[i].signal_clicked().connect (sigc::bind (sigc::mem_fun (*this, &CompassWidget::on_button_clicked), i));
      if (i < 9)
	ltable.add(buttons[i]);
      else
	rtable.add(buttons[i]);
      */
      Gtk::Button *b = manage (new Gtk::Button (compass_widget_dir_labels[i]));
      b->signal_clicked().connect (sigc::bind (sigc::mem_fun (*this, &CompassWidget::on_button_clicked), i));
      
      if (i < 9)
	//ltable.add (*b);
	ltable.attach (*b, (i%3), (i%3)+1, (i/3), (i/3)+1);
      else
	rtable.attach (*b, 0, 1, i-9, i-8);
	//rtable.add (*b);
      //add (*b);

      buttons.push_back (b);
    }
  add (ltable);
  add (rtable);
  show();
}

void CompassWidget::on_button_clicked (uint button_num)
{
  owner->try_run_command (compass_widget_dir_names[button_num]);
}

void CompassWidget::set_valid_exits (const vector<bool> &v)
{
  assert (v.size() == buttons.size());
  for (uint i = 0; i < v.size(); i ++)
    buttons[i]->set_sensitive (v[i]);
}
