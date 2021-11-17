
/*
 * wxgeas.cpp
 * Main file for user interface
 */

#include "wxgeas.hh"
#include <iostream>
#include <fstream>

#include "general.hh"

//#define PANEL_BORDER wxSIMPLE_BORDER
#define PANEL_BORDER wxSUNKEN_BORDER

using namespace std;

wxString cnv (const std::string &s) { return wxString::FromAscii(s.c_str()); }
string rcnv (const wxString &s) { return string (s.mb_str()); }

static wxDataFormat DF_Inv (_T("Geas Inventory Texts"));


void set_contents (wxListView *lb, const v2string &v, int count) {
  int current_item_number = lb->GetFirstSelected();
  int new_item_number = wxNOT_FOUND;

  wxString current;
  if (current_item_number != wxNOT_FOUND)
    current = lb->GetItemText (current_item_number);
  
  wxSize size = lb->GetSize();
  for (int i = 0; i < count; i ++)
    lb->SetColumnWidth(i, size.x / count);

  lb->DeleteAllItems();
  for (uint i = 0; i < v.size(); i ++)
    {
      wxString tmp = cnv (v[i][0]);
      long rownum = lb->InsertItem (i, tmp, 0);

      if (count > 1)
        lb->SetItem (rownum, 1, cnv(v[i][1]));
      if (current_item_number != wxNOT_FOUND && tmp == current)
        new_item_number = i;
    }
  if (new_item_number != wxNOT_FOUND)
    lb->Select (new_item_number);
}


IMPLEMENT_APP(GeasApp)

bool GeasApp::OnInit()
{
  GeasFrame *frame = new GeasFrame( _("wxGeas"), wxPoint(50,50), wxSize(450,340) );
  frame->Show(TRUE);
  SetTopWindow(frame);

  string game_name;
  if (argc == 1)
    {
      game_name = rcnv (choose_game);
      //game_name = "/media/sda6/Quest/demo-typelib.asl";
      //game_name = "/media/sda6/Quest/hungry goblin.cas";
    }
  else
    game_name = rcnv(argv[1]);
  frame->set_game (game_name);

  return TRUE;
} 

void GeasFrame::set_game (string fname) {
  gr->set_game (fname);
  run_state = WGUI_EXPECTING;
  end_turn_events();
}

/*
ostream &operator << (ostream &o, const wxDataFormat &wdf) {
  o << "DF <" << wdf.GetType() << ":" << rcnv (wdf.GetId()) << ">";
  return o;
}
*/

class GeasDragObject : public wxDataObjectSimple
{
  wxString m_data;

public:

  GeasDragObject (const wxString &dat = wxEmptyString) : wxDataObjectSimple (DF_Inv)
  { 
    SetString (dat);
  }

  virtual size_t GetDataSize() const 
  {
    return m_data.length() * sizeof (wxString::char_type);
  }

  void SetString (const wxString &str) 
  {
    m_data = str;
  }

  virtual bool SetData (size_t len, const void *buf) 
  {
    this->SetString (wxString ((const wxString::char_type*) buf, 
			       len / sizeof (wxString::char_type)));
    return true;
  }

  virtual bool GetDataHere(void *buf) const { 
    memcpy (buf, m_data.wc_str(), 
	    m_data.length() * sizeof (wxString::char_type));
    return true;
  }

  wxString GetString () { return m_data; }
};


