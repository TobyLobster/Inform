! ====================================
! Z-Test
! Z-Machine standards compliance test
! Written by Andrew Hunter
! Requires a v6 interpreter
! ====================================

Test colourTest "Version 6 colours test"
    with
    Run [ x c y;
	for (x=2: x<10: x++)
	{
	    y = 11-x;
	    @set_colour x y;
	    print "Colour ", x, "^";

	    @get_wind_prop -3 11 -> c;

	    if ((c&$ff) ~= x ||
		(c&$ff00) ~= (y*$100))
	    {
		@set_colour 1 1;

		print "Failed: ", x, " ", c&$ff, " ", c&$ff00, "^";
		rfalse;
	    }
	}

	if (standard_interpreter >= $101)
	{
	    for (x=0: x<$1f: x = x +2)
	    {
		y = $1f - x;		
		@"EXT:13" x y;
		print "Colour ", x, "^";

		@get_wind_prop -3 16 -> c;
		if (c ~= x)
		{
		    @set_colour 1 1 ;
		    print "Failed: ", c, " ", x, "^";
		}
		
		@get_wind_prop -3 17 -> c;
		if (c ~= y)
		{
		    @set_colour 1 1 ;
		    print "Failed: ", c, " ", x, "^";
		}
	    }
	    
	    @set_colour 1 1;
	    new_line;
	    
	    @set_colour 0 0;
	    @get_wind_prop -3 11 -> c;
	    print "Colours are: ", c, " ";
       	    @get_wind_prop -3 16 -> c;
	    print "True foreground: ", c;
	    @get_wind_prop -3 17 -> c;
	    print " True background: ", c;
	    new_line;
	    
	    @"EXT:13" $001f $1f00;
	    @erase_line 1;
	    @set_colour 2 2;
	    @"EXT:13" $fffd $fffd;
       	    @get_wind_prop -3 16 -> x;
       	    @get_wind_prop -3 17 -> y;
	    @set_colour 1 1;

	    if (y ~= $1f00)
	    {
		print "Failed: ", y, "^";
		rfalse;
	    }
	    if (x ~= $1f00)
	    {
		print "Failed: ", x, "^";
		rfalse;
	    }

	    @"EXT:13" $1f $fffc;
	    print "Transparent!^";
	}

	@set_colour 1 1;
	rtrue;
    ];

Test windowTest "V6 window test"
    with
    Run
	[;
	    @move_window 2 100 100;
	    @window_size 2 200 200;
	    @set_colour 5 3 2;
	    @erase_window 2;

	    @set_margins 20 20 2;
	    
	    @set_window 2;
	    @window_style 2 1 2;
	    print "Window 2 - this should not be wrapped to the
		margins, but it might be anyway, so ner^";
	    @set_window 0;

	    rtrue;
	];     

