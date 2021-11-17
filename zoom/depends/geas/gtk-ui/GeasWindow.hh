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
#include "InventoryWidget.hh"
#include "ObjectsWidget.hh"
#include "ChoiceWidget.hh"
#include "VariableWidget.hh"
#include "CompassWidget.hh"
#include <gtkmm/paned.h>
#include <gtkmm/textview.h>
#include <gtkmm/box.h>
#include <gtkmm/window.h>
#include <gtkmm/entry.h>
#include <gtkmm/texttag.h>
#include <map>

#include "GeasRunner.hh"

class GeasWindow;

class GeasWindowInterface : public GeasInterface
{
private:
  GeasWindow *gw;

protected: 
  virtual std::string absolute_name (std::string rel_name, std::string parent) const;
  virtual std::string get_file (std::string) const;
  virtual GeasResult print_normal (std::string);
  virtual GeasResult print_newline ();
  virtual GeasResult set_style (const GeasFontStyle &);
  
  virtual GeasResult wait_keypress () { return r_not_supported; }
  //virtual GeasResult pause (int msec) { gw->pause(msec); return r_success; }
  virtual GeasResult pause (int msec);
  virtual GeasResult clear_screen () { return r_not_supported; }
  //virtual std::string get_string() { return ""; }
  //virtual std::string get_string() { return gw->get_string(); }
  virtual std::string get_string();

  virtual void set_foreground (std::string s);
  virtual void set_background (std::string s);
  //virtual uint make_choice (std::string label, std::vector<std::string> v) { return gw->make_choice (label, v); }
  virtual uint make_choice (std::string label, std::vector<std::string> v);

  GeasResult show_image (std::string filename, std::string resolution,
			 std::string caption, ...)
  { return r_not_supported; }

  GeasResult play_sound (std::string filename, bool looped, bool sync)
  { return r_not_supported; }


  GeasResult speak (std::string)  { return r_not_supported; }
public:
  GeasWindowInterface (GeasWindow *in_gw) : gw(in_gw) { update_style(); }

  virtual void debug_print (std::string s);
};


class GeasWindow : public Gtk::Window
{
private:
  bool new_text; // has new text been printed since the last "scroll to end"?
  enum RunnerState
    {
      RS_NO_GAME,    //  everything locked
      RS_EXPECTING,  //  waiting for the player to enter a command
      RS_RUNNING,    //  running a command (everything locked)
      RS_CHOICE,     //  waiting for the player to choose from a menu 
      //                   (all but choice box locked)
      RS_TIMER,      //  running timers (everything locked)
      RS_GET_STRING, //  getting a string for a script (all but input locked)
      RS_GOT_STRING, //  recvd string, about to return
      RS_WAIT,       //  waiting for a keypress
      RS_PAUSE,      //  everything locked
      RS_WAS_PAUSED  //  pause over, everything locked
    } run_state;

  typedef Gtk::TextTag Tag;
  ChoiceWidget cw;

  //Glib::RefPtr<Tag> default_text;
  //Glib::ArrayHandle<Glib::RefPtr<Tag> > default_tags;
  //vector<Glib::RefPtr<Tag> > default_tags;
  Glib::RefPtr<Tag> current_tag;

  std::map <GeasFontStyle, Glib::RefPtr<Tag>, GeasFontStyleCompare> styles;
  typedef std::map <GeasFontStyle, Glib::RefPtr<Tag>, GeasFontStyleCompare>::iterator map_iter;

  friend class GeasWindowInterface;
  //GeasWindowInterface gwi;
  GeasRunner* gr;

  Glib::RefPtr<Gtk::TextMark> end_scroll;
  Gtk::HPaned pan1;
  Gtk::TextView tv;
  Gtk::Entry ent;
  Gtk::VBox rpane, lpane;
  Gtk::ScrolledWindow sw;
  InventoryWidget iw;
  ObjectsWidget ow;
  VariableWidget vw;
  CompassWidget cmpw;

  void handle_activate ();
  void scroll_to_end ();
  void end_turn_events ();
  bool each_second ();

public:
  int pushed_button;

  static void yield (bool blocking) { gtk_main_iteration_do (blocking); }
  void pause (int msec);
  bool end_pause ();
  void set_game (std::string fname);
  uint make_choice (std::string label, std::vector<std::string> v) { return cw.make_choice (label, v); }
  GeasWindow ();
  virtual ~GeasWindow();
  GeasResult set_style (const GeasFontStyle &style);
  GeasResult print_normal (std::string s);
  //string get_file (string s);
  void set_fg (std::string s) { tv.modify_text (Gtk::STATE_NORMAL, Gdk::Color(s)); yield(false); }
  void set_bg (std::string s) { tv.modify_base (Gtk::STATE_NORMAL, Gdk::Color(s)); yield(false); }
  virtual std::string get_string ();
  virtual std::string get_file (std::string) const;
  void try_run_command (std::string s);
};