InventControl::InventControl(GeasFrame *in_parent) :
  wxPanel (in_parent, -1, wxDefaultPosition, wxDefaultSize, PANEL_BORDER),
  parent(in_parent), src (this)
{
  SetDropTarget (new InventTarget (this));

  wxSizer *sizer = new wxBoxSizer (wxVERTICAL);
  sizer->Add (new wxStaticText (this, -1, _T("Inventory")), 0, wxEXPAND, 0);

  // NO_HEADER is a workaround for the problem with object detection

  data = new wxListView (this, ID_Invent, wxDefaultPosition, wxDefaultSize, wxLC_REPORT | wxLC_SINGLE_SEL | wxLC_NO_HEADER);
  sizer->Add (data, 1, wxEXPAND, 0);
  
  wxListItem itemCol;
  itemCol.SetText (_T("Item"));
  data->InsertColumn (0, itemCol);

  SetSizer (sizer);

  popup = new wxMenu ();
  popup->Append (ID_Invent_Look, _T("Look at"));
  popup->Append (ID_Invent_Examine, _T("Examine"));
  popup->Append (ID_Invent_Drop, _T("Drop"));
  popup->Append (ID_Invent_Use, _T("Use"));
}

void InventControl::try_action (wxString verb)
{
  //if (parent->run_state != RunnerState::WGUI_EXPECTING)
  //  return;
  if (data->GetFirstSelected() != -1)
    parent->run_command (verb + data->GetItemText(data->GetFirstSelected()));
}

void InventControl::SetContents (vector<vector<string> > v)
{
  set_contents (data, v, 1);
}

VarControl::VarControl (GeasFrame *in_parent):
  wxPanel (in_parent, -1, wxDefaultPosition, wxDefaultSize, PANEL_BORDER), 
  parent (in_parent)
{
  data = new wxListBox (this, -1);
  SetSizer (new wxBoxSizer(wxVERTICAL));
  GetSizer()->Add (data, 1, wxEXPAND, 0);
}

bool VarControl::SetContents (vector<string> v)
{
  data->Clear();
  for (uint i = 0; i < v.size(); i ++)
    data->Append (cnv (v[i]));

  if (v.size() == 0)
    return Hide();
  else
    return Show();
}

ObjectControl::ObjectControl (GeasFrame *in_parent) : 
  wxPanel (in_parent, -1, wxDefaultPosition, wxDefaultSize, PANEL_BORDER), 
  parent (in_parent), src (this)
{
  SetDropTarget (new ObjectTarget (this));

  wxSizer *sizer = new wxBoxSizer (wxVERTICAL);

  wxBoxSizer *object_buttons = new wxBoxSizer (wxHORIZONTAL);
  object_buttons->Add (new wxButton (this, ID_Object_Take,
				     _T("Take")),      0, wxEXPAND, 0);
  object_buttons->Add (new wxButton (this, ID_Object_Examine,
				     _T("Examine")),   0, wxEXPAND, 0);
  object_buttons->Add (new wxButton (this, ID_Object_Speak,
				     _T("Speak to")),  0, wxEXPAND, 0);
  sizer->Add (object_buttons);

  wxListItem itemCol;
  data = new wxListView (this, ID_Object, wxDefaultPosition, wxDefaultSize, wxLC_REPORT | wxLC_SINGLE_SEL | wxLC_NO_HEADER);
  itemCol.SetText (_T("Object"));
  data->InsertColumn (0, itemCol);
  itemCol.SetText (_T("Type"));
  data->InsertColumn (1, itemCol);

  sizer->Add (data, 1, wxEXPAND, 0);
  SetSizer (sizer);
}

void ObjectControl::try_action (wxString verb)
{
  //if (parent->run_state != WGUI_EXPECTING)
  //  return;
  if (data->GetFirstSelected() != -1)
    parent->run_command (verb + data->GetItemText(data->GetFirstSelected()));
}

void ObjectControl::SetContents (vector<vector<string> > v)
{
  set_contents (data, v, 2);
}

void InventControl::BeginDrag (wxListEvent &evt)
{
  cout << "IBeginDrag (" << rcnv(data->GetItemText (evt.GetIndex())) << ")" << endl;
  wxDropSource dragSource (this);

  //GeasDragObject my_data (data->GetItemText (evt.GetIndex()));  
  GeasDragObject my_data (_T("use ") + data->GetItemText (evt.GetIndex()) + _T(" on "));  
  //dragSource.SetData (_T("use ") + my_data.GetString() + _T(" on "));
  dragSource.SetData (my_data);
  cout << "IBeginDrag with object '" << rcnv (my_data.GetString()) << "'.\n";
  wxDragResult result = dragSource.DoDragDrop (TRUE);


  switch (result) 
    {
    case wxDragCopy: cout << "returning BeginDrag (Copy)\n" << endl; break;
    case wxDragMove: cout << "returning BeginDrag (Move)\n" << endl; break;
    default: cout << "returning BeginDrag (default)\n" << endl; break;
    }
}

