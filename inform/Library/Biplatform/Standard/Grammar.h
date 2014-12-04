! ----------------------------------------------------------------------------
!  GRAMMAR:  Grammar table entries for the standard verbs library.
!
!  Supplied for use with Inform 6                         Serial number 991113
!                                                                 Release 6/10
!  (c) Graham Nelson 1993, 1994, 1995, 1996, 1997, 1998, 1999
!      but freely usable (see manuals)
! ----------------------------------------------------------------------------
!  The "meta-verbs", commands to the game rather than in the game, come first:
! ----------------------------------------------------------------------------

System_file;

Verb meta 'score'
                *                                -> Score;
Verb meta 'fullscore' 'full'
                *                                -> FullScore
                * 'score'                        -> FullScore;
Verb meta 'q//' 'quit' 'die'
                *                                -> Quit;
Verb meta 'restore'
                *                                -> Restore;
Verb meta 'restart'
                *                                -> Restart;
Verb meta 'verify'
                *                                -> Verify;
Verb meta 'save'
                *                                -> Save;
Verb meta 'script' 'transcript'
                *                                -> ScriptOn
                * 'off'                          -> ScriptOff
                * 'on'                           -> ScriptOn;
Verb meta 'noscript' 'unscript'
                *                                -> ScriptOff;
Verb meta 'superbrief' 'short'
                *                                -> LMode3;
Verb meta 'verbose' 'long'
                *                                -> LMode2;
Verb meta 'brief' 'normal'
                *                                -> LMode1;
Verb meta 'pronouns' 'nouns'
                *                                -> Pronouns;
Verb meta 'notify'
                * 'on'                           -> NotifyOn
                * 'off'                          -> NotifyOff;
Verb meta 'version'
                *                                -> Version;
#IFNDEF NO_PLACES;
Verb meta 'places'
                *                                -> Places;
Verb meta 'objects'
                *                                -> Objects;
#ENDIF;

! ----------------------------------------------------------------------------
!  Debugging grammar
! ----------------------------------------------------------------------------

#ifdef DEBUG;
Verb meta 'trace'
                *                                -> TraceOn
                * number                         -> TraceLevel
                * 'on'                           -> TraceOn
                * 'off'                          -> TraceOff;
Verb meta 'actions'
                *                                -> ActionsOn
                * 'on'                           -> ActionsOn
                * 'off'                          -> ActionsOff;
Verb meta 'routines' 'messages'
                *                                -> RoutinesOn
                * 'on'                           -> RoutinesOn
                * 'off'                          -> RoutinesOff;
Verb meta 'timers' 'daemons'
                *                                -> TimersOn
                * 'on'                           -> TimersOn
                * 'off'                          -> TimersOff;
Verb meta 'changes'
                *                                -> ChangesOn
                * 'on'                           -> ChangesOn
                * 'off'                          -> ChangesOff;
Verb meta 'recording'
                *                                -> CommandsOn
                * 'on'                           -> CommandsOn
                * 'off'                          -> CommandsOff;
Verb meta 'replay'
                *                                -> CommandsRead;
Verb meta 'random'
                *                                -> Predictable;
Verb meta 'purloin'
                * multi                          -> XPurloin;
Verb meta 'abstract'
                * noun 'to' noun                 -> XAbstract;
Verb meta 'tree'
                *                                -> XTree
                * noun                           -> XTree;
Verb meta 'goto'
                * number                         -> Goto;
Verb meta 'gonear'
                * noun                           -> Gonear;
Verb meta 'scope'
                *                                -> Scope
                * noun                           -> Scope;
Verb meta 'showverb'
                * special                        -> Showverb;
Verb meta 'showobj'
                *                                -> Showobj
                * multi                          -> Showobj;
#endif;

! ----------------------------------------------------------------------------
!  And now the game verbs.
! ----------------------------------------------------------------------------

Verb 'take' 'carry' 'hold'
                * multi                          -> Take
                * 'off' worn                     -> Disrobe
                * multiinside 'from' noun        -> Remove
                * multiinside 'off' noun         -> Remove
                * 'inventory'                    -> Inv;
Verb 'get'      * 'out'/'off'/'up'               -> Exit
                * multi                          -> Take
                * 'in'/'into'/'on'/'onto' noun   -> Enter
                * 'off' noun                     -> GetOff
                * multiinside 'from' noun        -> Remove;
Verb 'pick'
                * 'up' multi                     -> Take
                * multi 'up'                     -> Take;
Verb 'stand'
                *                                -> Exit
                * 'up'                           -> Exit
                * 'on' noun                      -> Enter;
Verb 'remove'
                * held                           -> Disrobe
                * multi                          -> Take
                * multiinside 'from' noun        -> Remove;
Verb 'shed' 'doff' 'disrobe'
                * held                           -> Disrobe; 
Verb 'wear' 'don'
                * held                           -> Wear;
