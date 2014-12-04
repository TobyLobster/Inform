! ----------------------------------------------------------------------------
!  VERBLIB:  Front end to standard verbs library.
!
!  Supplied for use with Inform 6                         Serial number 991113
!                                                                 Release 6/10
!  (c) Graham Nelson 1993, 1994, 1995, 1996, 1997, 1998, 1999
!      but freely usable (see manuals)
! ----------------------------------------------------------------------------
System_file;
Default MAX_CARRIED  100;
Default MAX_SCORE    0;
Default NUMBER_TASKS 1;
Default OBJECT_SCORE 4;
Default ROOM_SCORE   5;
Default SACK_OBJECT  0;   
Default AMUSING_PROVIDED 1;
Default TASKS_PROVIDED   1;
#IFNDEF task_scores; Constant MAKE__TS; #ENDIF;
#IFDEF MAKE__TS;
Array  task_scores --> 0 0;
#ENDIF;
Array  task_done --> NUMBER_TASKS;
#IFNDEF LibraryMessages;
Object LibraryMessages;
#ENDIF;
#IFNDEF NO_PLACES;
[ PlacesSub; Places1Sub(); ];
[ ObjectsSub; Objects1Sub(); ];
#ENDIF;
#IFDEF USE_MODULES;
Link "verblibm";
#IFNOT;
Include "verblibm";
#ENDIF;