void InventControl::BeginRDrag (wxListEvent &evt)
{
  wxDropSource dragSource (this);
  cout << "IBeginRDrag (" << rcnv(evt.GetText()) << ")" << endl;
  GeasDragObject my_data (_T("give ") + data->GetItemText (evt.GetIndex()) + _T(" to "));  
  dragSource.SetData (my_data);
  //dragSource.SetString (_T("give ") + my_data.GetString() + _T(" to "));
  cout << "IBeginDrag with object '" << rcnv (my_data.GetString()) << "'.\n";
  dragSource.DoDragDrop (TRUE);
}

void ObjectControl::BeginDrag (wxListEvent &evt)
{
  cout << "OBeginDrag (" << rcnv(evt.GetText()) << ")" << endl;
}

void ObjectControl::BeginRDrag (wxListEvent &evt)
{
  cout << "OBeginRDrag (" << rcnv(evt.GetText()) << ")" << endl;
}


InventTarget::InventTarget (InventControl *in_p) : parent (in_p) { 
  SetDataObject (new GeasDragObject());
}

ObjectTarget::ObjectTarget (ObjectControl *in_p) : parent (in_p) {
  SetDataObject (new GeasDragObject());
}

ostream &operator << (ostream &o, wxPoint p) { o << "(" << p.x << ", " << p.y << ") "; return o; }

bool InventTarget::OnDrop (wxCoord x, wxCoord y) {
  wxPoint where (x, y);

  wxPoint p = parent->GetPosition();
  wxPoint gp = parent->parent->GetPosition();
  wxPoint pd = parent->data->GetPosition();
  wxPoint pd2;
  parent->data->GetItemPosition(0, pd2);
  //std::cout << "   Adjusted to " << x - p.x << ", " << y - p.y << ".\n";
  std::cout << "I::OnDrop " << where << 
    "; parent at " << p << "; diff1 is " << where - p << 
    "; grandparent at " << gp << "; diff2 is " << where - gp << 
    "; data at " << pd << "; diff is " << where - pd <<
    "; data[0] at " << pd2 << "; diff is " << where - pd2 <<
    ".\n";

  ///* HACK workaround: */
  //parent->data->GetItemPosition (1, pd2);
  //wxPoint offset = where - pd - pd2; // Assume row height ~= header height
  
  wxPoint offset = where - pd;

  int flags;
  long rownum = parent->data->HitTest (offset, flags);
  std::cout << "HitTest() -> " << rownum << "; flags == " << flags << std::endl;
  if (rownum > -1) 
    {
      target_name = parent->data->GetItemText (rownum);
      cout << "  -> " << rcnv (target_name) << ".\n";
      return true;
    }
  cout << "OnDrop() returning false\n";
  return false;
}

bool ObjectTarget::OnDrop (wxCoord x, wxCoord y) {
  wxPoint where (x, y);
  wxPoint pd = parent->data->GetPosition();

  ///* HACK workaround: */
  //parent->data->GetItemPosition (1, pd2);
  //wxPoint offset = where - pd - pd2; // Assume row height ~= header height
  
  wxPoint offset = where - pd;

  int flags;
  long rownum = parent->data->HitTest (offset, flags);

  if (rownum > -1) 
    {
      target_name = parent->data->GetItemText (rownum);
      return true;
    }
  return false;
}


