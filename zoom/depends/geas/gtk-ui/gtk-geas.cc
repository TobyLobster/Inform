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


#include "GeasWindow.hh"

#include <gtkmm/main.h>
#include <gtkmm/filechooserdialog.h>
#include <gtkmm/stock.h>
#include "general.hh"

using namespace std;

int main(int argc, char *argv[])
{
  Gtk::Main kit(argc, argv);

  cerr << endl;

  GeasWindow window;

  string fname;

  //fname = "../games/hungry goblin.cas";
  //fname = "/home/tilford/Desktop/Comp06/Comp06/quest/beam/beam.asl";
  fname = "demo-typelib.asl";

  if (argc > 1)
    fname = argv[1];
  else if (fname == "")
    {
      Gtk::FileChooserDialog dialog ("Choose .ASL or .CAS file", 
				     Gtk::FILE_CHOOSER_ACTION_OPEN);

      Gtk::FileFilter filter_quest;
      filter_quest.set_name("Quest files");
      filter_quest.add_pattern ("*.cas");
      filter_quest.add_pattern ("*.CAS");
      filter_quest.add_pattern ("*.asl");
      filter_quest.add_pattern ("*.ASL");
      dialog.add_filter(filter_quest);
      
      Gtk::FileFilter filter_any;
      filter_any.set_name("Any files");
      filter_any.add_pattern("*");
      dialog.add_filter(filter_any);

      dialog.add_button(Gtk::Stock::CANCEL, Gtk::RESPONSE_CANCEL);
      dialog.add_button(Gtk::Stock::OPEN, Gtk::RESPONSE_OK);



      int result = dialog.run();

      
      switch(result)
	{
	case(Gtk::RESPONSE_OK):
	  {
	    std::cerr << "Open clicked." << std::endl;
	    
	    fname = dialog.get_filename(); //Notice that it is a std::string, not a Glib::ustring.
	    std::cerr << "File selected: " <<  fname << std::endl;
	    break;
	  }
	case(Gtk::RESPONSE_CANCEL):
	  {
	    std::cerr << "Cancel clicked." << std::endl;
	    break;
	  }
	default:
	  {
	    std::cerr << "Unexpected button clicked." << std::endl;
	    break;
	  }
	}
    }
  if (fname != "")
    {
      window.set_game (fname);
      Gtk::Main::run(window); //Shows the window and returns when it is closed.
      //window.show();
    }
  return 0;
}
