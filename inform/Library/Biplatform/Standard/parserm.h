! ----------------------------------------------------------------------------
!  PARSERM:  Core of parser.
!
!  Supplied for use with Inform 6                         Serial number 991113
!                                                                 Release 6/10
!  (c) Graham Nelson 1993, 1994, 1995, 1996, 1997, 1998, 1999
!      but freely usable (see manuals)
! ----------------------------------------------------------------------------
!  Inclusion of "linklpa"
!                   (which defines properties and attributes)
!  Global variables, constants and arrays
!                1: outside of the parser
!                2: used within the parser
!  Inclusion of natural language definition file
!                   (which creates a compass and direction-objects)
!  Darkness and player objects
!  Definition of grammar token numbering system used by Inform
!
!  The InformParser object
!          keyboard reading
!          level 0: outer shell, conversation, errors
!                1: grammar lines
!                2: tokens
!                3: object lists
!                4: scope and ambiguity resolving
!                5: object comparisons
!                6: word comparisons
!                7: reading words and moving tables about
!          pronoun management
!
!  The InformLibrary object
!          main game loop
!          action processing
!          end of turn sequence
!          scope looping, before/after sequence, sending messages out
!          timers, daemons, time of day, score notification
!          light and darkness
!          changing player personality
!          tracing code (only present if DEBUG is set)
!
!  Status line printing, menu display
!  Printing object names with articles
!  Miscellaneous utility routines
!  Game banner, "version" verb, run-time errors
! ----------------------------------------------------------------------------

System_file;
Constant NULL = $ffff;

IFDEF MODULE_MODE;
Constant DEBUG;
Constant Grammar__Version 2;
Include "linklpa";
ENDIF;

! ============================================================================
!   Global variables and their associated Constant and Array declarations
! ----------------------------------------------------------------------------
Global location = InformLibrary;     ! Must be first global defined
Global sline1;                       ! Must be second
Global sline2;                       ! Must be third
                                     ! (for status line display)
! ------------------------------------------------------------------------------
!   Z-Machine and interpreter issues
! ------------------------------------------------------------------------------
Global top_object;                   ! Largest valid number of any tree object
Global standard_interpreter;         ! The version number of the Z-Machine
                                     ! Standard which the interpreter claims
                                     ! to support, in form (upper byte).(lower)
Global undo_flag;                    ! Can the interpreter provide "undo"?
Global just_undone;                  ! Can't have two successive UNDOs
Global transcript_mode;              ! true when game scripting is on
IFDEF DEBUG;
Global xcommsdir;                    ! true if command recording is on
ENDIF;
! ------------------------------------------------------------------------------
!   Time and score
! (for linkage reasons, the task_* arrays are created not here but in verblib.h)
! ------------------------------------------------------------------------------
Global turns = 1;                    ! Number of turns of play so far
Global the_time = NULL;              ! Current time (in minutes since midnight)
Global time_rate = 1;                ! How often time is updated
Global time_step;                    ! By how much

#ifndef MAX_TIMERS;
Constant MAX_TIMERS  32;             ! Max number timers/daemons active at once
#endif;
Array  the_timers  --> MAX_TIMERS;
Global active_timers;                ! Number of timers/daemons actives

Global score;                        ! The current score
Global last_score;                   ! Score last turn (for testing for changes)
Global notify_mode = true;           ! Score notification
Global places_score;                 ! Contribution to score made by visiting
Global things_score;                 ! Contribution made by acquisition
! ------------------------------------------------------------------------------
!   The player
! ------------------------------------------------------------------------------
Global player;                       ! Which object the human is playing through
Global deadflag;                     ! Normally 0, or false; 1 for dead;
                                     ! 2 for victorious, and higher numbers
                                     ! represent exotic forms of death
! ------------------------------------------------------------------------------
!   Light and room descriptions
! ------------------------------------------------------------------------------
Global lightflag = true;             ! Is there currently light to see by?
Global real_location;                ! When in darkness, location = thedark
                                     ! and this holds the real location
Global visibility_ceiling;           ! Highest object in tree visible from
                                     ! the player's point of view (usually
                                     ! the room, sometimes darkness, sometimes
                                     ! a closed non-transparent container).

Global lookmode = 1;                 ! 1=standard, 2=verbose, 3=brief room descs
Global print_player_flag;            ! If set, print something like "(as Fred)"
                                     ! in room descriptions, to reveal whom
                                     ! the human is playing through
Global lastdesc;                     ! Value of location at time of most recent
                                     ! room description printed out
! ------------------------------------------------------------------------------
!   List writing  (style bits are defined as Constants in "verblibm.h")
! ------------------------------------------------------------------------------
Global c_style;                      ! Current list-writer style
Global lt_value;                     ! Common value of list_together
Global listing_together;             ! Object number of one member of a group
                                     ! being listed together
Global listing_size;                 ! Size of such a group
Global wlf_indent;                   ! Current level of indentation printed by
                                     ! WriteListFrom routine

Global inventory_stage = 1;          ! 1 or 2 according to the context in which
                                     ! "invent" routines of objects are called
Global inventory_style;              ! List-writer style currently used while
                                     ! printing inventories
! ------------------------------------------------------------------------------
!   Menus and printing
! ------------------------------------------------------------------------------
Global pretty_flag = true;           ! Use character graphics, or plain text?
Global menu_nesting;                 ! Level of nesting (0 = root menu)
Global menu_item;                    ! These are used in communicating
Global item_width = 8;               ! with the menu-creating routines
Global item_name = "---";

Global lm_n;                         ! Parameters used by LibraryMessages
Global lm_o;                         ! mechanism

IFDEF DEBUG;
Global debug_flag;                   ! Bitmap of flags for tracing actions,
                                     ! calls to object routines, etc.
Global x_scope_count;                ! Used in printing a list of everything
                                     ! in scope
ENDIF;
! ------------------------------------------------------------------------------
!   Action processing
! ------------------------------------------------------------------------------
Global action;                       ! Action currently being asked to perform
Global inp1;                         ! 0 (nothing), 1 (number) or first noun
Global inp2;                         ! 0 (nothing), 1 (number) or second noun
Global noun;                         ! First noun or numerical value
Global second;                       ! Second noun or numerical value

Global keep_silent;                  ! If true, attempt to perform the action
                                     ! silently (e.g. for implicit takes,
                                     ! implicit opening of unlocked doors)

