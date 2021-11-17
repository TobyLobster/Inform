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

#include <iostream>
#include <fstream>

#include "GeasWindow.hh"
#include "GeasRunner.hh"
#include "general.hh"

using namespace std;

void GeasWindow::handle_activate() 
{ 
  if (run_state == RS_EXPECTING)
    {
      //int xx, yy, ww, hh, dd;
      //static int j = 0;
      //std::cerr << "GW.ha: Entered text: '" << ent.get_text() << "'" << std::endl;
      string cmd = ent.get_text();
      ent.set_text("");
      gr->run_command(cmd);
      //std::cerr << "GW.h_a: Returning." << std::endl;
      end_turn_events();
      scroll_to_end();
    }
  else if (run_state == RS_GET_STRING)
    {
      cout << "Ended Get string\n";
      //got_string = true;
      run_state = RS_GOT_STRING;
    }
}

void GeasWindow::try_run_command (string cmd)
{
  if (run_state == RS_EXPECTING)
    {
      gr->run_command (cmd);
      end_turn_events();
      scroll_to_end();
    }
}

bool GeasWindow::each_second()
{
  if (run_state == RS_EXPECTING)
    {
      run_state = RS_TIMER;
      gr->tick_timers();
      scroll_to_end();
      run_state = RS_EXPECTING;
    }
  return true;
}

string GeasWindow::get_string ()
{
  RunnerState tmp = run_state;
  run_state = RS_GET_STRING;

  scroll_to_end();

  do
    {
      yield (true);
    }
  while (run_state == RS_GET_STRING);

  run_state = tmp;
  string rv = ent.get_text();
  ent.set_text ("");
  return rv;
}

void GeasWindow::pause (int msec)
{
  RunnerState tmp = run_state;
  run_state = RS_PAUSE;

  sigc::slot<bool> my_slot = sigc::mem_fun (*this, &GeasWindow::end_pause);
  sigc::connection conn = Glib::signal_timeout().connect (my_slot, msec);

  scroll_to_end();

  do
    {
      yield (true);
    }
  while (run_state == RS_PAUSE);

  run_state = tmp;
}

bool GeasWindow::end_pause ()
{
  run_state = RS_WAS_PAUSED;
  return false;
}

void GeasWindow::end_turn_events()
{
  ow.set_contents (gr->get_room_contents());

  iw.set_contents (gr->get_inventory());

  vstring svars = gr->get_status_vars();
  vw.set_contents (svars);
  if (svars.size() == 0)
    vw.hide();
  else
    vw.show();

  cmpw.set_valid_exits (gr->get_valid_exits());
  
  ent.grab_focus();
}

string GeasWindow::get_file (string fname) const
{
  ifstream ifs;
  ifs.open(fname.c_str(), ios::binary);
  if (! ifs.is_open())
    {
      cerr << "Couldn't open " << fname << endl;
      return "";
    }
  string rv;
  char ch;
  ifs.get(ch);
  while (!ifs.eof())
    {
      rv += ch;
      ifs.get(ch);
    }
  return rv;
}
    

GeasWindow::GeasWindow() : lpane(false), iw(this), ow(this), cmpw(this)
{
  gr = GeasRunner::get_runner (new GeasWindowInterface(this));
  run_state = RS_NO_GAME;
  set_default_size (700, 700);

  tv.set_editable(false);
  tv.set_wrap_mode (Gtk::WRAP_WORD);
  current_tag = tv.get_buffer()->create_tag();
  //tv.can_focus(false);
  sw.add(tv);

  //sw.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);
  sw.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS);
  end_scroll = tv.get_buffer()->create_mark(tv.get_buffer()->end(), false);
  lpane.pack_start (sw, true, true);
  //sw.can_focus(false);
  //lpane.can_focus(false);

  ent.signal_activate().connect_notify (sigc::mem_fun (*this, &GeasWindow::handle_activate));
  //ent.can_focus(true);

  lpane.pack_start (ent, false, false);
  pan1.pack1 (lpane);

  rpane.add(iw);
  rpane.add(vw);
  rpane.add(ow);
  rpane.add(cmpw);
  //iw.can_focus(false);
  //ow.can_focus(false);
  //vw.can_focus(false);
  //pan1.can_focus(false);
  pan1.pack2 (rpane, false, false);

  add(pan1);
  show_all_children();
  ent.grab_focus();

  sigc::slot<bool> my_slot = sigc::mem_fun (*this, &GeasWindow::each_second);
  sigc::connection conn = Glib::signal_timeout().connect (my_slot, 1000);
}

void GeasWindow::set_game (string fname)
{
  gr->set_game (fname);
  run_state = RS_EXPECTING;
  end_turn_events();
}

GeasWindow::~GeasWindow() {}

GeasResult GeasWindow::print_normal (string s)
{
  new_text = true;
  tv.get_buffer()->insert_with_tag(tv.get_buffer()->end(), s, current_tag);
  return r_success;
}

GeasResult GeasWindowInterface::print_normal (string s)
{
  return gw->print_normal(s);
}

GeasResult GeasWindowInterface::print_newline ()
{
  return print_normal ("\n");
}


GeasResult GeasWindowInterface::set_style (const GeasFontStyle &style)
{ return gw->set_style(style); }


