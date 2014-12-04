! ----------------------------------------------------------------------------
!  PARSER:  Front end to parser.
!
!  Supplied for use with Inform 6
!
!  (c) Graham Nelson 1993, 1994, 1995, 1996, 1997, 1998, 1999
!      but freely usable (see manuals)
! ----------------------------------------------------------------------------
System_file;
IFDEF INFIX; IFNDEF DEBUG; Constant DEBUG; ENDIF; ENDIF;
IFDEF STRICT_MODE; IFNDEF DEBUG; Constant DEBUG; ENDIF; ENDIF;
Constant LibSerial  = "991113";
Constant LibRelease = "6/10";
Constant Grammar__Version = 2;
IFNDEF VN_1610;
Message fatalerror "*** Library 6/10 needs Inform v6.10 or later to work ***";
ENDIF;
Include "linklpa";
Fake_Action LetGo;
Fake_Action Receive;
Fake_Action ThrownAt;
Fake_Action Order;
Fake_Action TheSame;
Fake_Action PluralFound;
Fake_Action ListMiscellany;
Fake_Action Miscellany;
Fake_Action Prompt;
Fake_Action NotUnderstood;
IFDEF NO_PLACES;
Fake_Action Places;
Fake_Action Objects;
ENDIF;
[ Main; InformLibrary.play(); ];
IFDEF USE_MODULES;
Link "parserm";
IFNOT;
Include "parserm";
ENDIF;