wxDragResult InventTarget::OnData (wxCoord x, wxCoord y, wxDragResult def) { 
  //if (run_state != WGUI_EXPECTING)
  //  return wxDragError;
  
  std::cout << "I::OnData ()" <<  std::endl; 
  GetData();

  std::cout << "IT->OD:data_object == '" << rcnv(((GeasDragObject *)GetDataObject())->GetString()) << "'.\n";

  //wxString action = _T("use ") + ((GeasDragObject *)GetDataObject())->GetString() + _T(" on ") + target_name;
  wxString action = ((GeasDragObject *)GetDataObject())->GetString() 
    + target_name;

  parent->parent->run_command (action);

  cout << "Trying to run command: <" << rcnv (action) << ">\n";
  return def;
}

wxDragResult ObjectTarget::OnData (wxCoord x, wxCoord y, wxDragResult def) 
{
  //if (parent->parent->run_state != WGUI_EXPECTING)
  //  return wxDragError;

  GetData();

  wxString action = ((GeasDragObject *)GetDataObject())->GetString() +
    target_name;
  cout << "GDO -> '" << rcnv (((GeasDragObject *)GetDataObject())->GetString())
       << "', target_name --> '" << rcnv (target_name) << "'.\n";
  parent->parent->run_command (action);
  return def;
}


