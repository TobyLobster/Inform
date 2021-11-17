
#include "wx/wx.h" 
#include "wx/dnd.h"
#include <string>
#include <vector>


#include "GeasRunner.hh"

wxString cnv (const std::string &s);


class GeasApp: public wxApp
{
  virtual bool OnInit();
  //virtual bool OnCmdLineParsed (wxCmdLineParser &parser);
};

//class ObjectWidget {};
//class InventWidget {};
//class CompassWidget {};
//class VariableWidget {};

class GeasFrame;

class InventControl : public wxPanel //, public wxDropTarget
{
  friend class InventTarget;
  GeasFrame *parent;
  wxDropSource src;
  //wxListBox *data;
  wxListView *data;
  wxMenu *popup;

public:
  InventControl (GeasFrame *);

  void BeginDrag (wxListEvent &);
  void BeginRDrag (wxListEvent &);
  void SetContents (std::vector <std::vector <std::string> >);
  void try_action (wxString act);

  DECLARE_EVENT_TABLE();
};

class InventTarget : public wxDropTarget
{
  InventControl *parent;
  wxString target_name;
public:
  InventTarget (InventControl *in_p);

  virtual wxDragResult OnData (wxCoord x, wxCoord y, wxDragResult def);
  virtual bool OnDrop (wxCoord x, wxCoord y);

  virtual ~InventTarget() {}
};

class ObjectControl;

class ObjectTarget : public wxDropTarget
{
  ObjectControl *parent;
  wxString target_name;
public:
  ObjectTarget (ObjectControl *in_p);
  virtual wxDragResult OnData (wxCoord x, wxCoord y, wxDragResult def);
  virtual bool OnDrop (wxCoord x, wxCoord y);
  virtual ~ObjectTarget() {}
};


class VarControl : public wxPanel
{
  GeasFrame *parent;
  wxListBox *data;
public:
  VarControl (GeasFrame *);
  // Set the contents, and show or hide, if necessary.
  // Returns true if its visibility changed
  bool SetContents (std::vector<std::string>);
};

class ObjectControl : public wxPanel //, public wxDropTarget
{
  friend class ObjectTarget;
  GeasFrame *parent;
  wxDropSource src;
  wxListView *data;
public:
  ObjectControl (GeasFrame *);

  void BeginDrag (wxListEvent &);
  void BeginRDrag (wxListEvent &);
  void SetContents (std::vector <std::vector <std::string> >);
  void try_action (wxString act);

  //virtual bool GetData () { std::cout << "O::GetData ()" <<  std::endl; return true; }
  //virtual void OnData () {  std::cout << "O::OnData ()" <<  std::endl; }
  //virtual bool OnDrop (wxCoord x, wxCoord y) {  std::cout << "I::OnDrop (" << x << ", " << y << ")" <<  std::endl; return true; }
  //virtual wxDragResult OnEnter (wxCoord x, wxCoord y, wxDragResult def) {  std::cout << "O:OnEnter (" << x << ", " << y << ", " << def << ")" <<  std::endl; return wxDragNone; }
  //virtual wxDragResult  OnDragOver (wxCoord x, wxCoord y, wxDragResult def)  {  std::cout << "O:OnDragOver (" << x << ", " << y << ", " << def << ")" <<  std::endl; return wxDragNone; }
  //virtual void OnLeave() {  std::cout << "O::OnLeave ()" <<  std::endl; }

  DECLARE_EVENT_TABLE();
};  

class CompassControl : public wxPanel
{
  static wxString m_button_labels[11];
  static int m_button_ids[11];

  GeasFrame *parent;
  wxButton *m_dirs[11];

public:
  CompassControl (GeasFrame *);
  void SetValidExits (const std::vector<bool> &);
  void OnButton  (wxCommandEvent &event);

  DECLARE_EVENT_TABLE();
};


class GeasFrame: public wxFrame, public GeasInterface
{
  wxTextCtrl *output, *input;

  InventControl inv;
  VarControl var;
  ObjectControl obj;
  CompassControl comp;

  wxTimer *m_timer;

  GeasRunner *gr;
  void end_turn_events();

public:

  enum RunnerState
    {
      WGUI_NO_GAME,     // everything locked
      WGUI_EXPECTING,   // waiting for player to enter a command
      WGUI_RUNNING,     // running a command (everything locked)
      WGUI_CHOICE,      // waiting for player to choose from a menu
      //                      (all but choice box locked)
      WGUI_TIMER,       // running timers (everything locked)
      WGUI_GET_STRING,  // getting a string for script (all but input locked)
      WGUI_GOT_STRING,  // recvd string, about to return
      WGUI_WAIT,        // waiting for keypress
      WGUI_PAUSE,       // everything locked
      WGUI_WAS_PAUSE,   // pause over, everything locked
    } run_state;


  void run_command (const wxString &s);
  void set_game (std::string fname);

  GeasFrame(const wxString& title, const wxPoint& pos, const wxSize& size);

  void OnQuit    (wxCommandEvent &event);
  void OnAbout   (wxCommandEvent &event);
  void OnCommand (wxCommandEvent &event);
  void OnButton  (wxCommandEvent &event);