Verb 'put'
                * multiexcept 'in'/'inside'/'into' noun
                                                 -> Insert
                * multiexcept 'on'/'onto' noun   -> PutOn
                * 'on' held                      -> Wear
                * 'down' multiheld               -> Drop
                * multiheld 'down'               -> Drop;
Verb 'insert'
                * multiexcept 'in'/'into' noun   -> Insert;
Verb 'empty'
                * noun                           -> Empty
                * 'out' noun                     -> Empty
                * noun 'out'                     -> Empty
                * noun 'to'/'into'/'on'/'onto' noun
                                                 -> EmptyT;
Verb 'transfer'
                * noun 'to' noun                 -> Transfer;
Verb 'drop' 'throw' 'discard'
                * multiheld                      -> Drop
                * multiexcept 'in'/'into'/'down' noun
                                                 -> Insert
                * multiexcept 'on'/'onto' noun   -> PutOn
                * held 'at'/'against'/'on'/'onto' noun
                                                 -> ThrowAt;
Verb 'give' 'pay' 'offer' 'feed'
                * held 'to' creature             -> Give
                * creature held                  -> Give reverse
                * 'over' held 'to' creature      -> Give;
Verb 'show' 'present' 'display'
                * creature held                  -> Show reverse
                * held 'to' creature             -> Show;
[ ADirection; if (noun in compass) rtrue; rfalse; ];
Verb 'go' 'walk' 'run'
                *                                -> VagueGo
                * noun=ADirection                -> Go
                * noun                           -> Enter
                * 'into'/'in'/'inside'/'through' noun
                                                 -> Enter;
Verb 'leave'
                *                                -> VagueGo
                * noun=ADirection                -> Go
                * noun                           -> Exit
                * 'into'/'in'/'inside'/'through' noun
                                                 -> Enter;
Verb 'inventory' 'inv' 'i//'
                *                                -> Inv
                * 'tall'                         -> InvTall
                * 'wide'                         -> InvWide;
Verb 'look' 'l//'
                *                                -> Look
                * 'at' noun                      -> Examine
                * 'inside'/'in'/'into'/'through' noun
                                                 -> Search
                * 'under' noun                   -> LookUnder
                * 'up' topic 'in' noun           -> Consult;
Verb 'consult'  * noun 'about' topic             -> Consult
                * noun 'on' topic                -> Consult;
Verb 'open' 'unwrap' 'uncover' 'undo'
                * noun                           -> Open
                * noun 'with' held               -> Unlock;
Verb 'close' 'shut' 'cover'
                * noun                           -> Close
                * 'up' noun                      -> Close
                * 'off' noun                     -> SwitchOff;
Verb 'enter' 'cross'
                *                                -> GoIn
                * noun                           -> Enter;
Verb 'sit' 'lie'
                * 'on' 'top' 'of' noun           -> Enter
                * 'on'/'in'/'inside' noun        -> Enter;
Verb 'in' 'inside'
                *                                -> GoIn;
Verb 'exit' 'out' 'outside'
                *                                -> Exit;
Verb 'examine' 'x//' 'watch' 'describe' 'check'
                * noun                           -> Examine;
Verb 'read'
                * noun                           -> Examine
                * 'about' topic 'in' noun        -> Consult
                * topic 'in' noun                -> Consult;
Verb 'yes' 'y//'
                *                                -> Yes;
Verb 'no'
                *                                -> No;
Verb 'sorry'
                *                                -> Sorry;
Verb 'shit' 'fuck' 'damn' 'sod'
                *                                -> Strong
                * topic                          -> Strong;
Verb 'bother' 'curses' 'drat' 'darn'
                *                                -> Mild
                * topic                          -> Mild;
Verb 'search'
                * noun                           -> Search;
Verb 'wave'
                *                                -> WaveHands
                * noun                           -> Wave;
Verb 'set' 'adjust'
                * noun                           -> Set
                * noun 'to' special              -> SetTo;
Verb 'pull' 'drag'
                * noun                           -> Pull;
Verb 'push' 'move' 'shift' 'clear' 'press'
                * noun                           -> Push
                * noun noun                      -> PushDir
                * noun 'to' noun                 -> Transfer;
Verb 'turn' 'rotate' 'twist' 'unscrew' 'screw'
                * noun                           -> Turn
                * noun 'on'                      -> Switchon
                * noun 'off'                     -> Switchoff
                * 'on' noun                      -> Switchon
                * 'off' noun                     -> Switchoff;
Verb 'switch'
                * noun                           -> Switchon
                * noun 'on'                      -> Switchon
                * noun 'off'                     -> Switchoff
                * 'on' noun                      -> Switchon
                * 'off' noun                     -> Switchoff;
Verb 'lock'
                * noun 'with' held               -> Lock;
Verb 'unlock'
                * noun 'with' held               -> Unlock;