CompassControl::CompassControl (GeasFrame *in_parent) : 
  wxPanel (in_parent, -1, wxDefaultPosition, wxDefaultSize, PANEL_BORDER),
  parent(in_parent) 
{
  wxBoxSizer *main_sizer = new wxBoxSizer (wxHORIZONTAL), 
    *right_sizer = new wxBoxSizer (wxVERTICAL);
  SetSizer (main_sizer);

  wxPanel *left_panel = new wxPanel (this);
  wxGridSizer *left_sizer = new wxGridSizer (3, 3);
  left_panel->SetSizer (left_sizer);
  main_sizer->Add (left_panel);

  int i;
  for (i = 0; i < 9; i ++)
    {
      m_dirs[i] = new wxButton (left_panel, m_button_ids[i], m_button_labels[i], wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
      left_sizer->Add (m_dirs[i], 1, 0, 0);
    }


  wxPanel *right_panel = new wxPanel (this);
  right_panel->SetSizer (right_sizer);
  main_sizer->Add (right_panel);

  for (; i < 11; i ++)
    {
      m_dirs[i] = new wxButton (right_panel, m_button_ids[i], m_button_labels[i], wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
      right_sizer->Add (m_dirs[i], 1, 0, 1);
    }

  /*
  left_sizer->Add(m_dirs[i++] = new wxButton (left_panel, ID_Compass_NW,  _T("NW")), 0, wxEXPAND, 0);
  left_sizer->Add(m_dirs[i++] = new wxButton (left_panel, ID_Compass_N,   _T("N")), 0, wxEXPAND, 0);
  left_sizer->Add(m_dirs[i++] = new wxButton (left_panel, ID_Compass_NE,  _T("NE")), 0, wxEXPAND, 0);
  left_sizer->Add(m_dirs[i++] = new wxButton (left_panel, ID_Compass_W,   _T("W")), 0, wxEXPAND, 0);
  left_sizer->Add(m_dirs[i++] = new wxButton (left_panel, ID_Compass_OUT, _T("OUT")), 0, wxEXPAND, 0);
  left_sizer->Add(m_dirs[i++] = new wxButton (left_panel, ID_Compass_E,   _T("E")), 0, wxEXPAND, 0);
  left_sizer->Add(m_dirs[i++] = new wxButton (left_panel, ID_Compass_SW,  _T("SW")), 0, wxEXPAND, 0);
  left_sizer->Add(m_dirs[i++] = new wxButton (left_panel, ID_Compass_S,   _T("S")), 0, wxEXPAND, 0);
  left_sizer->Add(m_dirs[i++] = new wxButton (left_panel, ID_Compass_SE,  _T("SE")), 0, wxEXPAND, 0);
  main_sizer->Add (left_panel);

  wxPanel *right_panel = new wxPanel (this);
  right_panel->SetSizer (right_sizer);
  right_sizer->Add (m_dirs[i++] = new wxButton (right_panel, ID_Compass_U, _T("U")), 0, wxEXPAND, 0);
  right_sizer->Add (m_dirs[i++] = new wxButton (right_panel, ID_Compass_D, _T("D")), 0, wxEXPAND, 0);
  main_sizer->Add (right_panel);
  */
}

wxString CompassControl::m_button_labels[11] = { _T("NW"), _T("N"), _T("NE"), _T("W"), _T("OUT"), _T("E"), _T("SW"), _T("S"), _T("SE"), _T("U"), _T("D") };

int CompassControl::m_button_ids[11] = { ID_Compass_NW, ID_Compass_N, ID_Compass_NE, ID_Compass_W, ID_Compass_OUT, ID_Compass_E, ID_Compass_SW, ID_Compass_S, ID_Compass_SE, ID_Compass_U, ID_Compass_D };

void CompassControl::SetValidExits (const std::vector<bool>& dir_states)
{
  assert (dir_states.size() == 11);
  for (int i = 0; i < 11; i ++)
    m_dirs[i]->Enable (dir_states[i]);
}

void CompassControl::OnButton  (wxCommandEvent &event)
{
  //if (parent->run_state != WGUI_EXPECTING)
  //  return;

  switch (event.GetId())
    {
    case ID_Compass_NW:   parent->run_command (_T("northwest")); break;
    case ID_Compass_N:    parent->run_command (_T("north")); break;
    case ID_Compass_NE:   parent->run_command (_T("northeast")); break;
    case ID_Compass_W:    parent->run_command (_T("west")); break;
    case ID_Compass_OUT:  parent->run_command (_T("out")); break;
    case ID_Compass_E:    parent->run_command (_T("east")); break;
    case ID_Compass_SW:   parent->run_command (_T("southwest")); break;
    case ID_Compass_S:    parent->run_command (_T("south")); break;
    case ID_Compass_SE:   parent->run_command (_T("southeast")); break;
    case ID_Compass_U:    parent->run_command (_T("up")); break;
    case ID_Compass_D:    parent->run_command (_T("down")); break;
    default:
      cerr << "Bad action: " << event.GetId() << "\n";
    }
}


















GeasFrame::GeasFrame(const wxString& title, const wxPoint& pos, const wxSize& size)
  : wxFrame((wxFrame *)NULL, -1, title, pos, size), inv (this), var (this), obj (this), comp(this),
    run_state (WGUI_NO_GAME)
{
  gr = GeasRunner::get_runner (this);

  wxMenu *menuFile = new wxMenu;

  menuFile->Append( ID_About, _("&About...") );
  menuFile->AppendSeparator();
  menuFile->Append( ID_Quit, _("E&xit") );
  
  wxMenuBar *menuBar = new wxMenuBar;
  menuBar->Append( menuFile, _("&File") );
  
  SetMenuBar( menuBar );
  
  output = new wxTextCtrl (this, -1, _(""), wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE | wxTE_READONLY | wxTE_RICH | wxTE_RICH2 | wxTE_LEFT);


  //wxTextAttr my_style (*wxRED, wxNullColour, wxNullFont, wxTEXT_ALIGNMENT_DEFAULT);
  /*
  wxTextAttr my_style (*wxRED, wxNullColour),
    my_style2 (*wxRED, *wxLIGHT_GREY),
    my_style3 (*wxBLUE, *wxLIGHT_GREY),
    my_style4 (wxNullColour, *wxGREEN);
  */

  /*
  wxTextPos index, index2;

  index2 = output->GetLastPosition();

  output->AppendText (_T("Red text\n"));
  index = index2; index2 = output->GetLastPosition();
  output->SetStyle (index, index2, my_style);

  output->AppendText (_T("Red on grey text\n"));
  index = index2; index2 = output->GetLastPosition();
  output->SetStyle (index, index2, my_style2);

  output->AppendText (_T("Blue on grey text\n"));
  index = index2; index2 = output->GetLastPosition();
  output->SetStyle (index, index2, my_style3);

  output->SetStyle (0, index2, my_style4);
  */
  //output->SetBackgroundColour (*wxGREEN);
  /*
  output->SetDefaultStyle(wxTextAttr(*wxRED));
  output->AppendText(_T("Red text\n"));
  output->SetDefaultStyle(wxTextAttr(wxNullColour, *wxLIGHT_GREY));
  output->AppendText(_T("Red on grey text\n"));
  output->SetDefaultStyle(wxTextAttr(*wxBLUE));
  output->AppendText(_T("Blue on grey text\n"));
  output->SetBackgroundColour (*wxGREEN);
  */

  input = new wxTextCtrl (this, ID_Command_Line);
  input->SetWindowStyle (wxTE_PROCESS_ENTER);
    
  wxBoxSizer *left_sizer = new wxBoxSizer (wxVERTICAL);
  left_sizer->Add (output, 1, wxEXPAND, 0);
  left_sizer->Add (input, 0, wxEXPAND, 0);
  left_sizer->SetSizeHints (this);

  wxBoxSizer *right_sizer = new wxBoxSizer (wxVERTICAL);
  
  right_sizer->Add (&inv, 2, wxEXPAND, 0);
  right_sizer->Add (&var, 1, wxEXPAND, 0);
  right_sizer->Add (&obj, 2, wxEXPAND, 0);
  right_sizer->Add (&comp, 1, 0, 0);

  wxBoxSizer *sizer = new wxBoxSizer (wxHORIZONTAL);
  sizer->Add (left_sizer, 1, wxEXPAND, 0);
  sizer->Add (right_sizer, 0, wxEXPAND, 0);
  
  SetSizer (sizer);

  SetSize (wxSize (600, 600));

  m_timer = new wxTimer (this, ID_Timer_Regular);
  m_timer->Start (1000, wxTIMER_CONTINUOUS);
}

void GeasFrame::OnQuit(wxCommandEvent&)
{
  Close(TRUE);
}

void GeasFrame::OnAbout(wxCommandEvent&)
{
  wxMessageBox(_("This is a wxWindows Hello world sample"),
	       _("About Hello World"), wxOK | wxICON_INFORMATION, this);
}

void GeasFrame::OnCommand (wxCommandEvent&)
{
  if (run_state == WGUI_EXPECTING)
    {
      wxString cmd = input->GetValue();
      input->SetValue (_T(""));
      run_command (cmd);
    }
  else if (run_state == WGUI_GET_STRING)
    run_state = WGUI_GOT_STRING;
}

void GeasFrame::run_command (const wxString &s)
{
  cout << "run_command (), run_state == " << run_state << endl;
  if (run_state != WGUI_EXPECTING)
    return;
  run_state = WGUI_RUNNING;
  gr->run_command (rcnv (s));
  end_turn_events();
  run_state = WGUI_EXPECTING;
}

wxString GetSelectedItem (wxListView *box)
{
  return box->GetItemText (box->GetFirstSelected());
}

void GeasFrame::OnButton (wxCommandEvent &evt)
{
  switch (evt.GetId()) 
    {
      //case ID_Invent:
    case ID_Invent_Drop:
      inv.try_action (_T("drop "));
      break;

    case ID_Invent_Use: 
      inv.try_action (_T("use "));
      break;

    case ID_Invent_Look:
      inv.try_action (_T("look at "));
      break;

    case ID_Invent_Examine:
      inv.try_action (_T("examine "));
      break;
	
      //case ID_Object:
    case ID_Object_Take:
      obj.try_action (_T("take "));
      break;

    case ID_Object_Use:
      obj.try_action (_T("use "));
      break;

    case ID_Object_Examine:
      obj.try_action (_T("examine "));
      break;

    case ID_Object_Look:
      obj.try_action (_T("look at "));
      break;

    case ID_Object_Speak:
      obj.try_action (_T("speak to "));
      break;

    case ID_Object_Go_To:
      obj.try_action (_T("go to "));
      break;
    }   

}


void GeasFrame::end_turn_events() { 
  //set_contents (invent, gr->get_inventory(), 1);
  //set_contents (objects, gr->get_room_contents(), 2);
  inv.SetContents (gr->get_inventory());
  obj.SetContents (gr->get_room_contents());

  if (var.SetContents (gr->get_status_vars()))
    GetSizer()->Layout();

  //cmpw.set_valid_exits (gr->get_valid_exits());

  comp.SetValidExits(gr->get_valid_exits());

  input->SetFocus ();

  output->ShowPosition (output->GetLastPosition());
}




std::string GeasFrame::get_file (std::string fname) const {
  std::ifstream ifs;
  ifs.open(fname.c_str(), ios::binary);
  if (! ifs.is_open())
    {
      cerr << "Couldn't open " << fname << endl;
      return "";
    }
  std::string rv;
  char ch;
  ifs.get(ch);
  while (!ifs.eof())
    {
      rv += ch;
      ifs.get(ch);
    }
  return rv;
}


std::string GeasFrame::absolute_name (std::string rel_name, std::string parent) const {
  std::cerr << "absolute_name ('" << rel_name << "', '" << parent << "')\n";
  assert (parent[0] == '/');
  if (rel_name[0] == '/')
    {
      std::cerr << "  --> " << rel_name << "\n";
      return rel_name;
    }
  std::vector<std::string> path;
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
  std::string tmp;
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
  std::string rv;
  for (uint i = 0; i < path.size(); i ++)
    rv = rv + "/" + path[i];
  std::cerr << " ---> " << rv << "\n";
  return rv;
}

string GeasFrame::get_string ()
{
  RunnerState copy_state = run_state;
  run_state = WGUI_GET_STRING;
  while (run_state != WGUI_GOT_STRING)
    wxYield();
  // should that be wxYield(), wxApp::wxYield, or GeasApp.Yield(), 
  // and should it take an argument?
  string rv = rcnv (input->GetValue());
  input->SetValue (_T(""));
  run_state = copy_state;
  return rv;
}

uint GeasFrame::make_choice (string label, vector<string> v)
{
  output->AppendText (cnv (label + "\n"));
  wxString holder;
  for (uint i = 0; i < v.size(); i ++)
    {
      holder.Printf (_T("%d"), i + 1);
      output->AppendText (holder + cnv (") " + v[i] + "\n"));
    }
  uint rv;
  for (;;)
    {
      string tmp = get_string();
      //if ((rv = parse_int (tmp)) > 0 && rv < v.size())
      if ((rv = atoi (tmp.c_str())) > 0 && rv < v.size())
	return rv - 1;
    }
}

GeasResult GeasFrame::clear_screen() 
{  
  output->SetValue (_T(""));
  return r_success;
}

GeasResult GeasFrame::pause (int i)
{
  RunnerState copy_state = run_state;
  run_state = WGUI_PAUSE;

  wxTimer t(this, ID_Timer_Pause);

  while (!t.Start(i, wxTIMER_ONE_SHOT))
    wxYield(); // Keep trying until it can get a timer

  while (run_state == WGUI_PAUSE)
    wxYield();

  run_state = copy_state;
  return r_success;
}

void GeasFrame::EndPause (wxTimerEvent &evt)
{
  assert (run_state == WGUI_PAUSE);
  run_state = WGUI_WAS_PAUSE;
}

GeasResult GeasFrame::wait_keypress()
{
  return r_failure;
}

void GeasFrame::RegularTimer (wxTimerEvent &evt)
{
  if (run_state == WGUI_EXPECTING)
    {
      //cout << "Ticking timers\n";
      run_state = WGUI_TIMER;
      gr->tick_timers();
      run_state = WGUI_EXPECTING;
    }
}
