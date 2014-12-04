! ----------------------------------------------------------------------------
!  LINKLPA:  Link declarations of common properties and attributes.
!
!  Supplied for use with Inform 6                         Serial number 991113
!                                                                 Release 6/10
!  (c) Graham Nelson 1993, 1994, 1995, 1996, 1997, 1998, 1999
!      but freely usable (see manuals)
! ----------------------------------------------------------------------------

System_file;

Attribute animate;
Ifdef USE_MODULES;
   Iffalse (animate==0);
   Message error "Please move your Attribute declarations after the
                  Include ~Parser~ line: otherwise it will be impossible
                  to USE_MODULES";
   Endif;
Endif;
Attribute absent;
Attribute clothing;
Attribute concealed;
Attribute container;
Attribute door;
Attribute edible;
Attribute enterable;
Attribute general;
Attribute light;
Attribute lockable;
Attribute locked;
Attribute moved;
Attribute on;
Attribute open;
Attribute openable;
Attribute proper;
Attribute scenery;
Attribute scored;
Attribute static;
Attribute supporter;
Attribute switchable;
Attribute talkable;
Attribute transparent;
Attribute visited;
Attribute workflag;
Attribute worn;

Attribute male;
Attribute female;
Attribute neuter;
Attribute pluralname;

Property additive before $ffff;
Ifdef USE_MODULES;
   Iffalse before==4;
   Message error "Please move your Property declarations after the
                  Include ~Parser~ line: otherwise it will be impossible
                  to USE_MODULES";
   Endif;
Endif;
Property additive after  $ffff;
Property additive life   $ffff;

Property n_to;  Property s_to;
Property e_to;  Property w_to;
Property ne_to; Property se_to;
Property nw_to; Property sw_to;
Property u_to;  Property d_to;
Property in_to; Property out_to;

Property door_to;
Property with_key;
Property door_dir;
Property invent;
Property plural;
Property add_to_scope;
Property list_together;
Property react_before;
Property react_after;
Property grammar;
Property additive orders;

Property initial;
Property when_open;
Property when_closed;
Property when_on;
Property when_off;
Property description;
Property additive describe $ffff;
Property article "a";

Property cant_go;

Property found_in;         !  For fiddly reasons this can't alias

Property time_left;
Property number;
Property additive time_out $ffff;
Property daemon;
Property additive each_turn $ffff;

Property capacity 100;

Property short_name 0;
Property short_name_indef 0;
Property parse_name 0;

Property articles;
Property inside_description;