  DECLARE_EVENT_TABLE();

protected: 
  virtual std::string absolute_name (std::string rel_name, std::string parent) const;
  virtual std::string get_file (std::string) const;
  virtual GeasResult print_normal (std::string s) { output->AppendText (cnv(s)); return r_success; }
  virtual GeasResult print_newline () { output->AppendText (_("\n")); return r_success; }
  virtual GeasResult set_style (const GeasFontStyle &) { return r_not_supported; }
  
  //virtual GeasResult wait_keypress () { return r_not_supported; }
  virtual GeasResult wait_keypress ();
  //virtual GeasResult pause (int msec) { gw->pause(msec); return r_success; }
  //virtual GeasResult pause (int msec) { return r_not_supported; }
  virtual GeasResult pause (int msec);
  //virtual GeasResult clear_screen () { return r_not_supported; }
  virtual GeasResult clear_screen ();
  //virtual std::string get_string() { return ""; }
  virtual std::string get_string();

  virtual void set_foreground (std::string s) {}
  virtual void set_background (std::string s) {}
  //virtual uint make_choice (std::string label, std::vector<std::string> v) { return gw->make_choice (label, v); }
  virtual uint make_choice (std::string label, std::vector<std::string> v);

  GeasResult show_image (std::string filename, std::string resolution,
			 std::string caption, ...)
  { return r_not_supported; }

  GeasResult play_sound (std::string filename, bool looped, bool sync)
  { return r_not_supported; }


  GeasResult speak (std::string)  { return r_not_supported; }

  void RegularTimer (wxTimerEvent &evt);
  void EndPause (wxTimerEvent &evt);

public:
  //GeasWindowInterface (GeasWindow *in_gw) : gw(in_gw) { update_style(); }

  virtual void debug_print (std::string s) { print_normal (s); print_newline(); }
};



enum
{
  ID_Quit = 1,
  ID_About,
  ID_Command_Line,

  ID_Invent,
  ID_Invent_Left,
  ID_Invent_Right,
  ID_Invent_Drop,
  ID_Invent_Use,
  ID_Invent_Give,
  ID_Invent_Look,
  ID_Invent_Examine,

  ID_Object,
  ID_Object_Left,
  ID_Object_Right,
  ID_Object_Take,
  ID_Object_Use,
  ID_Object_Give,
  ID_Object_Examine,
  ID_Object_Look,
  ID_Object_Speak,
  ID_Object_Go_To,

  ID_Compass,
  ID_Compass_N,
  ID_Compass_E,
  ID_Compass_S,
  ID_Compass_W,
  ID_Compass_NE,
  ID_Compass_NW,
  ID_Compass_SE,
  ID_Compass_SW,
  ID_Compass_U,
  ID_Compass_D,
  ID_Compass_OUT,
  
  ID_Timer_Regular,
  ID_Timer_Pause,

  ID_TERMINATOR
};

BEGIN_EVENT_TABLE(GeasFrame, wxFrame)
  EVT_MENU(ID_Quit, GeasFrame::OnQuit)
  EVT_MENU(ID_About, GeasFrame::OnAbout)
  //EVT_MENU(ID_Enter_Command, GeasFrame::OnCommand)
  EVT_TEXT_ENTER (ID_Command_Line, GeasFrame::OnCommand)

  EVT_BUTTON (ID_Object_Examine, GeasFrame::OnButton)
  EVT_BUTTON (ID_Object_Look,    GeasFrame::OnButton)
  EVT_BUTTON (ID_Object_Speak,   GeasFrame::OnButton)
  EVT_BUTTON (ID_Object_Take,    GeasFrame::OnButton)
  EVT_BUTTON (ID_Object_Use,     GeasFrame::OnButton)

  EVT_TIMER  (ID_Timer_Regular,  GeasFrame::RegularTimer)
  EVT_TIMER  (ID_Timer_Pause,    GeasFrame::EndPause)

  END_EVENT_TABLE();


BEGIN_EVENT_TABLE (InventControl, wxPanel)
  EVT_LIST_BEGIN_DRAG  (ID_Invent,  InventControl::BeginDrag)
  EVT_LIST_BEGIN_RDRAG (ID_Invent,  InventControl::BeginRDrag)
  END_EVENT_TABLE();


BEGIN_EVENT_TABLE (ObjectControl, wxPanel)
  EVT_LIST_BEGIN_DRAG  (ID_Object,  ObjectControl::BeginDrag)
  EVT_LIST_BEGIN_RDRAG (ID_Object,  ObjectControl::BeginRDrag)
  END_EVENT_TABLE();


BEGIN_EVENT_TABLE (CompassControl, wxPanel)
  EVT_BUTTON (ID_Compass_N,   CompassControl::OnButton)
  EVT_BUTTON (ID_Compass_NE,  CompassControl::OnButton)
  EVT_BUTTON (ID_Compass_E,   CompassControl::OnButton)
  EVT_BUTTON (ID_Compass_SE,  CompassControl::OnButton)
  EVT_BUTTON (ID_Compass_S,   CompassControl::OnButton)
  EVT_BUTTON (ID_Compass_SW,  CompassControl::OnButton)
  EVT_BUTTON (ID_Compass_W,   CompassControl::OnButton)
  EVT_BUTTON (ID_Compass_NW,  CompassControl::OnButton)
  EVT_BUTTON (ID_Compass_U,   CompassControl::OnButton)
  EVT_BUTTON (ID_Compass_D,   CompassControl::OnButton)
  EVT_BUTTON (ID_Compass_OUT, CompassControl::OnButton)
  END_EVENT_TABLE();