GeasResult GeasWindow::set_style (const GeasFontStyle &style)
{
  //cerr << "Changing style to " << style << " -> ";

  GeasWindow::map_iter i = styles.find(style);
  if (i == styles.end())
    {
      //cerr << "Allocating new tag" << endl;
      Glib::RefPtr<Tag> newtag = tv.get_buffer()->create_tag();
      if (style.is_underlined)
	newtag->property_underline() = Pango::UNDERLINE_SINGLE;
      if (style.is_bold)
	newtag->property_weight() = Pango::WEIGHT_BOLD;
      if (style.is_italic)
	newtag->property_style() = Pango::STYLE_ITALIC;
      //newtag->size = style.size;  // TODO
      if (style.color != "")
	{
	  /*
	  Gdk::Color c;
	  c.set(style.color);
	  cerr << "Setting foreground to " << c << "\n";
	  // TODO Will this incorrectly allocate a color multiple times? 
	  Gdk::Colormap::get_system()->alloc_color(c);
	  //newtag->property_foreground() = style.color;
	  newtag->property_foreground_gdk() = c;
	  */
	  newtag->property_foreground() = style.color;
	}
      if (style.justify == JUSTIFY_LEFT)
	newtag->property_justification() = Gtk::JUSTIFY_LEFT;
      else if (style.justify == JUSTIFY_CENTER)
	newtag->property_justification() = Gtk::JUSTIFY_CENTER;
      else if (style.justify == JUSTIFY_RIGHT)
	newtag->property_justification() = Gtk::JUSTIFY_RIGHT;
      //cerr << "Pushing into default_tags" << endl;
      //default_tags[0] = newtag;
      current_tag = newtag;
      //cerr << "Adding into style map" << endl;
      styles[style] = newtag;
      //cerr << "Done!" << endl;
    }
  else
    {
      //cerr << "Reusing tag" << endl;
      current_tag = i->second;
      //default_tags[0] = i->second;
      //cerr << "reused" << endl;
    }
  //return r_not_supported;

  return r_success;
}

void GeasWindowInterface::set_foreground (string s) 
{ 
  cerr << "Setting foreground to '" << s << "'.\n";
  if (s != "") 
    {
      gw->set_fg(s);
      GeasWindow::yield(false);
    }
  //return r_success; 
}

void GeasWindowInterface::set_background (string s) 
{ 
  cerr << "Setting background to '" << s << "'.\n";
  if (s != "") 
    {
      gw->set_bg(s); 
      GeasWindow::yield(false);
    }
  //return r_success; 
}

void GeasWindow::scroll_to_end()
{
  if (!new_text)
    return;
  new_text = false;

  Gtk::TextBuffer::iterator it;
  //int trailing;

  //Gdk::Rectangle r;
  //tv.get_buffer()->destroy_mark(end_scroll);
  //end_scroll = tv.get_buffer()->create_mark(tv.get_buffer()->end(), false);

  /*
  tv.get_visible_rect(r);
  tv.get_iter_at_position (it, trailing, r.get_x() + r.get_width(),
			   r.get_y() + r.get_height());
  */
  it = tv.get_buffer()->end();
  tv.get_buffer()->move_mark (end_scroll, it);
  tv.scroll_to(end_scroll);
  

  //tv.get_buffer()->move_mark (end_scroll, tv.get_buffer()->end());
}

string GeasWindowInterface::absolute_name (std::string rel_name, std::string parent) const {
  cerr << "absolute_name ('" << rel_name << "', '" << parent << "')\n";
  assert (parent[0] == '/');
  if (rel_name[0] == '/')
    {
      cerr << "  --> " << rel_name << "\n";
      return rel_name;
    }
  vector<string> path;
  uint dir_start = 1, dir_end;
  while (dir_start < parent.length()) 
    {
      dir_end = dir_start;
      while (dir_end < parent.length() && parent[dir_end] != '/')
	dir_end ++;
      path.push_back (parent.substr (dir_start, dir_end - dir_start));
      dir_start = dir_end + 1;
    }
  path.pop_back();
  dir_start = 0;
  string tmp;
  while (dir_start < rel_name.length()) 
    {
      dir_end = dir_start;
      while (dir_end < rel_name.length() && rel_name[dir_end] != '/')
	dir_end ++;
      tmp = rel_name.substr (dir_start, dir_end - dir_start);
      dir_start = dir_end + 1;
      if (tmp == ".")
	continue;
      else if (tmp == "..")
	path.pop_back();
      else
	path.push_back (tmp);
    }
  string rv;
  for (uint i = 0; i < path.size(); i ++)
    rv = rv + "/" + path[i];
  cerr << " ---> " << rv << "\n";
  return rv;
}

string GeasWindowInterface::get_file (string s) const { return gw->get_file(s); }

uint GeasWindowInterface::make_choice (string label, vector<string> v)
{ return gw->make_choice (label, v); }

std::string GeasWindowInterface::get_string() { return gw->get_string(); }


void GeasWindowInterface::debug_print (std::string s) { gw->print_normal ("   debug:  " + s + "\n"); cerr << "   debug:  " + s + "\n"; }

GeasResult GeasWindowInterface::pause (int msec) { gw->pause(msec); return r_success; }