Verb 'attack' 'break' 'smash' 'hit' 'fight' 'wreck' 'crack'
     'destroy' 'murder' 'kill' 'torture' 'punch' 'thump'
                * noun                           -> Attack;
Verb 'wait' 'z//'
                *                                -> Wait;
Verb 'answer' 'say' 'shout' 'speak'
                * topic 'to' creature            -> Answer;
Verb 'tell'
                * creature 'about' topic         -> Tell;
Verb 'ask'
                * creature 'about' topic         -> Ask
                * creature 'for' noun            -> AskFor;
Verb 'eat'
                * held                           -> Eat;
Verb 'sleep' 'nap'
                *                                -> Sleep;
Verb 'peel'
                * noun                           -> Take
                * 'off' noun                     -> Take;
Verb 'sing'
                *                                -> Sing;
Verb 'climb' 'scale'
                * noun                           -> Climb
                * 'up'/'over' noun               -> Climb;
Verb 'buy' 'purchase'
                * noun                           -> Buy;
Verb 'squeeze' 'squash'
                * noun                           -> Squeeze;
Verb 'swim' 'dive'
                *                                -> Swim;
Verb 'swing'
                * noun                           -> Swing
                * 'on' noun                      -> Swing;
Verb 'blow'
                * held                           -> Blow;
Verb 'pray'
                *                                -> Pray;
Verb 'wake' 'awake' 'awaken'
                *                                -> Wake
                * 'up'                           -> Wake
                * creature                       -> WakeOther
                * creature 'up'                  -> WakeOther
                * 'up' creature                  -> WakeOther;
Verb 'kiss' 'embrace' 'hug'
                * creature                       -> Kiss;
Verb 'think'
                *                                -> Think;
Verb 'smell' 'sniff'
                *                                -> Smell
                * noun                           -> Smell;
Verb 'hear' 'listen'
                *                                -> Listen
                * noun                           -> Listen
                * 'to' noun                      -> Listen;
Verb 'taste'
                * noun                           -> Taste;
Verb 'touch' 'fondle' 'feel' 'grope'
                * noun                           -> Touch;
Verb 'rub' 'shine' 'polish' 'sweep' 'clean' 'dust' 'wipe' 'scrub'
                * noun                           -> Rub;
Verb 'tie' 'attach' 'fasten' 'fix'
                * noun                           -> Tie
                * noun 'to' noun                 -> Tie;
Verb 'burn' 'light'
                * noun                           -> Burn
                * noun 'with' held               -> Burn;
Verb 'drink' 'swallow' 'sip'
                * noun                           -> Drink;
Verb 'fill'
                * noun                           -> Fill;
Verb 'cut' 'slice' 'prune' 'chop'
                * noun                           -> Cut;
Verb 'jump' 'skip' 'hop'
                *                                -> Jump
                * 'over' noun                    -> JumpOver;
Verb 'dig'      * noun                           -> Dig
                * noun 'with' held               -> Dig;
! ----------------------------------------------------------------------------
!  This routine is no longer used here, but provided to help existing games
!  which use it as a general parsing routine:

[ ConTopic w; consult_from = wn;
  do w=NextWordStopped();
  until (w==-1 || (w=='to' && action_to_be==##Answer));
  wn--;
  consult_words = wn-consult_from;
  if (consult_words==0) return -1;
  if (action_to_be==##Ask or ##Answer or ##Tell)
  {   w=wn; wn=consult_from; parsed_number=NextWord();
      if (parsed_number=='the' && consult_words>1) parsed_number=NextWord();
      wn=w; return 1;
  }
  return 0;
];
! ----------------------------------------------------------------------------
!  Final task: provide trivial routines if the user hasn't already:
! ----------------------------------------------------------------------------
#Stub TimePasses      0;
#Stub Amusing         0;
#Stub DeathMessage    0;
#Stub DarkToDark      0;
#Stub NewRoom         0;
#Stub LookRoutine     0;
#Stub AfterLife       0;
#Stub GamePreRoutine  0;
#Stub GamePostRoutine 0;
#Stub AfterPrompt     0;
#Stub BeforeParsing   0;
#Stub PrintTaskName   1;
#Stub InScope         1;
#Stub UnknownVerb     1;
#Stub PrintVerb       1;
#Stub ParserError     1;
#Stub ParseNumber     2;
#Stub ChooseObjects   2;
#IFNDEF PrintRank;
Constant Make__PR;
#ENDIF;
#IFDEF Make__PR;
[ PrintRank; "."; ];
#ENDIF;
#IFNDEF ParseNoun;
Constant Make__PN;
#ENDIF;
#IFDEF Make__PN;
[ ParseNoun obj; obj=obj; return -1; ];
#ENDIF;
#Default Story 0;
#Default Headline 0;
#IFDEF INFIX;
#Include "infix";
#ENDIF;
! ----------------------------------------------------------------------------