Global reason_code;                  ! Reason for calling a "life" rule
                                     ! (an action or fake such as ##Kiss)

Global receive_action;               ! Either ##PutOn or ##Insert, whichever
                                     ! is action being tried when an object's
                                     ! "before" rule is checking "Receive"
! ==============================================================================
!   Parser variables: first, for communication to the parser
! ------------------------------------------------------------------------------
Global parser_trace = 0;             ! Set this to 1 to make the parser trace
                                     ! tokens and lines
Global parser_action;                ! For the use of the parser when calling
Global parser_one;                   ! user-supplied routines
Global parser_two;                   !
Array  inputobjs       --> 16;       ! For parser to write its results in
Global parser_inflection;            ! A property (usually "name") to find
                                     ! object names in
! ------------------------------------------------------------------------------
!   Parser output
! ------------------------------------------------------------------------------
Global actor;                        ! Person asked to do something
Global actors_location;              ! Like location, but for the actor
Global meta;                         ! Verb is a meta-command (such as "save")

Array  multiple_object --> 64;       ! List of multiple parameters
Global multiflag;                    ! Multiple-object flag
Global toomany_flag;                 ! Flag for "multiple match too large"
                                     ! (e.g. if "take all" took over 100 things)

Global special_word;                 ! Dictionary address for "special" token
Global special_number;               ! Number typed for "special" token
Global parsed_number;                ! For user-supplied parsing routines
Global consult_from;                 ! Word that a "consult" topic starts on
Global consult_words;                ! ...and number of words in topic
! ------------------------------------------------------------------------------
!   Implicit taking
! ------------------------------------------------------------------------------
Global notheld_mode;                 ! To do with implicit taking
Global onotheld_mode;                !     "old copy of notheld_mode", ditto
Global not_holding;                  ! Object to be automatically taken as an
                                     ! implicit command
Array  kept_results --> 16;          ! Delayed command (while the take happens)
! ------------------------------------------------------------------------------
!   Error numbers when parsing a grammar line
! ------------------------------------------------------------------------------
Global etype;                        ! Error number on current line
Global best_etype;                   ! Preferred error number so far
Global nextbest_etype;               ! Preferred one, if ASKSCOPE_PE disallowed

Constant STUCK_PE     = 1;
Constant UPTO_PE      = 2;
Constant NUMBER_PE    = 3;
Constant CANTSEE_PE   = 4;
Constant TOOLIT_PE    = 5;
Constant NOTHELD_PE   = 6;
Constant MULTI_PE     = 7;
Constant MMULTI_PE    = 8;
Constant VAGUE_PE     = 9;
Constant EXCEPT_PE    = 10;
Constant ANIMA_PE     = 11;
Constant VERB_PE      = 12;
Constant SCENERY_PE   = 13;
Constant ITGONE_PE    = 14;
Constant JUNKAFTER_PE = 15;
Constant TOOFEW_PE    = 16;
Constant NOTHING_PE   = 17;
Constant ASKSCOPE_PE  = 18;
! ------------------------------------------------------------------------------
!   Pattern-matching against a single grammar line
! ------------------------------------------------------------------------------
Array pattern --> 32;                ! For the current pattern match
Global pcount;                       ! and a marker within it
Array pattern2 --> 32;               ! And another, which stores the best match
Global pcount2;                      ! so far
Constant PATTERN_NULL = $ffff;       ! Entry for a token producing no text

Array  line_ttype-->32;              ! For storing an analysed grammar line
Array  line_tdata-->32;
Array  line_token-->32;

Global parameters;                   ! Parameters (objects) entered so far
Global nsns;                         ! Number of special_numbers entered so far
Global special_number1;              ! First number, if one was typed
Global special_number2;              ! Second number, if two were typed
! ------------------------------------------------------------------------------
!   Inferences and looking ahead
! ------------------------------------------------------------------------------
Global params_wanted;                ! Number of parameters needed
                                     ! (which may change in parsing)

Global inferfrom;                    ! The point from which the rest of the
                                     ! command must be inferred
Global inferword;                    ! And the preposition inferred
Global dont_infer;                   ! Another dull flag

Global action_to_be;                 ! (If the current line were accepted.)
Global action_reversed;              ! (Parameters would be reversed in order.)
Global advance_warning;              ! What a later-named thing will be
! ------------------------------------------------------------------------------
!   At the level of individual tokens now
! ------------------------------------------------------------------------------
Global found_ttype;                  ! Used to break up tokens into type
Global found_tdata;                  ! and data (by AnalyseToken)
Global token_filter;                 ! For noun filtering by user routines

Global length_of_noun;               ! Set by NounDomain to no of words in noun
Constant REPARSE_CODE = 10000;       ! Signals "reparse the text" as a reply
                                     ! from NounDomain

Global lookahead;                    ! The token after the one now being matched

Global multi_mode;                   ! Multiple mode
Global multi_wanted;                 ! Number of things needed in multitude
Global multi_had;                    ! Number of things actually found
Global multi_context;                ! What token the multi-obj was accepted for

Global indef_mode;                   ! "Indefinite" mode - ie, "take a brick"
                                     ! is in this mode
Global indef_type;                   ! Bit-map holding types of specification
Global indef_wanted;                 ! Number of items wanted (100 for all)
Global indef_guess_p;                ! Plural-guessing flag
Global indef_owner;                  ! Object which must hold these items
Global indef_cases;                  ! Possible gender and numbers of them
Global indef_possambig;              ! Has a possibly dangerous assumption
                                     ! been made about meaning of a descriptor?
Global indef_nspec_at;               ! Word at which a number like "two" was
                                     ! parsed (for backtracking)
Global allow_plurals;                ! Whether plurals presently allowed or not

Global take_all_rule;                ! Slightly different rules apply to
                                     ! "take all" than other uses of multiple
                                     ! objects, to make adjudication produce
                                     ! more pragmatically useful results
                                     ! (Not a flag: possible values 0, 1, 2)

Global dict_flags_of_noun;           ! Of the noun currently being parsed
                                     ! (a bitmap in #dict_par1 format)
Global pronoun_word;                 ! Records which pronoun ("it", "them", ...)
                                     ! caused an error
Global pronoun_obj;                  ! And what obj it was thought to refer to
Global pronoun__word;                ! Saved value
Global pronoun__obj;                 ! Saved value
! ------------------------------------------------------------------------------
!   Searching through scope and parsing "scope=Routine" grammar tokens
! ------------------------------------------------------------------------------
Constant PARSING_REASON       = 0;   ! Possible reasons for searching scope
Constant TALKING_REASON       = 1;
Constant EACH_TURN_REASON     = 2;
Constant REACT_BEFORE_REASON  = 3;
Constant REACT_AFTER_REASON   = 4;
Constant LOOPOVERSCOPE_REASON = 5;
Constant TESTSCOPE_REASON     = 6;

Global scope_reason = PARSING_REASON; ! Current reason for searching scope

Global scope_token;                  ! For "scope=Routine" grammar tokens
Global scope_error;
Global scope_stage;                  ! 1, 2 then 3

Global ats_flag = 0;                 ! For AddToScope routines
Global ats_hls;                      !

Global placed_in_flag;               ! To do with PlaceInScope

! ------------------------------------------------------------------------------
!   The match list of candidate objects for a given token
! ------------------------------------------------------------------------------
Constant MATCH_LIST_SIZE = 128;
Array  match_list    --> 64;         ! An array of matched objects so far
Array  match_classes --> 64;         ! An array of equivalence classes for them
Array  match_scores --> 64;          ! An array of match scores for them
Global number_matched;               ! How many items in it?  (0 means none)
Global number_of_classes;            ! How many equivalence classes?
Global match_length;                 ! How many words long are these matches?
Global match_from;                   ! At what word of the input do they begin?
Global bestguess_score;              ! What did the best-guess object score?
! ------------------------------------------------------------------------------
!   Low level textual manipulation
! ------------------------------------------------------------------------------
Array  buffer    -> 121;             ! Buffer for parsing main line of input
Array  parse     -> 65;              ! Parse table mirroring it
Array  buffer2   -> 121;             ! Buffers for supplementary questions
Array  parse2    -> 65;              !
Array  buffer3   -> 121;             ! Buffer retaining input for "again"

Constant comma_word = 'comma,';      ! An "untypeable word" used to substitute
                                     ! for commas in parse buffers

Global wn;                           ! Word number within "parse" (from 1)
Global num_words;                    ! Number of words typed
Global verb_word;                    ! Verb word (eg, take in "take all" or
                                     ! "dwarf, take all") - address in dict
Global verb_wordnum;                 ! its number in typing order (eg, 1 or 3)
Global usual_grammar_after;          ! Point from which usual grammar is parsed
                                     ! (it may vary from the above if user's
                                     ! routines match multi-word verbs)

Global oops_from;                    ! The "first mistake" word number
Global saved_oops;                   ! Used in working this out
Array  oops_workspace -> 64;         ! Used temporarily by "oops" routine

Global held_back_mode;               ! Flag: is there some input from last time
Global hb_wn;                        ! left over?  (And a save value for wn.)
                                     ! (Used for full stops and "then".)
! ----------------------------------------------------------------------------
Array PowersOfTwo_TB                 ! Used in converting case numbers to
  --> $$100000000000                 ! case bitmaps
      $$010000000000
      $$001000000000
      $$000100000000
      $$000010000000
      $$000001000000
      $$000000100000
      $$000000010000
      $$000000001000
      $$000000000100
      $$000000000010
      $$000000000001;
! ============================================================================


! ============================================================================
!  Constants, and one variable, needed for the language definition file
! ----------------------------------------------------------------------------
Constant POSSESS_PK  = $100;
Constant DEFART_PK   = $101;
Constant INDEFART_PK = $102;
Global short_name_case;
! ----------------------------------------------------------------------------
Include "language__";                !  The natural language definition,
                                     !  whose filename is taken from the ICL
                                     !  language_name variable
! ----------------------------------------------------------------------------
#ifndef LanguageCases;
Constant LanguageCases = 1;
#endif;
! ------------------------------------------------------------------------------
!   Pronouns support for the cruder (library 6/2 and earlier) version:
!   only needed in English
! ------------------------------------------------------------------------------
#ifdef EnglishNaturalLanguage;
Global itobj = NULL;                 ! The object which is currently "it"
Global himobj = NULL;                ! The object which is currently "him"
Global herobj = NULL;                ! The object which is currently "her"

Global old_itobj = NULL;             ! The object which is currently "it"
Global old_himobj = NULL;            ! The object which is currently "him"
Global old_herobj = NULL;            ! The object which is currently "her"
#endif;
! ============================================================================


! ============================================================================
! "Darkness" is not really a place: but it has to be an object so that the
!  location-name on the status line can be "Darkness".
! ----------------------------------------------------------------------------
Object thedark "(darkness object)"
  with initial 0,
       short_name DARKNESS__TX,
       description
       [;  return L__M(##Miscellany, 17);
       ];
Object selfobj "(self object)"
  with short_name
       [;  return L__M(##Miscellany, 18);
       ],
       description
       [;  return L__M(##Miscellany, 19);
       ],
       before NULL,   after NULL,    life NULL,    each_turn NULL,
       time_out NULL, describe NULL,
       capacity 100, parse_name 0,
       orders 0, number 0,
  has  concealed animate proper transparent;

! ============================================================================
!  The definition of the token-numbering system used by Inform.
! ----------------------------------------------------------------------------

Constant ILLEGAL_TT        = 0;      ! Types of grammar token: illegal
Constant ELEMENTARY_TT     = 1;      !     (one of those below)
Constant PREPOSITION_TT    = 2;      !     e.g. 'into'
Constant ROUTINE_FILTER_TT = 3;      !     e.g. noun=CagedCreature
Constant ATTR_FILTER_TT    = 4;      !     e.g. edible
Constant SCOPE_TT          = 5;      !     e.g. scope=Spells
Constant GPR_TT            = 6;      !     a general parsing routine

Constant NOUN_TOKEN        = 0;      ! The elementary grammar tokens, and
Constant HELD_TOKEN        = 1;      ! the numbers compiled by Inform to
Constant MULTI_TOKEN       = 2;      ! encode them
Constant MULTIHELD_TOKEN   = 3;
Constant MULTIEXCEPT_TOKEN = 4;
Constant MULTIINSIDE_TOKEN = 5;
Constant CREATURE_TOKEN    = 6;
Constant SPECIAL_TOKEN     = 7;
Constant NUMBER_TOKEN      = 8;
Constant TOPIC_TOKEN       = 9;


Constant GPR_FAIL          = -1;     ! Return values from General Parsing
Constant GPR_PREPOSITION   = 0;      ! Routines
Constant GPR_NUMBER        = 1;
Constant GPR_MULTIPLE      = 2;
Constant GPR_REPARSE       = REPARSE_CODE;
Constant GPR_NOUN          = $ff00;
Constant GPR_HELD          = $ff01;
Constant GPR_MULTI         = $ff02;
Constant GPR_MULTIHELD     = $ff03;
Constant GPR_MULTIEXCEPT   = $ff04;
Constant GPR_MULTIINSIDE   = $ff05;
Constant GPR_CREATURE      = $ff06;

Constant ENDIT_TOKEN       = 15;     ! Value used to mean "end of grammar line"

#Iftrue Grammar__Version == 1;
[ AnalyseToken token m;

    found_tdata = token;

    if (token < 0)   { found_ttype = ILLEGAL_TT; return; }
    if (token <= 8)  { found_ttype = ELEMENTARY_TT; return; }
    if (token < 15)  { found_ttype = ILLEGAL_TT; return; }
    if (token == 15) { found_ttype = ELEMENTARY_TT; return; }
    if (token < 48)  { found_ttype = ROUTINE_FILTER_TT;
                       found_tdata = token - 16;
                       return; }
    if (token < 80)  { found_ttype = GPR_TT;
                       found_tdata = #preactions_table-->(token-48);
                       return; }
    if (token < 128) { found_ttype = SCOPE_TT;
                       found_tdata = #preactions_table-->(token-80);
                       return; }
    if (token < 180) { found_ttype = ATTR_FILTER_TT;
                       found_tdata = token - 128;
                       return; }

    found_ttype = PREPOSITION_TT;
    m=#adjectives_table;
    for (::)
    {   if (token==m-->1) { found_tdata = m-->0; return; }
        m=m+4;
    }
    m=#adjectives_table; RunTimeError(1);
    found_tdata = m;
];
[ UnpackGrammarLine line_address i m;
  for (i = 0 : i < 32 : i++)
  {   line_token-->i = ENDIT_TOKEN;
      line_ttype-->i = ELEMENTARY_TT;
      line_tdata-->i = ENDIT_TOKEN;
  }
  for (i = 0: i <= 5 :i++)
  {   line_token-->i = line_address->(i+1);
      AnalyseToken(line_token-->i);
      if ((found_ttype == ELEMENTARY_TT) && (found_tdata == NOUN_TOKEN)
          && (m == line_address->0))
      {   line_token-->i = ENDIT_TOKEN;
          break;
      }
      line_ttype-->i = found_ttype;
      line_tdata-->i = found_tdata;
      if (found_ttype ~= PREPOSITION_TT) m++;
  }
  action_to_be = line_address->7;
  action_reversed = false;
  params_wanted = line_address->0;
  return line_address + 8;
];
#Ifnot;
[ AnalyseToken token;

    if (token == ENDIT_TOKEN)
    {   found_ttype = ELEMENTARY_TT;
        found_tdata = ENDIT_TOKEN;
        return;
    }

    found_ttype = (token->0) & $$1111;
    found_tdata = (token+1)-->0;
];
[ UnpackGrammarLine line_address i;
  for (i = 0 : i < 32 : i++)
  {   line_token-->i = ENDIT_TOKEN;
      line_ttype-->i = ELEMENTARY_TT;
      line_tdata-->i = ENDIT_TOKEN;
  }
  action_to_be = 256*(line_address->0) + line_address->1;
  action_reversed = ((action_to_be & $400) ~= 0);
  action_to_be = action_to_be & $3ff;
  line_address--;
  params_wanted = 0;
  for (i=0::i++)
  {   line_address = line_address + 3;
      if (line_address->0 == ENDIT_TOKEN) break;
      line_token-->i = line_address;
      AnalyseToken(line_address);
      if (found_ttype ~= PREPOSITION_TT) params_wanted++;
      line_ttype-->i = found_ttype;
      line_tdata-->i = found_tdata;
  }
  return line_address + 1;
];
#Endif;

!  To protect against a bug in early versions of the "Zip" interpreter:

[ Tokenise__ b p; b->(2 + b->1) = 0; @tokenise b p; ];

! ============================================================================
!  The InformParser object abstracts the front end of the parser.
!
!  InformParser.parse_input(results)
!  returns only when a sensible request has been made, and puts into the
!  "results" buffer:
!
!  --> 0 = The action number
!  --> 1 = Number of parameters
!  --> 2, 3, ... = The parameters (object numbers), but
!                  0 means "put the multiple object list here"
!                  1 means "put one of the special numbers here"
!
! ----------------------------------------------------------------------------

Object InformParser "(Inform Parser)"
  with parse_input
       [ results; Parser__parse(results);
       ], has proper;

! ----------------------------------------------------------------------------
!  The Keyboard routine actually receives the player's words,
!  putting the words in "a_buffer" and their dictionary addresses in
!  "a_table".  It is assumed that the table is the same one on each
!  (standard) call.
!
!  It can also be used by miscellaneous routines in the game to ask
!  yes-no questions and the like, without invoking the rest of the parser.
!
!  Return the number of words typed
! ----------------------------------------------------------------------------

[ KeyboardPrimitive  a_buffer a_table;
  read a_buffer a_table;
];
[ Keyboard  a_buffer a_table  nw i w w2 x1 x2;

    DisplayStatus();
    .FreshInput;

!  Save the start of the buffer, in case "oops" needs to restore it
!  to the previous time's buffer

    for (i=0:i<64:i++) oops_workspace->i = a_buffer->i;

!  In case of an array entry corruption that shouldn't happen, but would be
!  disastrous if it did:

   a_buffer->0 = 120;
   a_table->0 = 15;  ! Allow to split input into this many words

!  Print the prompt, and read in the words and dictionary addresses

    L__M(##Prompt);
    AfterPrompt();
    #IFV5; DrawStatusLine(); #ENDIF;
    KeyboardPrimitive(a_buffer, a_table);
    nw=a_table->1;

!  If the line was blank, get a fresh line
    if (nw == 0)
    { L__M(##Miscellany,10); jump FreshInput; }

!  Unless the opening word was "oops", return

    w=a_table-->1;
    if (w == OOPS1__WD or OOPS2__WD or OOPS3__WD) jump DoOops;

#IFV5;
!  Undo handling

    if ((w == UNDO1__WD or UNDO2__WD or UNDO3__WD) && (parse->1==1))
    {   if (turns==1)
        {   L__M(##Miscellany,11); jump FreshInput;
        }
        if (undo_flag==0)
        {   L__M(##Miscellany,6); jump FreshInput;
        }
        if (undo_flag==1) jump UndoFailed;
        if (just_undone==1)
        {   L__M(##Miscellany,12); jump FreshInput;
        }
        @restore_undo i;
        if (i==0)
        {   .UndoFailed;
            L__M(##Miscellany,7);
        }
        jump FreshInput;
    }
    @save_undo i;
    just_undone=0;
    undo_flag=2;
    if (i==-1) undo_flag=0;
    if (i==0) undo_flag=1;
    if (i==2)
    {   style bold;
        print (name) location, "^";
        style roman;
        L__M(##Miscellany,13);
        just_undone=1;
        jump FreshInput;
    }
#ENDIF;

    return nw;

    .DoOops;
    if (oops_from == 0)
    {   L__M(##Miscellany,14); jump FreshInput; }
    if (nw == 1)
    {   L__M(##Miscellany,15); jump FreshInput; }
    if (nw > 2)
    {   L__M(##Miscellany,16); jump FreshInput; }

!  So now we know: there was a previous mistake, and the player has
!  attempted to correct a single word of it.

    for (i=0:i<=120:i++) buffer2->i = a_buffer->i;
    x1 = a_table->9; ! Start of word following "oops"
    x2 = a_table->8; ! Length of word following "oops"

!  Repair the buffer to the text that was in it before the "oops"
!  was typed:

    for (i=0:i<64:i++) a_buffer->i = oops_workspace->i;
    Tokenise__(a_buffer,a_table);

!  Work out the position in the buffer of the word to be corrected:

    w = a_table->(4*oops_from + 1); ! Start of word to go
    w2 = a_table->(4*oops_from);    ! Length of word to go

!  Write spaces over the word to be corrected:

    for (i=0:i<w2:i++) a_buffer->(i+w) = ' ';

    if (w2 < x2)
    {   ! If the replacement is longer than the original, move up...

        for (i=120:i>=w+x2:i--)
            a_buffer->i = a_buffer->(i-x2+w2);

        ! ...increasing buffer size accordingly.

        a_buffer->1 = (a_buffer->1) + (x2-w2);
    }

!  Write the correction in:

    for (i=0:i<x2:i++) a_buffer->(i+w) = buffer2->(i+x1);

    Tokenise__(a_buffer,a_table);
    nw=a_table->1;

    return nw;
];

! ----------------------------------------------------------------------------
!  To simplify the picture a little, a rough map of the main routine:
!
!  (A)    Get the input, do "oops" and "again"
!  (B)    Is it a direction, and so an implicit "go"?  If so go to (K)
!  (C)    Is anyone being addressed?
!  (D)    Get the verb: try all the syntax lines for that verb
!  (E)    Break down a syntax line into analysed tokens
!  (F)    Look ahead for advance warning for multiexcept/multiinside
!  (G)    Parse each token in turn (calling ParseToken to do most of the work)
!  (H)    Cheaply parse otherwise unrecognised conversation and return
!  (I)    Print best possible error message
!  (J)    Retry the whole lot
!  (K)    Last thing: check for "then" and further instructions(s), return.
!
!  The strategic points (A) to (K) are marked in the commentary.
!
!  Note that there are three different places where a return can happen.
! ----------------------------------------------------------------------------

[ Parser__parse  results   syntax line num_lines line_address i j k
                           token l m;

!  **** (A) ****

!  Firstly, in "not held" mode, we still have a command left over from last
!  time (eg, the user typed "eat biscuit", which was parsed as "take biscuit"
!  last time, with "eat biscuit" tucked away until now).  So we return that.

    if (notheld_mode==1)
    {   for (i=0:i<8:i++) results-->i=kept_results-->i;
        notheld_mode=0; rtrue;
    }

    if (held_back_mode==1)
    {   held_back_mode=0;
        Tokenise__(buffer,parse);
        jump ReParse;
    }

  .ReType;

    Keyboard(buffer,parse);

  .ReParse;

    parser_inflection = name;

!  Initially assume the command is aimed at the player, and the verb
!  is the first word

    num_words=parse->1;
    wn=1;
#ifdef LanguageToInformese;
    LanguageToInformese();
#ifv5;
!   Re-tokenise:
    Tokenise__(buffer,parse);
#endif;
#endif;

    BeforeParsing();
    num_words=parse->1;

    k=0;
#ifdef DEBUG;
    if (parser_trace>=2)
    {   print "[ ";
        for (i=0:i<num_words:i++)
        {   j=parse-->(i*2 + 1);
            k=WordAddress(i+1);
            l=WordLength(i+1);
            print "~"; for (m=0:m<l:m++) print (char) k->m; print "~ ";

            if (j == 0) print "?";
            else
            {   if (UnsignedCompare(j, 0-->4)>=0
                    && UnsignedCompare(j, 0-->2)<0) print (address) j;
                else print j;
            }
            if (i ~= num_words-1) print " / ";
        }
        print " ]^";
    }
#endif;
    verb_wordnum=1;
    actor=player;
    actors_location = ScopeCeiling(player);
    usual_grammar_after = 0;

  .AlmostReParse;

    scope_token = 0;
    action_to_be = NULL;

!  Begin from what we currently think is the verb word

  .BeginCommand;
    wn=verb_wordnum;
    verb_word = NextWordStopped();

!  If there's no input here, we must have something like
!  "person,".

    if (verb_word==-1)
    {   best_etype = STUCK_PE; jump GiveError; }

!  Now try for "again" or "g", which are special cases:
!  don't allow "again" if nothing has previously been typed;
!  simply copy the previous text across

    if (verb_word==AGAIN2__WD or AGAIN3__WD) verb_word=AGAIN1__WD;
    if (verb_word==AGAIN1__WD)
    {   if (actor~=player)
        {   L__M(##Miscellany,20); jump ReType; }
        if (buffer3->1==0)
        {   L__M(##Miscellany,21); jump ReType; }
        for (i=0:i<120:i++) buffer->i=buffer3->i;
        jump ReParse;
    }

!  Save the present input in case of an "again" next time

    if (verb_word~=AGAIN1__WD)
        for (i=0:i<120:i++) buffer3->i=buffer->i;

    if (usual_grammar_after==0)
    {   i = RunRoutines(actor, grammar);
        #ifdef DEBUG;
        if (parser_trace>=2 && actor.grammar~=0 or NULL)
            print " [Grammar property returned ", i, "]^";
        #endif;
        if (i<0) { usual_grammar_after = verb_wordnum; i=-i; }
        if (i==1)
        {   results-->0 = action;
            results-->1 = noun;
            results-->2 = second;
            rtrue;
        }
        if (i~=0) { verb_word = i; wn--; verb_wordnum--; }
        else
        {   wn = verb_wordnum; verb_word=NextWord();
        }
    }
    else usual_grammar_after=0;

!  **** (B) ****

    #ifdef LanguageIsVerb;
    if (verb_word==0)
    {   i = wn; verb_word=LanguageIsVerb(buffer, parse, verb_wordnum);
        wn = i;
    }
    #endif;

!  If the first word is not listed as a verb, it must be a direction
!  or the name of someone to talk to

    if (verb_word==0 || ((verb_word->#dict_par1) & 1) == 0)
    {   

!  So is the first word an object contained in the special object "compass"
!  (i.e., a direction)?  This needs use of NounDomain, a routine which
!  does the object matching, returning the object number, or 0 if none found,
!  or REPARSE_CODE if it has restructured the parse table so the whole parse
!  must be begun again...

        wn=verb_wordnum; indef_mode = false; token_filter = 0;
        l=NounDomain(compass,0,0); if (l==REPARSE_CODE) jump ReParse;

!  If it is a direction, send back the results:
!  action=GoSub, no of arguments=1, argument 1=the direction.

        if (l~=0)
        {   results-->0 = ##Go;
            action_to_be = ##Go;
            results-->1 = 1;
            results-->2 = l;
            jump LookForMore;
        }

!  **** (C) ****

!  Only check for a comma (a "someone, do something" command) if we are
!  not already in the middle of one.  (This simplification stops us from
!  worrying about "robot, wizard, you are an idiot", telling the robot to
!  tell the wizard that she is an idiot.)

        if (actor==player)
        {   for (j=2:j<=num_words:j++)
            {   i=NextWord(); if (i==comma_word) jump Conversation;
            }

            verb_word=UnknownVerb(verb_word);
            if (verb_word~=0) jump VerbAccepted;
        }

        best_etype=VERB_PE; jump GiveError;

!  NextWord nudges the word number wn on by one each time, so we've now
!  advanced past a comma.  (A comma is a word all on its own in the table.)

      .Conversation;
        j=wn-1;
        if (j==1) { L__M(##Miscellany,22); jump ReType; }

!  Use NounDomain (in the context of "animate creature") to see if the
!  words make sense as the name of someone held or nearby

        wn=1; lookahead=HELD_TOKEN;
        scope_reason = TALKING_REASON;
        l=NounDomain(player,actors_location,6);
        scope_reason = PARSING_REASON;
        if (l==REPARSE_CODE) jump ReParse;

        if (l==0) { L__M(##Miscellany,23); jump ReType; }

!  The object addressed must at least be "talkable" if not actually "animate"
!  (the distinction allows, for instance, a microphone to be spoken to,
!  without the parser thinking that the microphone is human).

        if (l hasnt animate && l hasnt talkable)
        {   L__M(##Miscellany, 24, l); jump ReType; }

!  Check that there aren't any mystery words between the end of the person's
!  name and the comma (eg, throw out "dwarf sdfgsdgs, go north").

        if (wn~=j)
        {   L__M(##Miscellany, 25); jump ReType; }

!  The player has now successfully named someone.  Adjust "him", "her", "it":

        PronounNotice(l);

!  Set the global variable "actor", adjust the number of the first word,
!  and begin parsing again from there.

        verb_wordnum=j+1;

!  Stop things like "me, again":

        if (l == player)
        {   wn = verb_wordnum;
            if (NextWordStopped() == AGAIN1__WD or AGAIN2__WD or AGAIN3__WD)
            {   L__M(##Miscellany,20); jump ReType;
            }
        }

        actor=l;
        actors_location=ScopeCeiling(l);
        #ifdef DEBUG;
        if (parser_trace>=1)
            print "[Actor is ", (the) actor, " in ",
                (name) actors_location, "]^";
        #endif;
        jump BeginCommand;
    }

!  **** (D) ****

   .VerbAccepted;

!  We now definitely have a verb, not a direction, whether we got here by the
!  "take ..." or "person, take ..." method.  Get the meta flag for this verb:

    meta=((verb_word->#dict_par1) & 2)/2;

!  You can't order other people to "full score" for you, and so on...

    if (meta==1 && actor~=player)
    {   best_etype=VERB_PE; meta=0; jump GiveError; }

!  Now let i be the corresponding verb number, stored in the dictionary entry
!  (in a peculiar 255-n fashion for traditional Infocom reasons)...

    i=$ff-(verb_word->#dict_par2);

!  ...then look up the i-th entry in the verb table, whose address is at word
!  7 in the Z-machine (in the header), so as to get the address of the syntax
!  table for the given verb...

    syntax=(0-->7)-->i;

!  ...and then see how many lines (ie, different patterns corresponding to the
!  same verb) are stored in the parse table...

    num_lines=(syntax->0)-1;

!  ...and now go through them all, one by one.
!  To prevent pronoun_word 0 being misunderstood,

   pronoun_word=NULL; pronoun_obj=NULL;

   #ifdef DEBUG;
   if (parser_trace>=1)
   {    print "[Parsing for the verb '", (address) verb_word,
              "' (", num_lines+1, " lines)]^";
   }
   #endif;

   best_etype=STUCK_PE; nextbest_etype=STUCK_PE;

!  "best_etype" is the current failure-to-match error - it is by default
!  the least informative one, "don't understand that sentence".
!  "nextbest_etype" remembers the best alternative to having to ask a
!  scope token for an error message (i.e., the best not counting ASKSCOPE_PE).


!  **** (E) ****

    line_address = syntax + 1;

    for (line=0:line<=num_lines:line++)
    {   
        for (i = 0 : i < 32 : i++)
        {   line_token-->i = ENDIT_TOKEN;
            line_ttype-->i = ELEMENTARY_TT;
            line_tdata-->i = ENDIT_TOKEN;
        }

!  Unpack the syntax line from Inform format into three arrays; ensure that
!  the sequence of tokens ends in an ENDIT_TOKEN.

        line_address = UnpackGrammarLine(line_address);
            
        #ifdef DEBUG;
        if (parser_trace >= 1)
        {   if (parser_trace >= 2) new_line;
            print "[line ", line; DebugGrammarLine();
            print "]^";
        }
        #endif;

!  We aren't in "not holding" or inferring modes, and haven't entered
!  any parameters on the line yet, or any special numbers; the multiple
!  object is still empty.

        not_holding=0;
        inferfrom=0;
        parameters=0;
        nsns=0; special_word=0; special_number=0;
        multiple_object-->0 = 0;
        multi_context = 0;
        etype=STUCK_PE;

!  Put the word marker back to just after the verb

        wn=verb_wordnum+1;

!  **** (F) ****
!  There are two special cases where parsing a token now has to be
!  affected by the result of parsing another token later, and these
!  two cases (multiexcept and multiinside tokens) are helped by a quick
!  look ahead, to work out the future token now.  We can only carry this
!  out in the simple (but by far the most common) case:
!
!      multiexcept <one or more prepositions> noun
!
!  and similarly for multiinside.

        advance_warning = NULL; indef_mode = false;
        for (i=0,m=false,pcount=0:line_token-->pcount ~= ENDIT_TOKEN:pcount++)
        {   scope_token = 0;

            if (line_ttype-->pcount ~= PREPOSITION_TT) i++;

            if (line_ttype-->pcount == ELEMENTARY_TT)
            {   if (line_tdata-->pcount == MULTI_TOKEN) m=true;
                if (line_tdata-->pcount
                    == MULTIEXCEPT_TOKEN or MULTIINSIDE_TOKEN  && i==1)
                {   !   First non-preposition is "multiexcept" or
                    !   "multiinside", so look ahead.

                    #ifdef DEBUG;
                    if (parser_trace>=2) print " [Trying look-ahead]^";
                    #endif;

                    !   We need this to be followed by 1 or more prepositions.

                    pcount++;
                    if (line_ttype-->pcount == PREPOSITION_TT)
                    {   while (line_ttype-->pcount == PREPOSITION_TT)
                            pcount++;

                        if ((line_ttype-->pcount == ELEMENTARY_TT)
                            && (line_tdata-->pcount == NOUN_TOKEN))
                        {
                            !  Advance past the last preposition

                            while (wn <= num_words)
                            {   if (NextWord() == line_tdata-->(pcount-1))
                                {   l = NounDomain(actors_location, actor,
                                            NOUN_TOKEN);
                                    #ifdef DEBUG;
                                    if (parser_trace>=2)
                                    {   print " [Advanced to ~noun~ token: ";
                                        if (l==REPARSE_CODE)
                                            print "re-parse request]^";
                                        if (l==1) print "but multiple found]^";
                                        if (l==0) print "error ", etype, "]^";
                                        if (l>=2) print (the) l, "]^";
                                    }
                                    #endif;
                                    if (l==REPARSE_CODE) jump ReParse;
                                    if (l>=2) advance_warning = l;
                                }
                            }
                        }
                    }
                    break;
                }
            }
        }

!  Slightly different line-parsing rules will apply to "take multi", to
!  prevent "take all" behaving correctly but misleadingly when there's
!  nothing to take.

        take_all_rule = 0;
        if (m && params_wanted==1 && action_to_be==##Take)
            take_all_rule = 1;

!  And now start again, properly, forearmed or not as the case may be.
!  As a precaution, we clear all the variables again (they may have been
!  disturbed by the call to NounDomain, which may have called outside
!  code, which may have done anything!).

        not_holding=0;
        inferfrom=0;
        parameters=0;
        nsns=0; special_word=0; special_number=0;
        multiple_object-->0 = 0;
        etype=STUCK_PE;
        wn=verb_wordnum+1;

!  **** (G) ****
!  "Pattern" gradually accumulates what has been recognised so far,
!  so that it may be reprinted by the parser later on

        for (pcount=1::pcount++)
        {   pattern-->pcount = PATTERN_NULL; scope_token=0;

            token = line_token-->(pcount-1);
            lookahead = line_token-->pcount;

            #ifdef DEBUG;
            if (parser_trace >= 2)
               print " [line ", line, " token ", pcount, " word ", wn, " : ",
                     (DebugToken) token, "]^";
            #endif;

            if (token ~= ENDIT_TOKEN)
            {   scope_reason = PARSING_REASON;
                parser_inflection = name;
                AnalyseToken(token);
                l = ParseToken__(found_ttype, found_tdata, pcount-1, token);
                while (l<-200) l = ParseToken__(ELEMENTARY_TT, l + 256);
                scope_reason = PARSING_REASON;

                if (l==GPR_PREPOSITION)
                {   if (found_ttype~=PREPOSITION_TT
                        && (found_ttype~=ELEMENTARY_TT
                            || found_tdata~=TOPIC_TOKEN)) params_wanted--;
                    l = true;
                }
                else
                if (l<0) l = false;
                else
                if (l~=GPR_REPARSE)
                {   if (l==GPR_NUMBER)
                    {   if (nsns==0) special_number1=parsed_number;
                        else special_number2=parsed_number;
                        nsns++; l = 1;
                    }
                    if (l==GPR_MULTIPLE) l = 0;
                    results-->(parameters+2) = l;
                    parameters++;
                    pattern-->pcount = l;
                    l = true;
                }

                #ifdef DEBUG;
                if (parser_trace >= 3)
                {   print "  [token resulted in ";
                    if (l==REPARSE_CODE) print "re-parse request]^";
                    if (l==0) print "failure with error type ", etype, "]^";
                    if (l==1) print "success]^";
                }
                #endif;

                if (l==REPARSE_CODE) jump ReParse;
                if (l==false) break;
            }
            else
            {

!  If the player has entered enough already but there's still
!  text to wade through: store the pattern away so as to be able to produce
!  a decent error message if this turns out to be the best we ever manage,
!  and in the mean time give up on this line

!  However, if the superfluous text begins with a comma or "then" then
!  take that to be the start of another instruction

                if (wn <= num_words)
                {   l=NextWord();
                    if (l==THEN1__WD or THEN2__WD or THEN3__WD or comma_word)
                    {   held_back_mode=1; hb_wn=wn-1; }
                    else
                    {   for (m=0:m<32:m++) pattern2-->m=pattern-->m;
                        pcount2=pcount;
                        etype=UPTO_PE; break;
                    }
                }

!  Now, we may need to revise the multiple object because of the single one
!  we now know (but didn't when the list was drawn up).

                if (parameters>=1 && results-->2 == 0)
                {   l=ReviseMulti(results-->3);
                    if (l~=0) { etype=l; break; }
                }
                if (parameters>=2 && results-->3 == 0)
                {   l=ReviseMulti(results-->2);
                    if (l~=0) { etype=l; break; }
                }

!  To trap the case of "take all" inferring only "yourself" when absolutely
!  nothing else is in the vicinity...

                if (take_all_rule==2 && results-->2 == actor)
                {   best_etype = NOTHING_PE; jump GiveError;
                }

                #ifdef DEBUG;
                if (parser_trace>=1)
                    print "[Line successfully parsed]^";
                #endif;

!  The line has successfully matched the text.  Declare the input error-free...

                oops_from = 0;

!  ...explain any inferences made (using the pattern)...

                if (inferfrom~=0)
                {   print "("; PrintCommand(inferfrom); print ")^";
                }

!  ...copy the action number, and the number of parameters...

                results-->0 = action_to_be;
                results-->1 = parameters;

!  ...reverse first and second parameters if need be...

                if (action_reversed && parameters==2)
                {   i = results-->2; results-->2 = results-->3;
                    results-->3 = i;
                    if (nsns == 2)
                    {   i = special_number1; special_number1=special_number2;
                        special_number2=i;
                    }
                }

!  ...and to reset "it"-style objects to the first of these parameters, if
!  there is one (and it really is an object)...

                if (parameters > 0 && results-->2 >= 2)
                    PronounNotice(results-->2);

!  ...and worry about the case where an object was allowed as a parameter
!  even though the player wasn't holding it and should have been: in this
!  event, keep the results for next time round, go into "not holding" mode,
!  and for now tell the player what's happening and return a "take" request
!  instead...

                if (not_holding~=0 && actor==player)
                {   notheld_mode=1;
                    for (i=0:i<8:i++) kept_results-->i = results-->i;
                    results-->0 = ##Take;
                    results-->1 = 1;
                    results-->2 = not_holding;
                    L__M(##Miscellany, 26, not_holding);
                }

!  (Notice that implicit takes are only generated for the player, and not
!  for other actors.  This avoids entirely logical, but misleading, text
!  being printed.)

!  ...and return from the parser altogether, having successfully matched
!  a line.

                if (held_back_mode==1) { wn=hb_wn; jump LookForMore; }
                rtrue;
            }
        }

!  The line has failed to match.
!  We continue the outer "for" loop, trying the next line in the grammar.

        if (etype>best_etype) best_etype=etype;
        if (etype~=ASKSCOPE_PE && etype>nextbest_etype) nextbest_etype=etype;

!  ...unless the line was something like "take all" which failed because
!  nothing matched the "all", in which case we stop and give an error now.

        if (take_all_rule == 2 && etype==NOTHING_PE) break;
   }

!  The grammar is exhausted: every line has failed to match.

!  **** (H) ****

  .GiveError;
        etype=best_etype;

!  Errors are handled differently depending on who was talking.

!  If the command was addressed to somebody else (eg, "dwarf, sfgh") then
!  it is taken as conversation which the parser has no business in disallowing.

    if (actor~=player)
    {   if (usual_grammar_after>0)
        {   verb_wordnum = usual_grammar_after;
            jump AlmostReParse;
        }
        wn=verb_wordnum;
        special_word=NextWord();
        if (special_word==comma_word)
        {   special_word=NextWord();
            verb_wordnum++;
        }
        special_number=TryNumber(verb_wordnum);
        results-->0=##NotUnderstood;
        results-->1=2;
        results-->2=1; special_number1=special_word;
        results-->3=actor;
        consult_from = verb_wordnum; consult_words = num_words-consult_from+1;
        rtrue;
    }

!  **** (I) ****

!  If the player was the actor (eg, in "take dfghh") the error must be printed,
!  and fresh input called for.  In three cases the oops word must be jiggled.

    if (ParserError(etype)~=0) jump ReType;
    pronoun_word = pronoun__word; pronoun_obj = pronoun__obj;

    if (etype==STUCK_PE)   { L__M(##Miscellany, 27); oops_from=1; }
    if (etype==UPTO_PE)    { L__M(##Miscellany, 28);
                             for (m=0:m<32:m++) pattern-->m = pattern2-->m;
                             pcount=pcount2; PrintCommand(0); print ".^";
                           }
    if (etype==NUMBER_PE)  L__M(##Miscellany, 29);
    if (etype==CANTSEE_PE) { L__M(##Miscellany, 30); oops_from=saved_oops; }
    if (etype==TOOLIT_PE)  L__M(##Miscellany, 31);
    if (etype==NOTHELD_PE) { L__M(##Miscellany, 32); oops_from=saved_oops; }
    if (etype==MULTI_PE)   L__M(##Miscellany, 33);
    if (etype==MMULTI_PE)  L__M(##Miscellany, 34);
    if (etype==VAGUE_PE)   L__M(##Miscellany, 35);
    if (etype==EXCEPT_PE)  L__M(##Miscellany, 36);
    if (etype==ANIMA_PE)   L__M(##Miscellany, 37);
    if (etype==VERB_PE)    L__M(##Miscellany, 38);
    if (etype==SCENERY_PE) L__M(##Miscellany, 39);
    if (etype==ITGONE_PE)
    {   if (pronoun_obj == NULL) L__M(##Miscellany, 35);
                            else L__M(##Miscellany, 40);
    }
    if (etype==JUNKAFTER_PE) L__M(##Miscellany, 41);
    if (etype==TOOFEW_PE)  L__M(##Miscellany, 42, multi_had);
    if (etype==NOTHING_PE) { if (multi_wanted==100) L__M(##Miscellany, 43);
                             else L__M(##Miscellany, 44);  }

    if (etype==ASKSCOPE_PE)
    {   scope_stage=3;
        if (indirect(scope_error)==-1)
        {   best_etype=nextbest_etype; jump GiveError;  }
    }

!  **** (J) ****

!  And go (almost) right back to square one...

    jump ReType;

!  ...being careful not to go all the way back, to avoid infinite repetition
!  of a deferred command causing an error.


!  **** (K) ****

!  At this point, the return value is all prepared, and we are only looking
!  to see if there is a "then" followed by subsequent instruction(s).
    
   .LookForMore;

   if (wn>num_words) rtrue;

   i=NextWord();
   if (i==THEN1__WD or THEN2__WD or THEN3__WD or comma_word)
   {   if (wn>num_words)
       {   held_back_mode = false; return; }
       i = WordAddress(verb_wordnum);
       j = WordAddress(wn);
       for (:i<j:i++) i->0 = ' ';
       i = NextWord();
       if (i==AGAIN1__WD or AGAIN2__WD or AGAIN3__WD)
       {   !   Delete the words "then again" from the again buffer,
           !   in which we have just realised that it must occur:
           !   prevents an infinite loop on "i. again"

           i = WordAddress(wn-2)-buffer;
           if (wn > num_words) j = 119; else j = WordAddress(wn)-buffer;
           for (:i<j:i++) buffer3->i = ' ';
       }
       Tokenise__(buffer,parse); held_back_mode = true; return;
   }
   best_etype=UPTO_PE; jump GiveError;
];

[ ScopeCeiling person act;
  act = parent(person); if (act == 0) return person;
  if (person == player && location == thedark) return thedark;
  while (parent(act)~=0
         && (act has transparent || act has supporter
             || (act has container && act has open)))
      act = parent(act);
  return act;
];

! ----------------------------------------------------------------------------
!  Descriptors()
!
!  Handles descriptive words like "my", "his", "another" and so on.
!  Skips "the", and leaves wn pointing to the first misunderstood word.
!
!  Allowed to set up for a plural only if allow_p is set
!
!  Returns error number, or 0 if no error occurred
! ----------------------------------------------------------------------------

Constant OTHER_BIT  =   1;     !  These will be used in Adjudicate()
Constant MY_BIT     =   2;     !  to disambiguate choices
Constant THAT_BIT   =   4;
Constant PLURAL_BIT =   8;
Constant LIT_BIT    =  16;
Constant UNLIT_BIT  =  32;

[ ResetDescriptors;
   indef_mode=0; indef_type=0; indef_wanted=0; indef_guess_p=0;
   indef_possambig = false;
   indef_owner = nothing;
   indef_cases = $$111111111111;
   indef_nspec_at = 0;
];

[ Descriptors allow_multiple  o x flag cto type n;

   ResetDescriptors();
   if (wn > num_words) return 0;

   for (flag=true:flag:)
   {   o=NextWordStopped(); flag=false;

       for (x=1:x<=LanguageDescriptors-->0:x=x+4)
           if (o == LanguageDescriptors-->x)
           {   flag = true;
               type = LanguageDescriptors-->(x+2);
               if (type ~= DEFART_PK) indef_mode = true;
               indef_possambig = true;
               indef_cases = indef_cases & (LanguageDescriptors-->(x+1));

               if (type == POSSESS_PK)
               {   cto = LanguageDescriptors-->(x+3);
                   switch(cto)
                   {  0: indef_type = indef_type | MY_BIT;
                      1: indef_type = indef_type | THAT_BIT;
                      default: indef_owner = PronounValue(cto);
                        if (indef_owner == NULL) indef_owner = InformParser;
                   }
               }

               if (type == light)
                   indef_type = indef_type | LIT_BIT;
               if (type == -light)
                   indef_type = indef_type | UNLIT_BIT;
           }

       if (o==OTHER1__WD or OTHER2__WD or OTHER3__WD)
                            { indef_mode=1; flag=1;
                              indef_type = indef_type | OTHER_BIT; }
       if (o==ALL1__WD or ALL2__WD or ALL3__WD or ALL4__WD or ALL5__WD)
                            { indef_mode=1; flag=1; indef_wanted=100;
                              if (take_all_rule == 1)
                                  take_all_rule = 2;
                              indef_type = indef_type | PLURAL_BIT; }
       if (allow_plurals && allow_multiple)
       {   n=TryNumber(wn-1);
           if (n==1)        { indef_mode=1; flag=1; }
           if (n>1)         { indef_guess_p=1;
                              indef_mode=1; flag=1; indef_wanted=n;
                              indef_nspec_at=wn-1;
                              indef_type = indef_type | PLURAL_BIT; }
       }
       if (flag==1
           && NextWordStopped() ~= OF1__WD or OF2__WD or OF3__WD or OF4__WD)
           wn--;  ! Skip 'of' after these
   }
   wn--;
   if ((indef_wanted > 0) && (~~allow_multiple)) return MULTI_PE;
   return 0;
];

! ----------------------------------------------------------------------------
!  CreatureTest: Will this person do for a "creature" token?
! ----------------------------------------------------------------------------

[ CreatureTest obj;
  if (obj has animate) rtrue;
  if (obj hasnt talkable) rfalse;
  if (action_to_be == ##Ask or ##Answer or ##Tell or ##AskFor) rtrue;
  rfalse;
];

[ PrepositionChain wd index;
  if (line_tdata-->index == wd) return wd;
  if ((line_token-->index)->0 & $20 == 0) return -1;
  do
  {   if (line_tdata-->index == wd) return wd;
      index++;
  }
  until ((line_token-->index == ENDIT_TOKEN)
         || (((line_token-->index)->0 & $10) == 0));
  return -1;
];

! ----------------------------------------------------------------------------
!  ParseToken(type, data):
!      Parses the given token, from the current word number wn, with exactly
!      the specification of a general parsing routine.
!      (Except that for "topic" tokens and prepositions, you need to supply
!      a position in a valid grammar line as third argument.)
!
!  Returns:
!    GPR_REPARSE  for "reconstructed input, please re-parse from scratch"
!    GPR_PREPOSITION  for "token accepted with no result"
!    $ff00 + x    for "please parse ParseToken(ELEMENTARY_TT, x) instead"
!    0            for "token accepted, result is the multiple object list"
!    1            for "token accepted, result is the number in parsed_number"
!    object num   for "token accepted with this object as result"
!    -1           for "token rejected"
!
!  (A)            Analyse the token; handle all tokens not involving
!                 object lists and break down others into elementary tokens
!  (B)            Begin parsing an object list
!  (C)            Parse descriptors (articles, pronouns, etc.) in the list
!  (D)            Parse an object name
!  (E)            Parse connectives ("and", "but", etc.) and go back to (C)
!  (F)            Return the conclusion of parsing an object list
! ----------------------------------------------------------------------------

[ ParseToken given_ttype given_tdata token_n x y;
  x = lookahead; lookahead = NOUN_TOKEN;
  y = ParseToken__(given_ttype,given_tdata,token_n);
  if (y == GPR_REPARSE) Tokenise__(buffer,parse);
  lookahead = x; return y;
];

[ ParseToken__ given_ttype given_tdata token_n
             token l o i j k and_parity single_object desc_wn many_flag
             token_allows_multiple;

!  **** (A) ****

   token_filter = 0;

   switch(given_ttype)
   {   ELEMENTARY_TT:
           switch(given_tdata)
           {   SPECIAL_TOKEN:
                   l=TryNumber(wn);
                   special_word=NextWord();
                   #ifdef DEBUG;
                   if (l~=-1000)
                       if (parser_trace>=3)
                           print "  [Read special as the number ", l, "]^";
                   #endif;
                   if (l==-1000)
                   {   #ifdef DEBUG;
                       if (parser_trace>=3)
                         print "  [Read special word at word number ", wn, "]^";
                       #endif;
                       l = special_word;
                   }
                   parsed_number = l; return GPR_NUMBER;

               NUMBER_TOKEN:
                   l=TryNumber(wn++);
                   if (l==-1000) { etype=NUMBER_PE; return GPR_FAIL; }
                   #ifdef DEBUG;
                   if (parser_trace>=3) print "  [Read number as ", l, "]^";
                   #endif;
                   parsed_number = l; return GPR_NUMBER;

               CREATURE_TOKEN:
                   if (action_to_be==##Answer or ##Ask or ##AskFor or ##Tell)
                       scope_reason = TALKING_REASON;

               TOPIC_TOKEN:
                   consult_from = wn;
                   if ((line_ttype-->(token_n+1) ~= PREPOSITION_TT)
                       && (line_token-->(token_n+1) ~= ENDIT_TOKEN))
                       RunTimeError(13);
                   do o=NextWordStopped();
                   until (o==-1 || PrepositionChain(o, token_n+1) ~= -1);
                   wn--;
                   consult_words = wn-consult_from;
                   if (consult_words==0) return GPR_FAIL;
                   if (action_to_be==##Ask or ##Answer or ##Tell)
                   {   o=wn; wn=consult_from; parsed_number=NextWord();
                       #IFDEF EnglishNaturalLanguage;
                       if (parsed_number=='the' && consult_words>1)
                           parsed_number=NextWord();
                       #ENDIF;
                       wn=o; return 1;
                   }
                   return GPR_PREPOSITION;
           }

       PREPOSITION_TT:
           #Iffalse Grammar__Version==1;
!  Is it an unnecessary alternative preposition, when a previous choice
!  has already been matched?
           if ((token->0) & $10) return GPR_PREPOSITION;
           #Endif;

!  If we've run out of the player's input, but still have parameters to
!  specify, we go into "infer" mode, remembering where we are and the
!  preposition we are inferring...

           if (wn > num_words)
           {   if (inferfrom==0 && parameters<params_wanted)
               {   inferfrom = pcount; inferword = token;
                   pattern-->pcount = REPARSE_CODE + Dword__No(given_tdata);
               }

!  If we are not inferring, then the line is wrong...

               if (inferfrom==0) return -1;

!  If not, then the line is right but we mark in the preposition...

               pattern-->pcount = REPARSE_CODE + Dword__No(given_tdata);
               return GPR_PREPOSITION;
           }

           o = NextWord();

           pattern-->pcount = REPARSE_CODE + Dword__No(o);

!  Whereas, if the player has typed something here, see if it is the
!  required preposition... if it's wrong, the line must be wrong,
!  but if it's right, the token is passed (jump to finish this token).

           if (o == given_tdata) return GPR_PREPOSITION;
           #Iffalse Grammar__Version==1;
           if (PrepositionChain(o, token_n) ~= -1)
               return GPR_PREPOSITION;
           #Endif;
           return -1;

       GPR_TT:
           l=indirect(given_tdata);
           #ifdef DEBUG;
           if (parser_trace>=3)
               print "  [Outside parsing routine returned ", l, "]^";
           #endif;
           return l;

       SCOPE_TT:
           scope_token = given_tdata;
           scope_stage = 1;
           l = indirect(scope_token);
           #ifdef DEBUG;
           if (parser_trace>=3)
               print "  [Scope routine returned multiple-flag of ", l, "]^";
           #endif;
           if (l==1) given_tdata = MULTI_TOKEN; else given_tdata = NOUN_TOKEN;

       ATTR_FILTER_TT:
           token_filter = 1 + given_tdata;
           given_tdata = NOUN_TOKEN;

       ROUTINE_FILTER_TT:
           token_filter = given_tdata;
           given_tdata = NOUN_TOKEN;
   }

   token = given_tdata;

!  **** (B) ****

!  There are now three possible ways we can be here:
!      parsing an elementary token other than "special" or "number";
!      parsing a scope token;
!      parsing a noun-filter token (either by routine or attribute).
!
!  In each case, token holds the type of elementary parse to
!  perform in matching one or more objects, and
!  token_filter is 0 (default), an attribute + 1 for an attribute filter
!  or a routine address for a routine filter.

   token_allows_multiple = false;
   if (token == MULTI_TOKEN or MULTIHELD_TOKEN or MULTIEXCEPT_TOKEN
                or MULTIINSIDE_TOKEN) token_allows_multiple = true;

   many_flag = false; and_parity = true; dont_infer = false;

!  **** (C) ****
!  We expect to find a list of objects next in what the player's typed.

  .ObjectList;

   #ifdef DEBUG;
   if (parser_trace>=3) print "  [Object list from word ", wn, "]^";
   #endif;

!  Take an advance look at the next word: if it's "it" or "them", and these
!  are unset, set the appropriate error number and give up on the line
!  (if not, these are still parsed in the usual way - it is not assumed
!  that they still refer to something in scope)

    o=NextWord(); wn--;

    pronoun_word = NULL; pronoun_obj = NULL;
    l = PronounValue(o);
    if (l ~= 0)
    {   pronoun_word = o; pronoun_obj = l;
        if (l == NULL)
        {   !   Don't assume this is a use of an unset pronoun until the
            !   descriptors have been checked, because it might be an
            !   article (or some such) instead

            for (l=1:l<=LanguageDescriptors-->0:l=l+4)
                if (o == LanguageDescriptors-->l) jump AssumeDescriptor;
            pronoun__word=pronoun_word; pronoun__obj=pronoun_obj;
            etype=VAGUE_PE; return GPR_FAIL;
        }
    }

    .AssumeDescriptor;

    if (o==ME1__WD or ME2__WD or ME3__WD)
    {   pronoun_word = o; pronoun_obj = player;
    }

    allow_plurals = true; desc_wn = wn;

    .TryAgain;
!   First, we parse any descriptive words (like "the", "five" or "every"):
    l = Descriptors(token_allows_multiple);
    if (l~=0) { etype=l; return GPR_FAIL; }

    .TryAgain2;

!  **** (D) ****

!  This is an actual specified object, and is therefore where a typing error
!  is most likely to occur, so we set:

    oops_from = wn;

!  So, two cases.  Case 1: token not equal to "held" (so, no implicit takes)
!  but we may well be dealing with multiple objects

!  In either case below we use NounDomain, giving it the token number as
!  context, and two places to look: among the actor's possessions, and in the
!  present location.  (Note that the order depends on which is likeliest.)

    if (token ~= HELD_TOKEN)
    {   i=multiple_object-->0;
        #ifdef DEBUG;
        if (parser_trace>=3)
            print "  [Calling NounDomain on location and actor]^";
        #endif;
        l=NounDomain(actors_location, actor, token);
        if (l==REPARSE_CODE) return l;                  ! Reparse after Q&A
        if (l==0) {   if (indef_possambig)
                      {   ResetDescriptors(); wn = desc_wn; jump TryAgain2; }
                      etype=CantSee(); jump FailToken; } ! Choose best error

        #ifdef DEBUG;
        if (parser_trace>=3)
        {   if (l>1)
                print "  [ND returned ", (the) l, "]^";
            else
            {   print "  [ND appended to the multiple object list:^";
                k=multiple_object-->0;
                for (j=i+1:j<=k:j++)
                    print "  Entry ", j, ": ", (The) multiple_object-->j,
                          " (", multiple_object-->j, ")^";
                print "  List now has size ", k, "]^";
            }
        }
        #endif;

        if (l==1)
        {   if (~~many_flag)
            {   many_flag = true;
            }
            else                                  ! Merge with earlier ones
            {   k=multiple_object-->0;            ! (with either parity)
                multiple_object-->0 = i;
                for (j=i+1:j<=k:j++)
                {   if (and_parity) MultiAdd(multiple_object-->j);
                    else MultiSub(multiple_object-->j);
                }
                #ifdef DEBUG;
                if (parser_trace>=3)
                    print "  [Merging ", k-i, " new objects to the ",
                        i, " old ones]^";
                #endif;
            }
        }
        else
        {   ! A single object was indeed found

            if (match_length == 0 && indef_possambig)
            {   !   So the answer had to be inferred from no textual data,
                !   and we know that there was an ambiguity in the descriptor
                !   stage (such as a word which could be a pronoun being
                !   parsed as an article or possessive).  It's worth having
                !   another go.

                ResetDescriptors(); wn = desc_wn; jump TryAgain2;
            }
        
            if (token==CREATURE_TOKEN && CreatureTest(l)==0)
            {   etype=ANIMA_PE; jump FailToken; } !  Animation is required

            if (~~many_flag)
                single_object = l;
            else
            {   if (and_parity) MultiAdd(l); else MultiSub(l);
                #ifdef DEBUG;
                if (parser_trace>=3)
                    print "  [Combining ", (the) l, " with list]^";
                #endif;
            }
        }
    }

!  Case 2: token is "held" (which fortunately can't take multiple objects)
!  and may generate an implicit take

    else

    {   l=NounDomain(actor,actors_location,token);       ! Same as above...
        if (l==REPARSE_CODE) return GPR_REPARSE;
        if (l==0)
        {   if (indef_possambig)
            {   ResetDescriptors(); wn = desc_wn; jump TryAgain2; }
            etype=CantSee(); return GPR_FAIL;            ! Choose best error
        }

!  ...until it produces something not held by the actor.  Then an implicit
!  take must be tried.  If this is already happening anyway, things are too
!  confused and we have to give up (but saving the oops marker so as to get
!  it on the right word afterwards).
!  The point of this last rule is that a sequence like
!
!      > read newspaper
!      (taking the newspaper first)
!      The dwarf unexpectedly prevents you from taking the newspaper!
!
!  should not be allowed to go into an infinite repeat - read becomes
!  take then read, but take has no effect, so read becomes take then read...
!  Anyway for now all we do is record the number of the object to take.

        o=parent(l);
        if (o~=actor)
        {   if (notheld_mode==1)
            {   saved_oops=oops_from; etype=NOTHELD_PE; jump FailToken;
            }
            not_holding = l;
            #ifdef DEBUG;
            if (parser_trace>=3)
                print "  [Allowing object ", (the) l, " for now]^";
            #endif;
        }
        single_object = l;
    }

!  The following moves the word marker to just past the named object...

    wn = oops_from + match_length;

!  **** (E) ****

!  Object(s) specified now: is that the end of the list, or have we reached
!  "and", "but" and so on?  If so, create a multiple-object list if we
!  haven't already (and are allowed to).

    .NextInList;

    o=NextWord();

    if (o==AND1__WD or AND2__WD or AND3__WD or BUT1__WD or BUT2__WD or BUT3__WD
           or comma_word)
    {
        #ifdef DEBUG;
        if (parser_trace>=3) print "  [Read connective '", (address) o, "']^";
        #endif;

        if (~~token_allows_multiple)
        {   etype=MULTI_PE; jump FailToken;
        }

        if (o==BUT1__WD or BUT2__WD or BUT3__WD) and_parity = 1-and_parity;

        if (~~many_flag)
        {   multiple_object-->0 = 1;
            multiple_object-->1 = single_object;
            many_flag = true;
            #ifdef DEBUG;
            if (parser_trace>=3)
                print "  [Making new list from ", (the) single_object, "]^";
            #endif;
        }
        dont_infer = true; inferfrom=0;           ! Don't print (inferences)
        jump ObjectList;                          ! And back around
    }

    wn--;   ! Word marker back to first not-understood word

!  **** (F) ****

!  Happy or unhappy endings:

    .PassToken;

    if (many_flag)
    {   single_object = GPR_MULTIPLE;
        multi_context = token;
    }
    else
    {   if (indef_mode==1 && indef_type & PLURAL_BIT ~= 0)
        {   if (indef_wanted<100 && indef_wanted>1)
            {   multi_had=1; multi_wanted=indef_wanted;
                etype=TOOFEW_PE;
                jump FailToken;
            }
        }
    }
    return single_object;

    .FailToken;

!  If we were only guessing about it being a plural, try again but only
!  allowing singulars (so that words like "six" are not swallowed up as
!  Descriptors)

    if (allow_plurals && indef_guess_p==1)
    {   allow_plurals=false; wn=desc_wn; jump TryAgain;
    }
    return -1;
];

! ----------------------------------------------------------------------------
!  NounDomain does the most substantial part of parsing an object name.
!
!  It is given two "domains" - usually a location and then the actor who is
!  looking - and a context (i.e. token type), and returns:
!
!   0    if no match at all could be made,
!   1    if a multiple object was made,
!   k    if object k was the one decided upon,
!   REPARSE_CODE if it asked a question of the player and consequently rewrote
!        the player's input, so that the whole parser should start again
!        on the rewritten input.
!
!   In the case when it returns 1<k<REPARSE_CODE, it also sets the variable
!   length_of_noun to the number of words in the input text matched to the
!   noun.
!   In the case k=1, the multiple objects are added to multiple_object by
!   hand (not by MultiAdd, because we want to allow duplicates).
! ----------------------------------------------------------------------------

[ NounDomain domain1 domain2 context    first_word i j k l
                                        answer_words marker;

#ifdef DEBUG;
  if (parser_trace>=4)
  {   print "   [NounDomain called at word ", wn, "^";
      print "   ";
      if (indef_mode)
      {   print "seeking indefinite object: ";
          if (indef_type & OTHER_BIT)  print "other ";
          if (indef_type & MY_BIT)     print "my ";
          if (indef_type & THAT_BIT)   print "that ";
          if (indef_type & PLURAL_BIT) print "plural ";
          if (indef_type & LIT_BIT)    print "lit ";
          if (indef_type & UNLIT_BIT)  print "unlit ";
          if (indef_owner ~= 0) print "owner:", (name) indef_owner;
          new_line;
          print "   number wanted: ";
          if (indef_wanted == 100) print "all"; else print indef_wanted;
          new_line;
          print "   most likely GNAs of names: ", indef_cases, "^";
      }
      else print "seeking definite object^";
  }
#endif;

  match_length=0; number_matched=0; match_from=wn; placed_in_flag=0;

  SearchScope(domain1, domain2, context);

#ifdef DEBUG;
  if (parser_trace>=4) print "   [ND made ", number_matched, " matches]^";
#endif;

  wn=match_from+match_length;

!  If nothing worked at all, leave with the word marker skipped past the
!  first unmatched word...

  if (number_matched==0) { wn++; rfalse; }

!  Suppose that there really were some words being parsed (i.e., we did
!  not just infer).  If so, and if there was only one match, it must be
!  right and we return it...

  if (match_from <= num_words)
  {   if (number_matched==1) { i=match_list-->0; return i; }

!  ...now suppose that there was more typing to come, i.e. suppose that
!  the user entered something beyond this noun.  If nothing ought to follow,
!  then there must be a mistake, (unless what does follow is just a full
!  stop, and or comma)

      if (wn<=num_words)
      {   i=NextWord(); wn--;
          if (i ~=  AND1__WD or AND2__WD or AND3__WD or comma_word
                 or THEN1__WD or THEN2__WD or THEN3__WD
                 or BUT1__WD or BUT2__WD or BUT3__WD)
          {   if (lookahead==ENDIT_TOKEN) rfalse;
          }
      }
  }

!  Now look for a good choice, if there's more than one choice...

  number_of_classes=0;
  
  if (number_matched==1) i=match_list-->0;
  if (number_matched>1)
  {   i=Adjudicate(context);
      if (i==-1) rfalse;
      if (i==1) rtrue;       !  Adjudicate has made a multiple
                             !  object, and we pass it on
  }

!  If i is non-zero here, one of two things is happening: either
!  (a) an inference has been successfully made that object i is
!      the intended one from the user's specification, or
!  (b) the user finished typing some time ago, but we've decided
!      on i because it's the only possible choice.
!  In either case we have to keep the pattern up to date,
!  note that an inference has been made and return.
!  (Except, we don't note which of a pile of identical objects.)

  if (i~=0)
  {   if (dont_infer) return i;
      if (inferfrom==0) inferfrom=pcount;
      pattern-->pcount = i;
      return i;
  }

!  If we get here, there was no obvious choice of object to make.  If in
!  fact we've already gone past the end of the player's typing (which
!  means the match list must contain every object in scope, regardless
!  of its name), then it's foolish to give an enormous list to choose
!  from - instead we go and ask a more suitable question...

  if (match_from > num_words) jump Incomplete;

!  Now we print up the question, using the equivalence classes as worked
!  out by Adjudicate() so as not to repeat ourselves on plural objects...

  if (context==CREATURE_TOKEN)
      L__M(##Miscellany, 45); else L__M(##Miscellany, 46);

  j=number_of_classes; marker=0;
  for (i=1:i<=number_of_classes:i++)
  {   
      while (((match_classes-->marker) ~= i)
             && ((match_classes-->marker) ~= -i)) marker++;
      k=match_list-->marker;

      if (match_classes-->marker > 0) print (the) k; else print (a) k;

      if (i<j-1)  print ", ";
      if (i==j-1) print (string) OR__TX;
  }
  print "?^";

!  ...and get an answer:

  .WhichOne;
  for (i=2:i<120:i++) buffer2->i=' ';
  answer_words=Keyboard(buffer2, parse2);

  first_word=(parse2-->1);

!  Take care of "all", because that does something too clever here to do
!  later on:

  if (first_word == ALL1__WD or ALL2__WD or ALL3__WD or ALL4__WD or ALL5__WD)
  {   
      if (context == MULTI_TOKEN or MULTIHELD_TOKEN or MULTIEXCEPT_TOKEN
                     or MULTIINSIDE_TOKEN)
      {   l=multiple_object-->0;
          for (i=0:i<number_matched && l+i<63:i++)
          {   k=match_list-->i;
              multiple_object-->(i+1+l) = k;
          }
          multiple_object-->0 = i+l;
          rtrue;
      }
      L__M(##Miscellany, 47);
      jump WhichOne;
  }

!  If the first word of the reply can be interpreted as a verb, then
!  assume that the player has ignored the question and given a new
!  command altogether.
!  (This is one time when it's convenient that the directions are
!  not themselves verbs - thus, "north" as a reply to "Which, the north
!  or south door" is not treated as a fresh command but as an answer.)

  #ifdef LanguageIsVerb;
  if (first_word==0)
  {   j = wn; first_word=LanguageIsVerb(buffer2, parse2, 1); wn = j;
  }
  #endif;
  if (first_word ~= 0)
  {   j=first_word->#dict_par1;
      if ((0~=j&1) && (first_word ~= 'long' or 'short' or 'normal'
                                     or 'brief' or 'full' or 'verbose'))
      {   CopyBuffer(buffer, buffer2);
          return REPARSE_CODE;
      }
  }

!  Now we insert the answer into the original typed command, as
!  words additionally describing the same object
!  (eg, > take red button
!       Which one, ...
!       > music
!  becomes "take music red button".  The parser will thus have three
!  words to work from next time, not two.)

  k = WordAddress(match_from) - buffer; l=buffer2->1+1;
  for (j=buffer + buffer->0 - 1: j>= buffer+k+l: j--)
      j->0 = 0->(j-l);
  for (i=0:i<l:i++) buffer->(k+i) = buffer2->(2+i);
  buffer->(k+l-1) = ' ';
  buffer->1 = buffer->1 + l;
  if (buffer->1 >= (buffer->0 - 1)) buffer->1 = buffer->0;

!  Having reconstructed the input, we warn the parser accordingly
!  and get out.

  return REPARSE_CODE;

!  Now we come to the question asked when the input has run out
!  and can't easily be guessed (eg, the player typed "take" and there
!  were plenty of things which might have been meant).

  .Incomplete;

  if (context==CREATURE_TOKEN)
      L__M(##Miscellany, 48); else L__M(##Miscellany, 49);

  for (i=2:i<120:i++) buffer2->i=' ';
  answer_words=Keyboard(buffer2, parse2);

  first_word=(parse2-->1);
  #ifdef LanguageIsVerb;
  if (first_word==0)
  {   j = wn; first_word=LanguageIsVerb(buffer2, parse2, 1); wn = j;
  }
  #endif;

!  Once again, if the reply looks like a command, give it to the
!  parser to get on with and forget about the question...

  if (first_word ~= 0)
  {   j=first_word->#dict_par1;
      if (0~=j&1)
      {   CopyBuffer(buffer, buffer2);
          return REPARSE_CODE;
      }
  }

!  ...but if we have a genuine answer, then:
!
!  (1) we must glue in text suitable for anything that's been inferred.

  if (inferfrom ~= 0)
  {   for (j = inferfrom: j<pcount: j++)
      {   if (pattern-->j == PATTERN_NULL) continue;
          i=2+buffer->1; (buffer->1)++; buffer->(i++) = ' ';
    
          if (parser_trace >= 5)
          print "[Gluing in inference with pattern code ", pattern-->j, "]^";

          parse2-->1 = 0;

          ! An inferred object.  Best we can do is glue in a pronoun.
          ! (This is imperfect, but it's very seldom needed anyway.)
    
          if (pattern-->j >= 2 && pattern-->j < REPARSE_CODE)
          {   PronounNotice(pattern-->j);
              for (k=1: k<=LanguagePronouns-->0: k=k+3)
                  if (pattern-->j == LanguagePronouns-->(k+2))
                  {   parse2-->1 = LanguagePronouns-->k;
                      if (parser_trace >= 5)
                      print "[Using pronoun '", (address) parse2-->1, "']^";
                      break;
                  }
          }
          else
          {   ! An inferred preposition.
              parse2-->1 = No__Dword(pattern-->j - REPARSE_CODE);
              if (parser_trace >= 5)
                  print "[Using preposition '", (address) parse2-->1, "']^";
          }
    
          ! parse2-->1 now holds the dictionary address of the word to glue in.
    
          if (parse2-->1 ~= 0)
          {   k = buffer + i;
              @output_stream 3 k;
              print (address) parse2-->1;
              @output_stream -3;
              k = k-->0;
              for (l=i:l<i+k:l++) buffer->l = buffer->(l+2);
              i = i + k; buffer->1 = i-2;
          }
      }
  }

!  (2) we must glue the newly-typed text onto the end.

  i=2+buffer->1; (buffer->1)++; buffer->(i++) = ' ';
  for (j=0: j<buffer2->1: i++, j++)
  {   buffer->i = buffer2->(j+2);
      (buffer->1)++;
      if (buffer->1 == 120) break;
  }    

!  (3) we fill up the buffer with spaces, which is unnecessary, but may
!      help incorrectly-written interpreters to cope.

  for (:i<120:i++) buffer->i = ' ';

  return REPARSE_CODE;
];

! ----------------------------------------------------------------------------
!  The Adjudicate routine tries to see if there is an obvious choice, when
!  faced with a list of objects (the match_list) each of which matches the
!  player's specification equally well.
!
!  To do this it makes use of the context (the token type being worked on).
!  It counts up the number of obvious choices for the given context
!  (all to do with where a candidate is, except for 6 (animate) which is to
!  do with whether it is animate or not);
!
!  if only one obvious choice is found, that is returned;
!
!  if we are in indefinite mode (don't care which) one of the obvious choices
!    is returned, or if there is no obvious choice then an unobvious one is
!    made;
!
!  at this stage, we work out whether the objects are distinguishable from
!    each other or not: if they are all indistinguishable from each other,
!    then choose one, it doesn't matter which;
!
!  otherwise, 0 (meaning, unable to decide) is returned (but remember that
!    the equivalence classes we've just worked out will be needed by other
!    routines to clear up this mess, so we can't economise on working them
!    out).
!
!  Returns -1 if an error occurred
! ----------------------------------------------------------------------------
Constant SCORE__CHOOSEOBJ = 1000;
Constant SCORE__IFGOOD = 500;
Constant SCORE__UNCONCEALED = 100;
Constant SCORE__BESTLOC = 60;
Constant SCORE__NEXTBESTLOC = 40;
Constant SCORE__NOTCOMPASS = 20;
Constant SCORE__NOTSCENERY = 10;
Constant SCORE__NOTACTOR = 5;
Constant SCORE__GNA = 1;
Constant SCORE__DIVISOR = 20;

[ Adjudicate context i j k good_flag good_ones last n flag offset sovert;

#ifdef DEBUG;
  if (parser_trace>=4)
  {   print "   [Adjudicating match list of size ", number_matched,
          " in context ", context, "^";
      print "   ";
      if (indef_mode)
      {   print "indefinite type: ";
          if (indef_type & OTHER_BIT)  print "other ";
          if (indef_type & MY_BIT)     print "my ";
          if (indef_type & THAT_BIT)   print "that ";
          if (indef_type & PLURAL_BIT) print "plural ";
          if (indef_type & LIT_BIT)    print "lit ";
          if (indef_type & UNLIT_BIT)  print "unlit ";
          if (indef_owner ~= 0) print "owner:", (name) indef_owner;
          new_line;
          print "   number wanted: ";
          if (indef_wanted == 100) print "all"; else print indef_wanted;
          new_line;
          print "   most likely GNAs of names: ", indef_cases, "^";
      }
      else print "definite object^";
  }
#endif;

  j=number_matched-1; good_ones=0; last=match_list-->0;
  for (i=0:i<=j:i++)
  {   n=match_list-->i;
      match_scores-->i = 0;

      good_flag = false;

      switch(context) {
          HELD_TOKEN, MULTIHELD_TOKEN:
              if (parent(n)==actor) good_flag = true;
          MULTIEXCEPT_TOKEN:
              if (advance_warning == -1) {
                  good_flag = true;
              } else {
                  if (n ~= advance_warning) good_flag = true;
              }
          MULTIINSIDE_TOKEN:
              if (advance_warning == -1) {
                  if (parent(n) ~= actor) good_flag = true;
              } else {
                  if (n in advance_warning) good_flag = true;
              }
          CREATURE_TOKEN: if (CreatureTest(n)==1) good_flag = true;
          default: good_flag = true;
      }

      if (good_flag) {
          match_scores-->i = SCORE__IFGOOD;
          good_ones++; last = n;
      }
  }
  if (good_ones==1) return last;

  ! If there is ambiguity about what was typed, but it definitely wasn't
  ! animate as required, then return anything; higher up in the parser
  ! a suitable error will be given.  (This prevents a question being asked.)
  !
  if (context==CREATURE_TOKEN && good_ones==0) return match_list-->0;

  if (indef_mode==0) indef_type=0;

  ScoreMatchL(context);
  if (number_matched == 0) return -1;

  if (indef_mode == 0)
  {   !  Is there now a single highest-scoring object?
      i = SingleBestGuess();
      if (i >= 0)
      {   
#ifdef DEBUG;
          if (parser_trace>=4)
              print "   Single best-scoring object returned.]^";
#endif;
          return i;
      }
  }

  if (indef_mode==1 && indef_type & PLURAL_BIT ~= 0)
  {   if (context ~= MULTI_TOKEN or MULTIHELD_TOKEN or MULTIEXCEPT_TOKEN
                     or MULTIINSIDE_TOKEN)
      {   etype=MULTI_PE; return -1; }
      i=0; offset=multiple_object-->0; sovert = -1;
      for (j=BestGuess():j~=-1 && i<indef_wanted
           && i+offset<63:j=BestGuess())
      {   flag=0;
          if (j hasnt concealed && j hasnt worn) flag=1;
          if (sovert == -1) sovert = bestguess_score/SCORE__DIVISOR;
          else {
              if (indef_wanted == 100
                  && bestguess_score/SCORE__DIVISOR < sovert) flag=0;
          }
          if (context==MULTIHELD_TOKEN or MULTIEXCEPT_TOKEN
              && parent(j)~=actor) flag=0;
          if (action_to_be == ##Take or ##Remove && parent(j)==actor) flag=0;
          k=ChooseObjects(j,flag);
          if (k==1) flag=1; else { if (k==2) flag=0; }
          if (flag==1)
          {   i++; multiple_object-->(i+offset) = j;
#ifdef DEBUG;
              if (parser_trace>=4) print "   Accepting it^";
#endif;
          }
          else
          {   i=i;
#ifdef DEBUG;
              if (parser_trace>=4) print "   Rejecting it^";
#endif;
          }
      }
      if (i<indef_wanted && indef_wanted<100)
      {   etype=TOOFEW_PE; multi_wanted=indef_wanted;
          multi_had=i;
          return -1;
      }
      multiple_object-->0 = i+offset;
      multi_context=context;
#ifdef DEBUG;
      if (parser_trace>=4)
          print "   Made multiple object of size ", i, "]^";
#endif;
      return 1;
  }

  for (i=0:i<number_matched:i++) match_classes-->i=0;

  n=1;
  for (i=0:i<number_matched:i++)
      if (match_classes-->i==0)
      {   match_classes-->i=n++; flag=0;
          for (j=i+1:j<number_matched:j++)
              if (match_classes-->j==0
                  && Identical(match_list-->i, match_list-->j)==1)
              {   flag=1;
                  match_classes-->j=match_classes-->i;
              }
          if (flag==1) match_classes-->i = 1-n;
      }
  n--; number_of_classes = n;

#ifdef DEBUG;
  if (parser_trace>=4)
  {   print "   Grouped into ", n, " possibilities by name:^";
      for (i=0:i<number_matched:i++)
          if (match_classes-->i > 0)
              print "   ", (The) match_list-->i,
                  " (", match_list-->i, ")  ---  group ",
                  match_classes-->i, "^";
  }
#endif;

  if (indef_mode == 0)
  {   if (n > 1)
      {   k = -1;
          for (i=0:i<number_matched:i++)
          {   if (match_scores-->i > k)
              {   k = match_scores-->i;
                  j = match_classes-->i; j=j*j;
                  flag = 0;
              }
              else
              if (match_scores-->i == k)
              {   if ((match_classes-->i) * (match_classes-->i) ~= j)
                      flag = 1;
              }
          }
          if (flag)
          {
#ifdef DEBUG;
              if (parser_trace>=4)
                  print "   Unable to choose best group, so ask player.]^";
#endif;
              return 0;
          }
#ifdef DEBUG;
          if (parser_trace>=4)
              print "   Best choices are all from the same group.^";
#endif;          
      }
  }

!  When the player is really vague, or there's a single collection of
!  indistinguishable objects to choose from, choose the one the player
!  most recently acquired, or if the player has none of them, then
!  the one most recently put where it is.

  if (n==1) dont_infer = true;
  return BestGuess();
];

! ----------------------------------------------------------------------------
!  ReviseMulti  revises the multiple object which already exists, in the
!    light of information which has come along since then (i.e., the second
!    parameter).  It returns a parser error number, or else 0 if all is well.
!    This only ever throws things out, never adds new ones.
! ----------------------------------------------------------------------------

[ ReviseMulti second_p  i low;

#ifdef DEBUG;
  if (parser_trace>=4)
      print "   Revising multiple object list of size ", multiple_object-->0,
            " with 2nd ", (name) second_p, "^";
#endif;

  if (multi_context==MULTIEXCEPT_TOKEN or MULTIINSIDE_TOKEN)
  {   for (i=1, low=0:i<=multiple_object-->0:i++)
      {   if ( (multi_context==MULTIEXCEPT_TOKEN
                && multiple_object-->i ~= second_p)
               || (multi_context==MULTIINSIDE_TOKEN
                   && multiple_object-->i in second_p))
          {   low++; multiple_object-->low = multiple_object-->i;
          }
      }
      multiple_object-->0 = low;
  }

  if (multi_context==MULTI_TOKEN && action_to_be == ##Take)
  {   for (i=1, low=0:i<=multiple_object-->0:i++)
          if (ScopeCeiling(multiple_object-->i)==ScopeCeiling(actor))
              low++;
#ifdef DEBUG;
      if (parser_trace>=4)
          print "   Token 2 plural case: number with actor ", low, "^";
#endif;
      if (take_all_rule==2 || low>0)
      {   for (i=1, low=0:i<=multiple_object-->0:i++)
          {   if (ScopeCeiling(multiple_object-->i)==ScopeCeiling(actor))
              {   low++; multiple_object-->low = multiple_object-->i;
              }
          }
          multiple_object-->0 = low;
      }
  }

  i=multiple_object-->0;
#ifdef DEBUG;
  if (parser_trace>=4)
      print "   Done: new size ", i, "^";
#endif;
  if (i==0) return NOTHING_PE;
  return 0;
];

! ----------------------------------------------------------------------------
!  ScoreMatchL  scores the match list for quality in terms of what the
!  player has vaguely asked for.  Points are awarded for conforming with
!  requirements like "my", and so on.  Remove from the match list any
!  entries which fail the basic requirements of the descriptors.
! ----------------------------------------------------------------------------

[ ScoreMatchL context its_owner its_score obj i j threshold met a_s l_s;

!  if (indef_type & OTHER_BIT ~= 0) threshold++;
  if (indef_type & MY_BIT ~= 0)    threshold++;
  if (indef_type & THAT_BIT ~= 0)  threshold++;
  if (indef_type & LIT_BIT ~= 0)   threshold++;
  if (indef_type & UNLIT_BIT ~= 0) threshold++;
  if (indef_owner ~= nothing)      threshold++;

#ifdef DEBUG;
  if (parser_trace>=4) print "   Scoring match list: indef mode ", indef_mode,
      " type ", indef_type,
      ", satisfying ", threshold, " requirements:^";
#endif;

  a_s = SCORE__NEXTBESTLOC; l_s = SCORE__BESTLOC;
  if (context == HELD_TOKEN or MULTIHELD_TOKEN or MULTIEXCEPT_TOKEN) {
      a_s = SCORE__BESTLOC; l_s = SCORE__NEXTBESTLOC;
  }

  for (i=0: i<number_matched: i++) {
      obj = match_list-->i; its_owner = parent(obj); its_score=0;

!      if (indef_type & OTHER_BIT ~=0
!          &&  obj~=itobj or himobj or herobj) met++;
      if (indef_type & MY_BIT ~=0  &&  its_owner==actor) met++;
      if (indef_type & THAT_BIT ~=0  &&  its_owner==actors_location) met++;
      if (indef_type & LIT_BIT ~=0  &&  obj has light) met++;
      if (indef_type & UNLIT_BIT ~=0  &&  obj hasnt light) met++;
      if (indef_owner~=0 && its_owner == indef_owner) met++;

      if (met < threshold)
      {
#ifdef DEBUG;
          if (parser_trace >= 4)
              print "   ", (The) match_list-->i,
                    " (", match_list-->i, ") in ", (the) its_owner,
                    " is rejected (doesn't match descriptors)^";
#endif;
          match_list-->i=-1;
      }
      else
      {   its_score = 0;
          if (obj hasnt concealed) its_score = SCORE__UNCONCEALED;

          if (its_owner==actor)   its_score = its_score + a_s;
          else
          if (its_owner==actors_location) its_score = its_score + l_s;
          else
          if (its_owner~=compass) its_score = its_score + SCORE__NOTCOMPASS;

          its_score = its_score + SCORE__CHOOSEOBJ * ChooseObjects(obj, 2);

          if (obj hasnt scenery) its_score = its_score + SCORE__NOTSCENERY;
          if (obj ~= actor) its_score = its_score + SCORE__NOTACTOR;

          !   A small bonus for having the correct GNA,
          !   for sorting out ambiguous articles and the like.

          if (indef_cases & (PowersOfTwo_TB-->(GetGNAOfObject(obj))))
              its_score = its_score + SCORE__GNA;

          match_scores-->i = match_scores-->i + its_score;
#ifdef DEBUG;
          if (parser_trace >= 4)
              print "     ", (The) match_list-->i,
                    " (", match_list-->i, ") in ", (the) its_owner,
                    " : ", match_scores-->i, " points^";
#endif;
      }
  }

  for (i=0:i<number_matched:i++)
  {   while (match_list-->i == -1)
      {   if (i == number_matched-1) { number_matched--; break; }
          for (j=i:j<number_matched:j++)
          {   match_list-->j = match_list-->(j+1);
              match_scores-->j = match_scores-->(j+1);              
          }
          number_matched--;
      }
  }
];

! ----------------------------------------------------------------------------
!  BestGuess makes the best guess it can out of the match list, assuming that
!  everything in the match list is textually as good as everything else;
!  however it ignores items marked as -1, and so marks anything it chooses.
!  It returns -1 if there are no possible choices.
! ----------------------------------------------------------------------------

[ BestGuess  earliest its_score best i;

  earliest=0; best=-1;
  for (i=0:i<number_matched:i++)
  {   if (match_list-->i >= 0)
      {   its_score=match_scores-->i;
          if (its_score>best) { best=its_score; earliest=i; }
      }
  }
#ifdef DEBUG;
  if (parser_trace>=4)
  {   if (best<0)
          print "   Best guess ran out of choices^";
      else
          print "   Best guess ", (the) match_list-->earliest,
                " (", match_list-->earliest, ")^";
  }
#endif;
  if (best<0) return -1;
  i=match_list-->earliest;
  match_list-->earliest=-1;
  bestguess_score = best;
  return i;
];

! ----------------------------------------------------------------------------
!  SingleBestGuess returns the highest-scoring object in the match list
!  if it is the clear winner, or returns -1 if there is no clear winner
! ----------------------------------------------------------------------------

[ SingleBestGuess  earliest its_score best i;

  earliest=-1; best=-1000;
  for (i=0:i<number_matched:i++)
  {   its_score=match_scores-->i;
      if (its_score==best) { earliest = -1; }
      if (its_score>best) { best=its_score; earliest=match_list-->i; }
  }
  bestguess_score = best;
  return earliest;
];

! ----------------------------------------------------------------------------
!  Identical decides whether or not two objects can be distinguished from
!  each other by anything the player can type.  If not, it returns true.
! ----------------------------------------------------------------------------

[ Identical o1 o2 p1 p2 n1 n2 i j flag;

  if (o1==o2) rtrue;  ! This should never happen, but to be on the safe side
  if (o1==0 || o2==0) rfalse;  ! Similarly
  if (parent(o1)==compass || parent(o2)==compass) rfalse; ! Saves time

!  What complicates things is that o1 or o2 might have a parsing routine,
!  so the parser can't know from here whether they are or aren't the same.
!  If they have different parsing routines, we simply assume they're
!  different.  If they have the same routine (which they probably got from
!  a class definition) then the decision process is as follows:
!
!     the routine is called (with self being o1, not that it matters)
!       with noun and second being set to o1 and o2, and action being set
!       to the fake action TheSame.  If it returns -1, they are found
!       identical; if -2, different; and if >=0, then the usual method
!       is used instead.

  if (o1.parse_name~=0 || o2.parse_name~=0)
  {   if (o1.parse_name ~= o2.parse_name) rfalse;
      parser_action=##TheSame; parser_one=o1; parser_two=o2;
      j=wn; i=RunRoutines(o1,parse_name); wn=j;
      if (i==-1) rtrue; if (i==-2) rfalse;
  }

!  This is the default algorithm: do they have the same words in their
!  "name" (i.e. property no. 1) properties.  (Note that the following allows
!  for repeated words and words in different orders.)

  p1 = o1.&1; n1 = (o1.#1)/2;
  p2 = o2.&1; n2 = (o2.#1)/2;

!  for (i=0:i<n1:i++) { print (address) p1-->i, " "; } new_line;
!  for (i=0:i<n2:i++) { print (address) p2-->i, " "; } new_line;

  for (i=0:i<n1:i++)
  {   flag=0;
      for (j=0:j<n2:j++)
          if (p1-->i == p2-->j) flag=1;
      if (flag==0) rfalse;
  }

  for (j=0:j<n2:j++)
  {   flag=0;
      for (i=0:i<n1:i++)
          if (p1-->i == p2-->j) flag=1;
      if (flag==0) rfalse;
  }

!  print "Which are identical!^";
  rtrue;
];

! ----------------------------------------------------------------------------
!  PrintCommand reconstructs the command as it presently reads, from
!  the pattern which has been built up
!
!  If from is 0, it starts with the verb: then it goes through the pattern.
!  The other parameter is "emptyf" - a flag: if 0, it goes up to pcount:
!  if 1, it goes up to pcount-1.
!
!  Note that verbs and prepositions are printed out of the dictionary:
!  and that since the dictionary may only preserve the first six characters
!  of a word (in a V3 game), we have to hand-code the longer words needed.
!
!  (Recall that pattern entries are 0 for "multiple object", 1 for "special
!  word", 2 to REPARSE_CODE-1 are object numbers and REPARSE_CODE+n means the
!  preposition n)
! ----------------------------------------------------------------------------

[ PrintCommand from i k spacing_flag;

  if (from==0)
  {   i=verb_word;
      if (LanguageVerb(i) == 0)
          if (PrintVerb(i) == 0)
              print (address) i;
      from++; spacing_flag = true;
  }

  for (k=from:k<pcount:k++)
  {   i=pattern-->k;
      if (i == PATTERN_NULL) continue;
      if (spacing_flag) print (char) ' ';
      if (i==0) { print (string) THOSET__TX; jump TokenPrinted; }
      if (i==1) { print (string) THAT__TX; jump TokenPrinted; }
      if (i>=REPARSE_CODE) print (address) No__Dword(i-REPARSE_CODE);
      else print (the) i;
      .TokenPrinted;
      spacing_flag = true;
  }
];

! ----------------------------------------------------------------------------
!  The CantSee routine returns a good error number for the situation where
!  the last word looked at didn't seem to refer to any object in context.
!
!  The idea is that: if the actor is in a location (but not inside something
!  like, for instance, a tank which is in that location) then an attempt to
!  refer to one of the words listed as meaningful-but-irrelevant there
!  will cause "you don't need to refer to that in this game" rather than
!  "no such thing" or "what's 'it'?".
!  (The advantage of not having looked at "irrelevant" local nouns until now
!  is that it stops them from clogging up the ambiguity-resolving process.
!  Thus game objects always triumph over scenery.)
! ----------------------------------------------------------------------------

[ CantSee  i w e;
    saved_oops=oops_from;

    if (scope_token~=0) { scope_error = scope_token; return ASKSCOPE_PE; }

    wn--; w=NextWord();
    e=CANTSEE_PE;
    if (w==pronoun_word)
    {   pronoun__word=pronoun_word; pronoun__obj=pronoun_obj;
        e=ITGONE_PE;
    }
    i=actor; while (parent(i) ~= 0) i = parent(i);
    if (i has visited && Refers(i,wn-1)==1) e=SCENERY_PE;
    if (etype>e) return etype;
    return e;
];

! ----------------------------------------------------------------------------
!  The MultiAdd routine adds object "o" to the multiple-object-list.
!
!  This is only allowed to hold 63 objects at most, at which point it ignores
!  any new entries (and sets a global flag so that a warning may later be
!  printed if need be).
! ----------------------------------------------------------------------------

[ MultiAdd o i j;
  i=multiple_object-->0;
  if (i==63) { toomany_flag=1; rtrue; }
  for (j=1:j<=i:j++)
      if (o==multiple_object-->j) 
          rtrue;
  i++;
  multiple_object-->i = o;
  multiple_object-->0 = i;
];

! ----------------------------------------------------------------------------
!  The MultiSub routine deletes object "o" from the multiple-object-list.
!
!  It returns 0 if the object was there in the first place, and 9 (because
!  this is the appropriate error number in Parser()) if it wasn't.
! ----------------------------------------------------------------------------

[ MultiSub o i j k et;
  i=multiple_object-->0; et=0;
  for (j=1:j<=i:j++)
      if (o==multiple_object-->j)
      {   for (k=j:k<=i:k++)
              multiple_object-->k = multiple_object-->(k+1);
          multiple_object-->0 = --i;
          return et;
      }
  et=9; return et;
];

! ----------------------------------------------------------------------------
!  The MultiFilter routine goes through the multiple-object-list and throws
!  out anything without the given attribute "attr" set.
! ----------------------------------------------------------------------------

[ MultiFilter attr  i j o;
  .MFiltl;
  i=multiple_object-->0;
  for (j=1:j<=i:j++)
  {   o=multiple_object-->j;
      if (o hasnt attr) { MultiSub(o); jump Mfiltl; }
  }
];

! ----------------------------------------------------------------------------
!  The UserFilter routine consults the user's filter (or checks on attribute)
!  to see what already-accepted nouns are acceptable
! ----------------------------------------------------------------------------

[ UserFilter obj;

  if (token_filter > 0 && token_filter < 49)
  {   if (obj has (token_filter-1)) rtrue;
      rfalse;
  }
  noun = obj;
  return indirect(token_filter);
];

! ----------------------------------------------------------------------------
!  MoveWord copies word at2 from parse buffer b2 to word at1 in "parse"
!  (the main parse buffer)
! ----------------------------------------------------------------------------

[ MoveWord at1 b2 at2 x y;
  x=at1*2-1; y=at2*2-1;
  parse-->x++ = b2-->y++;
  parse-->x = b2-->y;
];

! ----------------------------------------------------------------------------
!  SearchScope  domain1 domain2 context
!
!  Works out what objects are in scope (possibly asking an outside routine),
!  but does not look at anything the player has typed.
! ----------------------------------------------------------------------------

[ SearchScope domain1 domain2 context i;

  i=0;
!  Everything is in scope to the debugging commands

#ifdef DEBUG;
  if (scope_reason==PARSING_REASON
      && verb_word == 'purloin' or 'tree' or 'abstract'
                       or 'gonear' or 'scope' or 'showobj')
  {   for (i=selfobj:i<=top_object:i++)
          if (i ofclass Object && (parent(i)==0 || parent(i) ofclass Object))
              PlaceInScope(i);
      rtrue;
  }
#endif;

!  First, a scope token gets priority here:

  if (scope_token ~= 0)
  {   scope_stage=2;
      if (indirect(scope_token)~=0) rtrue;
  }

!  Next, call any user-supplied routine adding things to the scope,
!  which may circumvent the usual routines altogether if they return true:

  if (actor==domain1 or domain2 && InScope(actor)~=0) rtrue;

!  Pick up everything in the location except the actor's possessions;
!  then go through those.  (This ensures the actor's possessions are in
!  scope even in Darkness.)

  if (context==MULTIINSIDE_TOKEN && advance_warning ~= -1)
  {   if (IsSeeThrough(advance_warning)==1)
          ScopeWithin(advance_warning, 0, context);
  }
  else
  {   if (domain1~=0 && domain1 has supporter or container)
          ScopeWithin_O(domain1, domain1, context);
      ScopeWithin(domain1, domain2, context);
      if (domain2~=0 && domain2 has supporter or container)
          ScopeWithin_O(domain2, domain2, context);
      ScopeWithin(domain2, 0, context);
  }

!  A special rule applies:
!  in Darkness as in light, the actor is always in scope to himself.

  if (thedark == domain1 or domain2)
  {   ScopeWithin_O(actor, actor, context);
      if (parent(actor) has supporter or container)
          ScopeWithin_O(parent(actor), parent(actor), context);
  }
];

! ----------------------------------------------------------------------------
!  IsSeeThrough is used at various places: roughly speaking, it determines
!  whether o being in scope means that the contents of o are in scope.
! ----------------------------------------------------------------------------

[ IsSeeThrough o;
  if (o has supporter
      || (o has transparent)
      || (o has container && o has open))
      rtrue;
  rfalse;
];

! ----------------------------------------------------------------------------
!  PlaceInScope is provided for routines outside the library, and is not
!  called within the parser (except for debugging purposes).
! ----------------------------------------------------------------------------

[ PlaceInScope thing;
   if (scope_reason~=PARSING_REASON or TALKING_REASON)
   {   DoScopeAction(thing); rtrue; }
   wn=match_from; TryGivenObject(thing); placed_in_flag=1;
];

! ----------------------------------------------------------------------------
!  DoScopeAction
! ----------------------------------------------------------------------------

[ DoScopeAction thing s p1;
  s = scope_reason; p1=parser_one;
#ifdef DEBUG;
  if (parser_trace>=6)
  {   print "[DSA on ", (the) thing, " with reason = ", scope_reason,
      " p1 = ", parser_one, " p2 = ", parser_two, "]^";
  }
#endif;
  switch(scope_reason)
  {   REACT_BEFORE_REASON:
          if (thing.react_before==0 or NULL) return;
#ifdef DEBUG;
          if (parser_trace>=2)
          {   print "[Considering react_before for ", (the) thing, "]^"; }
#endif;
          if (parser_one==0) parser_one = RunRoutines(thing,react_before);
      REACT_AFTER_REASON:
          if (thing.react_after==0 or NULL) return;
#ifdef DEBUG;
          if (parser_trace>=2)
          {   print "[Considering react_after for ", (the) thing, "]^"; }
#endif;
          if (parser_one==0) parser_one = RunRoutines(thing,react_after);
      EACH_TURN_REASON:
          if (thing.each_turn == 0 or NULL) return;
#ifdef DEBUG;
          if (parser_trace>=2)
          {   print "[Considering each_turn for ", (the) thing, "]^"; }
#endif;
          PrintOrRun(thing, each_turn);
      TESTSCOPE_REASON:
          if (thing==parser_one) parser_two = 1;
      LOOPOVERSCOPE_REASON:
          indirect(parser_one,thing); parser_one=p1;
  }
  scope_reason = s;
];

! ----------------------------------------------------------------------------
!  ScopeWithin looks for objects in the domain which make textual sense
!  and puts them in the match list.  (However, it does not recurse through
!  the second argument.)
! ----------------------------------------------------------------------------

[ ScopeWithin domain nosearch context x y;

   if (domain==0) rtrue;

!  Special rule: the directions (interpreted as the 12 walls of a room) are
!  always in context.  (So, e.g., "examine north wall" is always legal.)
!  (Unless we're parsing something like "all", because it would just slow
!  things down then, or unless the context is "creature".)

   if (indef_mode==0 && domain==actors_location
       && scope_reason==PARSING_REASON && context~=CREATURE_TOKEN)
           ScopeWithin(compass);

!  Look through the objects in the domain, avoiding "objectloop" in case
!  movements occur, e.g. when trying each_turn.

   x = child(domain);
   while (x ~= 0)
   {   y = sibling(x);
       ScopeWithin_O(x, nosearch, context);
       x = y;
   }
];

[ ScopeWithin_O domain nosearch context i ad n;

!  multiexcept doesn't have second parameter in scope
   if (context==MULTIEXCEPT_TOKEN && domain==advance_warning) jump DontAccept;

!  If the scope reason is unusual, don't parse.

      if (scope_reason~=PARSING_REASON or TALKING_REASON)
      {   DoScopeAction(domain); jump DontAccept; }

!  "it" or "them" matches to the it-object only.  (Note that (1) this means
!  that "it" will only be understood if the object in question is still
!  in context, and (2) only one match can ever be made in this case.)

      if (match_from <= num_words)  ! If there's any text to match, that is
      {   wn=match_from;
          i=NounWord();
          if (i==1 && player==domain)  MakeMatch(domain, 1);

          if (i>=2 && i<128 && (LanguagePronouns-->i == domain))
              MakeMatch(domain, 1);
      }

!  Construing the current word as the start of a noun, can it refer to the
!  object?

      wn = match_from;
      if (TryGivenObject(domain) > 0)
          if (indef_nspec_at>0 && match_from~=indef_nspec_at)
          {   !  This case arises if the player has typed a number in
              !  which is hypothetically an indefinite descriptor:
              !  e.g. "take two clubs".  We have just checked the object
              !  against the word "clubs", in the hope of eventually finding
              !  two such objects.  But we also backtrack and check it
              !  against the words "two clubs", in case it turns out to
              !  be the 2 of Clubs from a pack of cards, say.  If it does
              !  match against "two clubs", we tear up our original
              !  assumption about the meaning of "two" and lapse back into
              !  definite mode.
          
              wn = indef_nspec_at;
              if (TryGivenObject(domain) > 0)
              {   match_from = indef_nspec_at;
                  ResetDescriptors();                  
              }
              wn = match_from;
          }

      .DontAccept;

!  Shall we consider the possessions of the current object, as well?
!  Only if it's a container (so, for instance, if a dwarf carries a
!  sword, then "drop sword" will not be accepted, but "dwarf, drop sword"
!  will).
!  Also, only if there are such possessions.
!
!  Notice that the parser can see "into" anything flagged as
!  transparent - such as a dwarf whose sword you can get at.

      if (child(domain)~=0 && domain ~= nosearch && IsSeeThrough(domain)==1)
          ScopeWithin(domain,nosearch,context);

!  Drag any extras into context

   ad = domain.&add_to_scope;
   if (ad ~= 0)
   {   if (UnsignedCompare(ad-->0,top_object) > 0)
       {   ats_flag = 2+context;
           RunRoutines(domain, add_to_scope);
           ats_flag = 0;
       }
       else
       {   n=domain.#add_to_scope;
           for (i=0:(2*i)<n:i++)
               ScopeWithin_O(ad-->i,0,context);
       }
   }
];

[ AddToScope obj;
   if (ats_flag>=2)
       ScopeWithin_O(obj,0,ats_flag-2);
   if (ats_flag==1)
   {   if  (HasLightSource(obj)==1) ats_hls = 1;
   }
];

! ----------------------------------------------------------------------------
!  MakeMatch looks at how good a match is.  If it's the best so far, then
!  wipe out all the previous matches and start a new list with this one.
!  If it's only as good as the best so far, add it to the list.
!  If it's worse, ignore it altogether.
!
!  The idea is that "red panic button" is better than "red button" or "panic".
!
!  number_matched (the number of words matched) is set to the current level
!  of quality.
!
!  We never match anything twice, and keep at most 64 equally good items.
! ----------------------------------------------------------------------------

[ MakeMatch obj quality i;
#ifdef DEBUG;
   if (parser_trace>=6) print "    Match with quality ",quality,"^";
#endif;
   if (token_filter~=0 && UserFilter(obj)==0)
   {   #ifdef DEBUG;
       if (parser_trace>=6)
       {   print "    Match filtered out: token filter ", token_filter, "^";
       }
       #endif;
       rtrue;
   }
   if (quality < match_length) rtrue;
   if (quality > match_length) { match_length=quality; number_matched=0; }
   else
   {   if (2*number_matched>=MATCH_LIST_SIZE) rtrue;
       for (i=0:i<number_matched:i++)
           if (match_list-->i==obj) rtrue;
   }
   match_list-->number_matched++ = obj;
#ifdef DEBUG;
   if (parser_trace>=6) print "    Match added to list^";
#endif;
];

! ----------------------------------------------------------------------------
!  TryGivenObject tries to match as many words as possible in what has been
!  typed to the given object, obj.  If it manages any words matched at all,
!  it calls MakeMatch to say so, then returns the number of words (or 1
!  if it was a match because of inadequate input).
! ----------------------------------------------------------------------------

[ TryGivenObject obj threshold k w j;

#ifdef DEBUG;
   if (parser_trace>=5)
       print "    Trying ", (the) obj, " (", obj, ") at word ", wn, "^";
#endif;

   dict_flags_of_noun = 0;

!  If input has run out then always match, with only quality 0 (this saves
!  time).

   if (wn > num_words)
   {   if (indef_mode ~= 0)
           dict_flags_of_noun = $$01110000;  ! Reject "plural" bit
       MakeMatch(obj,0);
       #ifdef DEBUG;
       if (parser_trace>=5)
       print "    Matched (0)^";
       #endif;
       return 1;
   }

!  Ask the object to parse itself if necessary, sitting up and taking notice
!  if it says the plural was used:

   if (obj.parse_name~=0)
   {   parser_action = NULL; j=wn;
       k=RunRoutines(obj,parse_name);
       if (k>0)
       {   wn=j+k;
           .MMbyPN;

           if (parser_action == ##PluralFound)
               dict_flags_of_noun = dict_flags_of_noun | 4;

           if (dict_flags_of_noun & 4)
           {   if (~~allow_plurals) k=0;
               else
               {   if (indef_mode==0)
                   {   indef_mode=1; indef_type=0; indef_wanted=0; }
                   indef_type = indef_type | PLURAL_BIT;
                   if (indef_wanted==0) indef_wanted=100;
               }
           }

           #ifdef DEBUG;
               if (parser_trace>=5)
               {   print "    Matched (", k, ")^";
               }
           #endif;
           MakeMatch(obj,k);
           return k;
       }
       if (k==0) jump NoWordsMatch;
   }

!  The default algorithm is simply to count up how many words pass the
!  Refers test:

   parser_action = NULL;

   w = NounWord();

   if (w==1 && player==obj) { k=1; jump MMbyPN; }

   if (w>=2 && w<128 && (LanguagePronouns-->w == obj))
   {   k=1; jump MMbyPN; }

   j=--wn;
   threshold = ParseNoun(obj);
#ifdef DEBUG;
   if (threshold>=0 && parser_trace>=5)
       print "    ParseNoun returned ", threshold, "^";
#endif;
   if (threshold<0) wn++;
   if (threshold>0) { k=threshold; jump MMbyPN; }

   if (threshold==0 || Refers(obj,wn-1)==0)
   {   .NoWordsMatch;
       if (indef_mode~=0)
       {   k=0; parser_action=NULL; jump MMbyPN;
       }
       rfalse;
   }

   if (threshold<0)
   {   threshold=1;
       dict_flags_of_noun = (w->#dict_par1) & $$01110100;
       w = NextWord();
       while (Refers(obj, wn-1))
       {   threshold++;
           if (w)
               dict_flags_of_noun = dict_flags_of_noun
                                    | ((w->#dict_par1) & $$01110100);
           w = NextWord();
       }
   }

   k = threshold; jump MMbyPN;
];

! ----------------------------------------------------------------------------
!  Refers works out whether the word at number wnum can refer to the object
!  obj, returning true or false.  The standard method is to see if the
!  word is listed under "name" for the object, but this is more complex
!  in languages other than English.
! ----------------------------------------------------------------------------

[ Refers obj wnum   wd k l m;
    if (obj==0) rfalse;

    #ifdef LanguageRefers;
    k = LanguageRefers(obj,wnum); if (k>=0) return k;
    #endif;

    k = wn; wn = wnum; wd = NextWordStopped(); wn = k;

    if (parser_inflection >= 256)
    {   k = indirect(parser_inflection, obj, wd);
        if (k>=0) return k;
        m = -k;
    } else m = parser_inflection;
    k=obj.&m; l=(obj.#m)/2-1;
    for (m=0:m<=l:m++)
        if (wd==k-->m) rtrue;
    rfalse;
];

[ WordInProperty wd obj prop k l m;
    k=obj.&prop; l=(obj.#prop)/2-1;
    for (m=0:m<=l:m++)
        if (wd==k-->m) rtrue;
    rfalse;
];

[ DictionaryLookup b l i;
  for (i=0:i<l:i++) buffer2->(2+i) = b->i;
  buffer2->1 = l;
  Tokenise__(buffer2,parse2);
  return parse2-->1;
];

! ----------------------------------------------------------------------------
!  NounWord (which takes no arguments) returns:
!
!   0  if the next word is unrecognised or does not carry the "noun" bit in
!      its dictionary entry,
!   1  if a word meaning "me",
!   the index in the pronoun table (plus 2) of the value field of a pronoun,
!      if the word is a pronoun,
!   the address in the dictionary if it is a recognised noun.
!
!  The "current word" marker moves on one.
! ----------------------------------------------------------------------------

[ NounWord i j s;
   i=NextWord();
   if (i==0) rfalse;
   if (i==ME1__WD or ME2__WD or ME3__WD) return 1;
   s = LanguagePronouns-->0;
   for (j=1 : j<=s : j=j+3)
       if (i == LanguagePronouns-->j)
           return j+2;
   if ((i->#dict_par1)&128 == 0) rfalse;
   return i;
];

! ----------------------------------------------------------------------------
!  NextWord (which takes no arguments) returns:
!
!  0            if the next word is unrecognised,
!  comma_word   if a comma
!  THEN1__WD    if a full stop
!  or the dictionary address if it is recognised.
!  The "current word" marker is moved on.
!
!  NextWordStopped does the same, but returns -1 when input has run out
! ----------------------------------------------------------------------------

[ NextWord i j;
   if (wn > parse->1) { wn++; rfalse; }
   i=wn*2-1; wn++;
   j=parse-->i;
   if (j == ',//') j=comma_word;
   if (j == './/') j=THEN1__WD;
   return j;
];   

[ NextWordStopped;
   if (wn > parse->1) { wn++; return -1; }
   return NextWord();
];

[ WordAddress wordnum;
   return buffer + parse->(wordnum*4+1);
];

[ WordLength wordnum;
   return parse->(wordnum*4);
];

! ----------------------------------------------------------------------------
!  TryNumber is the only routine which really does any character-level
!  parsing, since that's normally left to the Z-machine.
!  It takes word number "wordnum" and tries to parse it as an (unsigned)
!  decimal number, returning
!
!  -1000                if it is not a number
!  the number           if it has between 1 and 4 digits
!  10000                if it has 5 or more digits.
!
!  (The danger of allowing 5 digits is that Z-machine integers are only
!  16 bits long, and anyway this isn't meant to be perfect.)
!
!  Using NumberWord, it also catches "one" up to "twenty".
!
!  Note that a game can provide a ParseNumber routine which takes priority,
!  to enable parsing of odder numbers ("x45y12", say).
! ----------------------------------------------------------------------------

[ TryNumber wordnum   i j c num len mul tot d digit;

   i=wn; wn=wordnum; j=NextWord(); wn=i;
   j=NumberWord(j); if (j>=1) return j;

   i=wordnum*4+1; j=parse->i; num=j+buffer; len=parse->(i-1);

   tot=ParseNumber(num, len);  if (tot~=0) return tot;

   if (len>=4) mul=1000;
   if (len==3) mul=100;
   if (len==2) mul=10;
   if (len==1) mul=1;

   tot=0; c=0; len=len-1;

   for (c=0:c<=len:c++)
   {   digit=num->c;
       if (digit=='0') { d=0; jump digok; }
       if (digit=='1') { d=1; jump digok; }
       if (digit=='2') { d=2; jump digok; }
       if (digit=='3') { d=3; jump digok; }
       if (digit=='4') { d=4; jump digok; }
       if (digit=='5') { d=5; jump digok; }
       if (digit=='6') { d=6; jump digok; }
       if (digit=='7') { d=7; jump digok; }
       if (digit=='8') { d=8; jump digok; }
       if (digit=='9') { d=9; jump digok; }
       return -1000;
     .digok;
       tot=tot+mul*d; mul=mul/10;
   }
   if (len>3) tot=10000;
   return tot;
];

! ----------------------------------------------------------------------------
!  GetGender returns 0 if the given animate object is female, and 1 if male
!  (not all games will want such a simple decision function!)
! ----------------------------------------------------------------------------

[ GetGender person;
   if (person hasnt female) rtrue;
   rfalse;
];

[ GetGNAOfObject obj case gender;
   if (obj hasnt animate) case = 6;
   if (obj has male) gender = male;
   if (obj has female) gender = female;
   if (obj has neuter) gender = neuter;
   if (gender == 0)
   {   if (case == 0) gender = LanguageAnimateGender;
       else gender = LanguageInanimateGender;
   }
   if (gender == female) case = case + 1;
   if (gender == neuter) case = case + 2;
   if (obj has pluralname) case = case + 3;
   return case;
];

! ----------------------------------------------------------------------------
!  Converting between dictionary addresses and entry numbers
! ----------------------------------------------------------------------------

[ Dword__No w; return (w-(0-->4 + 7))/9; ];
[ No__Dword n; return 0-->4 + 7 + 9*n; ];

! ----------------------------------------------------------------------------
!  For copying buffers
! ----------------------------------------------------------------------------

[ CopyBuffer bto bfrom i size;
   size=bto->0;
   for (i=1:i<=size:i++) bto->i=bfrom->i;
];

! ----------------------------------------------------------------------------
!  Provided for use by language definition files
! ----------------------------------------------------------------------------

[ LTI_Insert i ch  b y;

  !   Protect us from strict mode, as this isn't an array in quite the
  !   sense it expects
      b = buffer;

  !   Insert character ch into buffer at point i.

  !   Being careful not to let the buffer possibly overflow:

      y = b->1;
      if (y > b->0) y = b->0;

  !   Move the subsequent text along one character:

      for (y=y+2: y>i : y--) b->y = b->(y-1);
      b->i = ch;

  !   And the text is now one character longer:
      if (b->1 < b->0) (b->1)++;
];

! ============================================================================

[ PronounsSub x y c d;

  L__M(##Pronouns, 1);

  c = (LanguagePronouns-->0)/3;
  if (player ~= selfobj) c++;

  if (c==0) return L__M(##Pronouns, 4);

  for (x = 1, d = 0 : x <= LanguagePronouns-->0: x = x+3)
  {   print "~", (address) LanguagePronouns-->x, "~ ";
      y = LanguagePronouns-->(x+2);
      if (y == NULL) L__M(##Pronouns, 3);
      else { L__M(##Pronouns, 2); print (the) y; }
      d++;
      if (d < c-1) print ", ";
      if (d == c-1) print (string) AND__TX;
  }
  if (player ~= selfobj)
  {   print "~", (address) ME1__WD, "~ "; L__M(##Pronouns, 2);
      c = player; player = selfobj;
      print (the) c; player = c;
  }
  ".";
];

[ SetPronoun dword value x;
  for (x = 1 : x <= LanguagePronouns-->0: x = x+3)
      if (LanguagePronouns-->x == dword)
      {   LanguagePronouns-->(x+2) = value; return;
      }
  RunTimeError(14);
];

[ PronounValue dword x;
  for (x = 1 : x <= LanguagePronouns-->0: x = x+3)
      if (LanguagePronouns-->x == dword)
          return LanguagePronouns-->(x+2);
  return 0;
];

[ ResetVagueWords obj; PronounNotice(obj); ];

#ifdef EnglishNaturalLanguage;
[ PronounOldEnglish;
   if (itobj ~= old_itobj)   SetPronoun('it', itobj);
   if (himobj ~= old_himobj) SetPronoun('him', himobj);
   if (herobj ~= old_herobj) SetPronoun('her', herobj);
   old_itobj = itobj; old_himobj = himobj; old_herobj = herobj;
];
#endif;

[ PronounNotice obj x bm;

   if (obj == player) return;

   #ifdef EnglishNaturalLanguage;
   PronounOldEnglish();
   #endif;

   bm = PowersOfTwo_TB-->(GetGNAOfObject(obj));

   for (x = 1 : x <= LanguagePronouns-->0: x = x+3)
       if (bm & (LanguagePronouns-->(x+1)) ~= 0)
           LanguagePronouns-->(x+2) = obj;

   #ifdef EnglishNaturalLanguage;
   itobj  = PronounValue('it');  old_itobj  = itobj;
   himobj = PronounValue('him'); old_himobj = himobj;
   herobj = PronounValue('her'); old_herobj = herobj;
   #endif;
];

! ============================================================================
!  End of the parser proper: the remaining routines are its front end.
! ----------------------------------------------------------------------------

Object InformLibrary "(Inform Library)"
  with play
       [ i j k l;
       standard_interpreter = $32-->0;
       transcript_mode = ((0-->8) & 1);
       ChangeDefault(cant_go, CANTGO__TX);

       buffer->0 = 120;
       buffer2->0 = 120;
       buffer3->0 = 120;
       parse->0 = 64;
       parse2->0 = 64;
       
       real_location = thedark;
       player = selfobj; actor = player;
    
       top_object = #largest_object-255;
       selfobj.capacity = MAX_CARRIED;
       #ifdef LanguageInitialise;
       LanguageInitialise();
       #endif;
       new_line;
       j=Initialise();
       last_score = score;
       move player to location;
       while (parent(location)~=0) location=parent(location);
       real_location = location;
       objectloop (i in player) give i moved ~concealed;
    
       if (j~=2) Banner();

       MoveFloatingObjects();
       lightflag=OffersLight(parent(player));
       if (lightflag==0) { real_location=location; location=thedark; }
       <Look>;
    
       for (i=1:i<=100:i++) j=random(i);

       #ifdef EnglishNaturalLanguage;
       old_itobj = itobj; old_himobj = himobj; old_herobj = herobj;
       #endif;
    
       while (~~deadflag)
       {   
           #ifdef EnglishNaturalLanguage;
               PronounOldEnglish();
               old_itobj = PronounValue('it');
               old_himobj = PronounValue('him');
               old_herobj = PronounValue('her');
           #endif;

           .very__late__error;

           if (score ~= last_score)
           {   if (notify_mode==1) NotifyTheScore(); last_score=score; }

           .late__error;

           inputobjs-->0 = 0; inputobjs-->1 = 0;
           inputobjs-->2 = 0; inputobjs-->3 = 0; meta=false;
    
           !  The Parser writes its results into inputobjs and meta,
           !  a flag indicating a "meta-verb".  This can only be set for
           !  commands by the player, not for orders to others.
    
           InformParser.parse_input(inputobjs);
    
           action=inputobjs-->0;

           !  --------------------------------------------------------------

           !  Reverse "give fred biscuit" into "give biscuit to fred"
    
           if (action==##GiveR or ##ShowR)
           {   i=inputobjs-->2; inputobjs-->2=inputobjs-->3; inputobjs-->3=i;
               if (action==##GiveR) action=##Give; else action=##Show;
           }
    
           !  Convert "P, tell me about X" to "ask P about X"
    
           if (action==##Tell && inputobjs-->2==player && actor~=player)
           {   inputobjs-->2=actor; actor=player; action=##Ask;
           }
    
           !  Convert "ask P for X" to "P, give X to me"
    
           if (action==##AskFor && inputobjs-->2~=player && actor==player)
           {   actor=inputobjs-->2; inputobjs-->2=inputobjs-->3;
               inputobjs-->3=player; action=##Give;
           }
    
           !  For old, obsolete code: special_word contains the topic word
           !  in conversation
    
           if (action==##Ask or ##Tell or ##Answer)
               special_word = special_number1;

           !  --------------------------------------------------------------
    
           multiflag=false; onotheld_mode=notheld_mode; notheld_mode=false;
           !  For implicit taking and multiple object detection
    
          .begin__action;
           inp1 = 0; inp2 = 0; i=inputobjs-->1;
           if (i>=1) inp1=inputobjs-->2;
           if (i>=2) inp2=inputobjs-->3;
    
           !  inp1 and inp2 hold: object numbers, or 0 for "multiple object",
           !  or 1 for "a number or dictionary address"
    
           if (inp1 == 1) noun = special_number1; else noun = inp1;
           if (inp2 == 1)
           {   if (inp1 == 1) second = special_number2;
               else second = special_number1;
           } else second = inp2;

           !  --------------------------------------------------------------
    
           if (actor~=player)
           {   
           !  The player's "orders" property can refuse to allow conversation
           !  here, by returning true.  If not, the order is sent to the
           !  other person's "orders" property.  If that also returns false,
           !  then: if it was a misunderstood command anyway, it is converted
           !  to an Answer action (thus "floyd, grrr" ends up as
           !  "say grrr to floyd").  If it was a good command, it is finally
           !  offered to the Order: part of the other person's "life"
           !  property, the old-fashioned way of dealing with conversation.
    
               j=RunRoutines(player,orders);
               if (j==0)
               {   j=RunRoutines(actor,orders);
                   if (j==0)
                   {   if (action==##NotUnderstood)
                       {   inputobjs-->3=actor; actor=player; action=##Answer;
                           jump begin__action;
                       }
                       if (RunLife(actor,##Order)==0) L__M(##Order,1,actor);
                   }
               }
               jump turn__end;
           }

           !  --------------------------------------------------------------
           !  Generate the action...

           if ((i==0)
               || (i==1 && inp1 ~= 0)
               || (i==2 && inp1 ~= 0 && inp2 ~= 0))
           {   self.begin_action(action, noun, second, 0);
               jump turn__end;
           }

           !  ...unless a multiple object must be substituted.  First:
           !  (a) check the multiple list isn't empty;
           !  (b) warn the player if it has been cut short because too long;
           !  (c) generate a sequence of actions from the list
           !      (stopping in the event of death or movement away).

           multiflag = true;
           j=multiple_object-->0;
           if (j==0) { L__M(##Miscellany,2); jump late__error; }
           if (toomany_flag)
           {   toomany_flag = false; L__M(##Miscellany,1); }
           i=location;
           for (k=1:k<=j:k++)
           {   if (deadflag) break;
               if (location ~= i)
               {   L__M(##Miscellany, 51);
                   break;
               }
               l = multiple_object-->k;
               PronounNotice(l);
               print (name) l, ": ";
               if (inp1 == 0)
               {   inp1 = l; self.begin_action(action, l, second, 0); inp1 = 0;
               }
               else
               {   inp2 = l; self.begin_action(action, noun, l, 0); inp2 = 0;
               }
           }

           !  --------------------------------------------------------------
    
           .turn__end;
    
           !  No time passes if either (i) the verb was meta, or
           !  (ii) we've only had the implicit take before the "real"
           !  action to follow.
    
           if (notheld_mode==1) { NoteObjectAcquisitions(); continue; }
           if (meta) continue;
           if (~~deadflag) self.end_turn_sequence();
       }

           if (deadflag~=2) AfterLife();
           if (deadflag==0) jump very__late__error;
    
           print "^^    ";
           #IFV5; style bold; #ENDIF;
           print "***";
           if (deadflag==1) L__M(##Miscellany,3);
           if (deadflag==2) L__M(##Miscellany,4);
           if (deadflag>2)  { print " "; DeathMessage(); print " "; }
           print "***";
           #IFV5; style roman; #ENDIF;
           print "^^^";
           ScoreSub();
           DisplayStatus();
           AfterGameOver();
       ],

       end_turn_sequence
       [ i j;

           turns++;
           if (the_time~=NULL)
           {   if (time_rate>=0) the_time=the_time+time_rate;
               else
               {   time_step--;
                   if (time_step==0)
                   {   the_time++;
                       time_step = -time_rate;
                   }
               }
               the_time=the_time % 1440;
           }

           #IFDEF DEBUG;
           if (debug_flag & 4 ~= 0)
           {   for (i=0: i<active_timers: i++)
               {   j=the_timers-->i;
                   if (j~=0)
                   {   print (name) (j&$7fff), ": ";
                       if (j & $8000) print "daemon";
                       else
                       {   print "timer with ",
                                 j.time_left, " turns to go"; }
                       new_line;
                   }
               }
           }
           #ENDIF;

           for (i=0: i<active_timers: i++)
           {   if (deadflag) return;
               j=the_timers-->i;
               if (j~=0)
               {   if (j & $8000) RunRoutines(j&$7fff,daemon);
                   else
                   {   if (j.time_left==0)
                       {   StopTimer(j);
                           RunRoutines(j,time_out);
                       }
                       else
                           j.time_left=j.time_left-1;
                   }
               }
           }
           if (deadflag) return;

           scope_reason=EACH_TURN_REASON; verb_word=0;
           DoScopeAction(location);
           SearchScope(ScopeCeiling(player), player, 0);
           scope_reason=PARSING_REASON;

           if (deadflag) return;

           TimePasses();

           if (deadflag) return;

           AdjustLight();

           if (deadflag) return;

           NoteObjectAcquisitions();
       ],

       begin_action
       [ a n s source   sa sn ss;
           sa = action; sn = noun; ss = second;
           action = a; noun = n; second = s;
           #IFDEF DEBUG;
           if (debug_flag & 2 ~= 0) TraceAction(source);
           #IFNOT;
           source = 0;
           #ENDIF;
           #IFTRUE Grammar__Version == 1;
           if ((meta || BeforeRoutines()==false) && action<256)
               ActionPrimitive();
           #IFNOT;
           if ((meta || BeforeRoutines()==false) && action<4096)
               ActionPrimitive();
           #ENDIF;
           action = sa; noun = sn; second = ss;
       ],
  has  proper;

[ ActionPrimitive;
  indirect(#actions_table-->action);
];
       
[ AfterGameOver i;
   .RRQPL;
   L__M(##Miscellany,5);
   .RRQL;
   print "> ";
   #IFV3; read buffer parse; #ENDIF;
   temp_global=0;
   #IFV5; read buffer parse DrawStatusLine; #ENDIF;
   i=parse-->1;
   if (i==QUIT1__WD or QUIT2__WD) quit;
   if (i==RESTART__WD)      @restart;
   if (i==RESTORE__WD)      { RestoreSub(); jump RRQPL; }
   if (i==FULLSCORE1__WD or FULLSCORE2__WD && TASKS_PROVIDED==0)
   {   new_line; FullScoreSub(); jump RRQPL; }
   if (deadflag==2 && i==AMUSING__WD && AMUSING_PROVIDED==0)
   {   new_line; Amusing(); jump RRQPL; }
   #IFV5;
   if (i==UNDO1__WD or UNDO2__WD or UNDO3__WD)
   {   if (undo_flag==0)
       {   L__M(##Miscellany,6);
           jump RRQPL;
       }
       if (undo_flag==1) jump UndoFailed2;
       @restore_undo i;
       if (i==0)
       {   .UndoFailed2; L__M(##Miscellany,7);
       }
       jump RRQPL;
   }
   #ENDIF;
   L__M(##Miscellany,8);
   jump RRQL;
];

[ R_Process a i j s1 s2;
   s1 = inp1; s2 = inp2;
   inp1 = i; inp2 = j; InformLibrary.begin_action(a, i, j, 1);
   inp1 = s1; inp2 = s2;
];

[ NoteObjectAcquisitions i;
  objectloop (i in player && i hasnt moved)
  {   give i moved;
      if (i has scored)
      {   score = score + OBJECT_SCORE;
          things_score = things_score + OBJECT_SCORE;
      }
  }
];

! ----------------------------------------------------------------------------

[ TestScope obj act a al sr x y;
  x=parser_one; y=parser_two;
  parser_one=obj; parser_two=0; a=actor; al=actors_location;
  sr=scope_reason; scope_reason=TESTSCOPE_REASON;
  if (act==0) actor=player; else actor=act;
  actors_location=ScopeCeiling(actor);
  SearchScope(actors_location,actor,0); scope_reason=sr; actor=a;
  actors_location=al; parser_one=x; x=parser_two; parser_two=y;
  return x;
];

[ LoopOverScope routine act x y a al;
  x = parser_one; y=scope_reason; a=actor; al=actors_location;
  parser_one=routine; if (act==0) actor=player; else actor=act;
  actors_location=ScopeCeiling(actor);
  scope_reason=LOOPOVERSCOPE_REASON;
  SearchScope(actors_location,actor,0);
  parser_one=x; scope_reason=y; actor=a; actors_location=al;
];

[ BeforeRoutines;
  if (GamePreRoutine()~=0) rtrue;
  if (RunRoutines(player,orders)~=0) rtrue;
  if (location~=0 && RunRoutines(location,before)~=0) rtrue;
  scope_reason=REACT_BEFORE_REASON; parser_one=0;
  SearchScope(ScopeCeiling(player),player,0); scope_reason=PARSING_REASON;
  if (parser_one~=0) rtrue;
  if (inp1>1 && RunRoutines(inp1,before)~=0) rtrue;
  rfalse;
];

[ AfterRoutines;
  scope_reason=REACT_AFTER_REASON; parser_one=0;
  SearchScope(ScopeCeiling(player),player,0); scope_reason=PARSING_REASON;
  if (parser_one~=0) rtrue;
  if (location~=0 && RunRoutines(location,after)~=0) rtrue;
  if (inp1>1 && RunRoutines(inp1,after)~=0) rtrue;
  return GamePostRoutine();
];

[ RunLife a j;
#IFDEF DEBUG;
   if (debug_flag & 2 ~= 0) TraceAction(2, j);
#ENDIF;
   reason_code = j; return RunRoutines(a,life);
];

[ ZRegion addr;
  switch(metaclass(addr))       ! Left over from Inform 5
  {   nothing: return 0;
      Object, Class: return 1;
      Routine: return 2;
      String: return 3;
  }
];

[ PrintOrRun obj prop flag;
  if (obj.#prop > 2) return RunRoutines(obj,prop);
  if (obj.prop==NULL) rfalse;
  switch(metaclass(obj.prop))
  {   Class, Object, nothing: return RunTimeError(2,obj,prop);
      String: print (string) obj.prop; if (flag==0) new_line; rtrue;
      Routine: return RunRoutines(obj,prop);
  }
];

[ ValueOrRun obj prop;
  if (obj.prop < 256) return obj.prop;
  return RunRoutines(obj, prop);
];

[ RunRoutines obj prop;
   if (obj == thedark
       && prop ~= initial or short_name or description) obj=real_location;
   if (obj.&prop == 0) rfalse;
   return obj.prop();
];

[ ChangeDefault prop val a b;
   ! Use assembly-language here because -S compilation won't allow this:
   @loadw 0 5 -> a;
   b = prop-1;
   @storew a b val;
];

! ----------------------------------------------------------------------------

[ StartTimer obj timer i;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i==obj) rfalse;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i==0) jump FoundTSlot;
   i=active_timers++;
   if (i >= MAX_TIMERS) { RunTimeError(4); return; }
   .FoundTSlot;
   if (obj.&time_left==0) { RunTimeError(5,obj); return; }
   the_timers-->i=obj; obj.time_left=timer;
];

[ StopTimer obj i;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i==obj) jump FoundTSlot2;
   rfalse;
   .FoundTSlot2;
   if (obj.&time_left==0) { RunTimeError(5,obj); return; }
   the_timers-->i=0; obj.time_left=0;
];

[ StartDaemon obj i;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i == $8000 + obj)
           rfalse;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i==0) jump FoundTSlot3;
   i=active_timers++;
   if (i >= MAX_TIMERS) RunTimeError(4);
   .FoundTSlot3;
   the_timers-->i = $8000 + obj;
];

[ StopDaemon obj i;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i == $8000 + obj) jump FoundTSlot4;
   rfalse;
   .FoundTSlot4;
   the_timers-->i=0;
];

! ----------------------------------------------------------------------------

[ DisplayStatus;
   if (the_time==NULL)
   {   sline1=score; sline2=turns; }
   else
   {   sline1=the_time/60; sline2=the_time%60; }
];

[ SetTime t s;
   the_time=t; time_rate=s; time_step=0;
   if (s<0) time_step=0-s;
];

[ NotifyTheScore;
   print "^[";  L__M(##Miscellany, 50, score-last_score);  print ".]^";
];

! ----------------------------------------------------------------------------

[ AdjustLight flag i;
   i=lightflag;
   lightflag=OffersLight(parent(player));

   if (i==0 && lightflag==1)
   {   location=real_location; if (flag==0) <Look>;
   }

   if (i==1 && lightflag==0)
   {   real_location=location; location=thedark;
       if (flag==0) { NoteArrival();
                      return L__M(##Miscellany, 9); }
   }
   if (i==0 && lightflag==0) location=thedark;
];

[ OffersLight i j;
   if (i==0) rfalse;
   if (i has light) rtrue;
   objectloop (j in i)
       if (HasLightSource(j)==1) rtrue;
   if (i has container)
   {   if (i has open || i has transparent)
           return OffersLight(parent(i));
   }
   else
   {   if (i has enterable || i has transparent || i has supporter)
           return OffersLight(parent(i));
   }
   rfalse;
];

[ HidesLightSource obj;
    if (obj == player) rfalse;
    if (obj has transparent or supporter) rfalse;
    if (obj has container) return obj hasnt open;
    return obj hasnt enterable;
];

[ HasLightSource i j ad;
   if (i==0) rfalse;
   if (i has light) rtrue;
   if (i has enterable || IsSeeThrough(i)==1)
       if (~~(HidesLightSource(i)))
           objectloop (j in i)
               if (HasLightSource(j)==1) rtrue;
   ad = i.&add_to_scope;
   if (parent(i)~=0 && ad ~= 0)
   {   if (metaclass(ad-->0) == Routine)
       {   ats_hls = 0; ats_flag = 1;
           RunRoutines(i, add_to_scope);
           ats_flag = 0; if (ats_hls == 1) rtrue;
       }
       else
       {   for (j=0:(2*j)<i.#add_to_scope:j++)
               if (HasLightSource(ad-->j)==1) rtrue;
       }
   }
   rfalse;
];

[ ChangePlayer obj flag i;
!  if (obj.&number==0) return RunTimeError(7,obj);
  if (actor==player) actor=obj;
  give player ~transparent ~concealed;
  i=obj; while(parent(i)~=0) { if (i has animate) give i transparent;
                               i=parent(i); }
  if (player==selfobj) player.short_name=FORMER__TX;

  player=obj;

  if (player==selfobj) player.short_name=NULL;
  give player transparent concealed animate proper;
  i=player; while(parent(i)~=0) i=parent(i); location=i;
  real_location=location;
  MoveFloatingObjects();
  lightflag=OffersLight(parent(player));
  if (lightflag==0) location=thedark;
  print_player_flag=flag;
];

! ----------------------------------------------------------------------------

#IFDEF DEBUG;
[ DebugParameter w x n l;
  x=0-->4; x=x+(x->0)+1; l=x->0; n=(x+1)-->0; x=w-(x+3);
  print w;
  if (w>=1 && w<=top_object) print " (", (name) w, ")";
  if (x%l==0 && (x/l)<n) print " ('", (address) w, "')";
];
[ DebugAction a anames;
#iftrue Grammar__Version==1;
  if (a>=256) { print "<fake action ", a-256, ">"; return; }
#ifnot;
  if (a>=4096) { print "<fake action ", a-4096, ">"; return; }
#endif;
  anames = #identifiers_table;
  anames = anames + 2*(anames-->0) + 2*48;
  print (string) anames-->a;
];
[ DebugAttribute a anames;
  if (a<0 || a>=48) print "<invalid attribute ", a, ">";
  else
  {   anames = #identifiers_table; anames = anames + 2*(anames-->0);
      print (string) anames-->a;
  }
];
[ TraceAction source ar;
  if (source<2) print "[ Action ", (DebugAction) action;
  else
  {   if (ar==##Order)
          print "[ Order to ", (name) actor, ": ", (DebugAction) action;
      else
          print "[ Life rule ", (DebugAction) ar;
  }
  if (noun~=0)   print " with noun ", (DebugParameter) noun;
  if (second~=0) print " and second ", (DebugParameter) second;
  if (source==0) print " ";
  if (source==1) print " (from < > statement) ";
  print "]^";
];
[ DebugToken token;
  AnalyseToken(token);
  switch(found_ttype)
  {   ILLEGAL_TT: print "<illegal token number ", token, ">";
      ELEMENTARY_TT:
      switch(found_tdata)
      {   NOUN_TOKEN:        print "noun";
          HELD_TOKEN:        print "held";
          MULTI_TOKEN:       print "multi";
          MULTIHELD_TOKEN:   print "multiheld";
          MULTIEXCEPT_TOKEN: print "multiexcept";
          MULTIINSIDE_TOKEN: print "multiinside";
          CREATURE_TOKEN:    print "creature";
          SPECIAL_TOKEN:     print "special";
          NUMBER_TOKEN:      print "number";
          TOPIC_TOKEN:       print "topic";
          ENDIT_TOKEN:       print "END";
      }
      PREPOSITION_TT:
          print "'", (address) found_tdata, "'";
      ROUTINE_FILTER_TT:
      #ifdef INFIX; print "noun=", (InfixPrintPA) found_tdata;
      #ifnot; print "noun=Routine(", found_tdata, ")"; #endif;
      ATTR_FILTER_TT:
          print (DebugAttribute) found_tdata;
      SCOPE_TT:
      #ifdef INFIX; print "scope=", (InfixPrintPA) found_tdata;
      #ifnot; print "scope=Routine(", found_tdata, ")"; #endif;
      GPR_TT:
      #ifdef INFIX; print (InfixPrintPA) found_tdata;
      #ifnot; print "Routine(", found_tdata, ")"; #endif;
  }
];
[ DebugGrammarLine pcount;
  print " * ";
  for (:line_token-->pcount ~= ENDIT_TOKEN:pcount++)
  {   if ((line_token-->pcount)->0 & $10) print "/ ";
      print (DebugToken) line_token-->pcount, " ";
  }
  print "-> ", (DebugAction) action_to_be;
  if (action_reversed) print " reverse";
];
[ ShowVerbSub address lines da meta i j;
    if (((noun->#dict_par1) & 1) == 0)
      "Try typing ~showverb~ and then the name of a verb.";
    meta=((noun->#dict_par1) & 2)/2;
    i = $ff-(noun->#dict_par2);
    address = (0-->7)-->i;
    lines = address->0;
    address++;
    print "Verb ";
    if (meta) print "meta ";
    da = 0-->4;
    for (j=0:j < (da+5)-->0:j++)
        if (da->(j*9 + 14) == $ff-i)
            print "'", (address) (da + 9*j + 7), "' ";
    new_line;
    if (lines == 0) "has no grammar lines.";
    for (:lines > 0:lines--)
    {   address = UnpackGrammarLine(address);
        print "    "; DebugGrammarLine(); new_line;
    }
];
[ ShowobjSub c f l a n x;
   if (noun==0) noun=location;
   objectloop (c ofclass Class) if (noun ofclass c) { f++; l=c; }
   if (f == 1) print (name) l, " ~"; else print "Object ~";
   print (name) noun, "~ (", noun, ")";
   if (parent(noun)~=0) print " in ~", (name) parent(noun), "~";
   new_line;
   if (f > 1)
   {   print "  class ";
       objectloop (c ofclass Class) if (noun ofclass c) print (name) c, " ";
       new_line;
   }
   for (a=0,f=0:a<48:a++) if (noun has a) f=1;
   if (f)
   {   print "  has ";
       for (a=0:a<48:a++) if (noun has a) print (DebugAttribute) a, " ";
       new_line;
   }
   if (noun ofclass Class) return;

   f=0; l = #identifiers_table-->0;
   for (a=1:a<=l:a++)
   {   if ((a~=2 or 3) && noun.&a)
       {   if (f==0) { print "  with "; f=1; }
           print (property) a;
           n = noun.#a;
           for (c=0:2*c<n:c++)
           {   print " ";
               x = (noun.&a)-->c;
               if (a==name) print "'", (address) x, "'";
               else
               {   if (a==number or capacity or time_left)
                       print x;
                   else
                   {   switch(x)
                       {   NULL: print "NULL";
                           0: print "0";
                           1: print "1";
                           default:
                           switch(metaclass(x))
                           {   Class, Object: print (name) x;
                               String: print "~", (string) x, "~";
                               Routine: print "[...]";
                           }
                           print " (", x, ")";
                       }
                   }
               }
           }
           print ",^       ";
       }
   }
!   if (f==1) new_line;
];
#ENDIF;

! ----------------------------------------------------------------------------
!  Except in Version 3, the DrawStatusLine routine does just that: this is
!  provided explicitly so that it can be Replace'd to change the style, and
!  as written it emulates the ordinary Standard game status line, which is
!  drawn in hardware
! ----------------------------------------------------------------------------

#IFV5;
[ DrawStatusLine width posa posb;
   @split_window 1; @set_window 1; @set_cursor 1 1; style reverse;
   width = 0->33; posa = width-26; posb = width-13;
   spaces width;
   @set_cursor 1 2;
   if (location == thedark) print (name) location;
   else
   {   FindVisibilityLevels();
       if (visibility_ceiling == location)
           print (name) location;
       else print (The) visibility_ceiling;
   }
   if ((0->1)&2 == 0)
   {   if (width > 76)
       {   @set_cursor 1 posa; print (string) SCORE__TX, sline1;
           @set_cursor 1 posb; print (string) MOVES__TX, sline2;
       }
       if (width > 63 && width <= 76)
       {   @set_cursor 1 posb; print sline1, "/", sline2;
       }
   }
   else
   {   @set_cursor 1 posa;
       print (string) TIME__TX;
       LanguageTimeOfDay(sline1, sline2);
   }
   @set_cursor 1 1; style roman; @set_window 0;
];
#ENDIF;

#ifv5;
Array StorageForShortName --> 161;
#endif;

[ PrefaceByArticle o acode pluralise  i artform findout;

   if (o provides articles)
   {   print (string) (o.&articles)-->(acode+short_name_case*LanguageCases),
           " ";
       if (pluralise) return;
       print (PSN__) o; return;
   }

   i = GetGNAOfObject(o);
   if (pluralise)
   {   if (i<3 || (i>=6 && i<9)) i = i + 3;
   }
   i = LanguageGNAsToArticles-->i;

   artform = LanguageArticles
             + 6*LanguageContractionForms*(short_name_case + i*LanguageCases);

#iftrue LanguageContractionForms == 2;
   if (artform-->acode ~= artform-->(acode+3)) findout = true;
#endif;
#iftrue LanguageContractionForms == 3;
   if (artform-->acode ~= artform-->(acode+3)) findout = true;
   if (artform-->(acode+3) ~= artform-->(acode+6)) findout = true;
#endif;
#iftrue LanguageContractionForms == 4;
   if (artform-->acode ~= artform-->(acode+3)) findout = true;
   if (artform-->(acode+3) ~= artform-->(acode+6)) findout = true;
   if (artform-->(acode+6) ~= artform-->(acode+9)) findout = true;
#endif;
#iftrue LanguageContractionForms > 4;
   findout = true;
#endif;
   if (standard_interpreter ~= 0 && findout)
   {   StorageForShortName-->0 = 160;
       @output_stream 3 StorageForShortName;
       if (pluralise) print (number) pluralise; else print (PSN__) o;
       @output_stream -3;
       acode = acode + 3*LanguageContraction(StorageForShortName + 2);
   }

   print (string) artform-->acode;
   if (pluralise) return;
   print (PSN__) o;
];

[ PSN__ o;
   if (o==0) { print (string) NOTHING__TX; rtrue; }
   switch(metaclass(o))
   {   Routine: print "<routine ", o, ">"; rtrue;
       String:  print "<string ~", (string) o, "~>"; rtrue;
       nothing: print "<illegal object number ", o, ">"; rtrue;
   }
   if (o==player) { print (string) YOURSELF__TX; rtrue; }
   #ifdef LanguagePrintShortName;
   if (LanguagePrintShortName(o)) rtrue;
   #endif;
   if (indef_mode && o.&short_name_indef~=0
       && PrintOrRun(o, short_name_indef, 1)~=0) rtrue;
   if (o.&short_name~=0 && PrintOrRun(o,short_name,1)~=0) rtrue;
   @print_obj o;
];

[ Indefart o i;
   i = indef_mode; indef_mode = true;
   if (o has proper) { indef_mode = NULL; print (PSN__) o; return; }
   if (o provides article)
   {   PrintOrRun(o,article,1); print " ", (PSN__) o; indef_mode = i; return;
   }
   PrefaceByArticle(o, 2); indef_mode = i;
];
[ Defart o i;
   i = indef_mode; indef_mode = false;
   if (o has proper)
   { indef_mode = NULL; print (PSN__) o; indef_mode = i; return; }
   PrefaceByArticle(o, 1); indef_mode = i;
];
[ CDefart o i;
   i = indef_mode; indef_mode = false;
   if (o has proper)
   { indef_mode = NULL; print (PSN__) o; indef_mode = i; return; }
   PrefaceByArticle(o, 0); indef_mode = i;
];

[ PrintShortName o i;
   i = indef_mode; indef_mode = NULL;
   PSN__(o); indef_mode = i;
];

[ EnglishNumber n; LanguageNumber(n); ];

[ NumberWord o i n;
  n = LanguageNumbers-->0;
  for (i=1:i<=n:i=i+2)
      if (o == LanguageNumbers-->i)
          return LanguageNumbers-->(i+1);
  return 0;
];

[ RandomEntry tab;
  if (tab-->0==0) return RunTimeError(8);
  return tab-->(random(tab-->0));
];

! ----------------------------------------------------------------------------
!  Useful routine: unsigned comparison (for addresses in Z-machine)
!    Returns 1 if x>y, 0 if x=y, -1 if x<y
! ----------------------------------------------------------------------------

[ UnsignedCompare x y u v;
  if (x==y) return 0;
  if (x<0 && y>=0) return 1;
  if (x>=0 && y<0) return -1;
  u = x&$7fff; v= y&$7fff;
  if (u>v) return 1;
  return -1;
];

! ----------------------------------------------------------------------------
