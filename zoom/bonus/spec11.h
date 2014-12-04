! ====================================
! Z-Test
! Z-Machine standards compliance test
! Written by Andrew Hunter
! Specification 1.1 tests
! ====================================

Array buf -> 40;

Test saveTest "1.1 File handling test"
    with     data 1 2 3 4,
    newdata 0 0 0 0,
    Run [ x y z res;
	if (standard_interpreter < $101)
	{
	    print "(Your interpreter is not standard 1.1)^";
	    return -1;
	}
	
	print "Save/restore test (no prompt)...";
	buf->0 = 40;
	@output_stream 3 buf;
	print "blarfle.file";
	@output_stream -3;
	
	print "Writing ", self.#data, " bytes to
	    blarfle.file...";
	
	x = self.&data;
	y = self.#data;
	z = buf + 1;
	
	@"EXT:0S" x y z 0 -> res;
	
	if (res == self.#data)
	{
	    x = self.&newdata;
	    @"EXT:1S" x y z 0 -> res;
	    if (res ~= self.#data)
	    {
		print "Failed: only read ", res, " bytes on restore^";
		rfalse;
	    }

	    for (x=0: x<self.#data: x++)
	    {
		if ((self.&newdata)->x ~= (self.&data)->x)
		{
		    print "Failed: byte ", x, " did not match on
			restore (read ", (self.&newdata)->x, " but
			wrote ", (self.&data)->x, ")^";
		    rfalse;
		}
	    }

	    print "OK^";
	    
	    print "This time, a prompt should be shown (load the blarfle.file we just saved, if possible):^";
	    x = self.&newdata;
	    @"EXT:1S" x y z 1 -> res;
	    if (res > 0)
	    {
	    	if (res ~= self.#data)
	    	{
		    print "Failed: only read ", res, " bytes on restore^";
		    rfalse;
	    	}
   		
	    	for (x=0: x<self.#data: x++)
	    	{
		    if ((self.&newdata)->x ~= (self.&data)->x)
		    {
		    	print "Failed: byte ", x, " did not match on
			    restore (read ", (self.&newdata)->x, " but
			    wrote ", (self.&data)->x, ")^";
		    	rfalse;
		    }
		}
	    }
	    else
	    {
		print "File not found^";
	    }

	    print "OK^";
	}
	else
	{
	    print "Failed to write file^";
	}
	
	rtrue;
    ];

Test uniTest "1.1 Unicode"
    with
    japanese $14D8 $88A5 $D15F $98D3 $75D1, ! Note: the standard got
                                            ! the encoding wrong.
    zork1 $13F4 $5E05 $9B00 $DEDD,
    zork2 $13F4 $5CA6 $E010 $DEDD,
    zork3 $13F4 $14D8 $82F0 $DEDD,
    beyondzork $13E5 $1B00 $DEDD $D2F0,
    Run [ x;
	if (standard_interpreter < $101)
	{
	    print "(Your interpreter is not standard 1.1)^";
	    return -1;
	}
	
	print "This will attempt to display some Unicode
	    strings (the examples from the specification). You'll
	    have to verify for yourself if they're correct^";
	print "The strings will be:^";
	print "~Japanese~ in Japanese^";
	print "Zork<TM>^";
	print "Zor<TM>k^";
	print "Zo<TM>rk^";
	print "Z<TM>ork^";
	print "(Characters may be missing from your font: this is
	    not an interpreter bug)^^";

	x = self.&japanese; @print_addr x; new_line;
	x = self.&zork1; @print_addr x; new_line;
	x = self.&zork2; @print_addr x; new_line;
	x = self.&zork3; @print_addr x; new_line;
	x = self.&beyondzork; @print_addr x; new_line;

	rtrue;
    ];

Test miscTest "1.1 miscellany"
    with Run [ x pass;
	     if (standard_interpreter < $101)
	     {
	    	 print "(Your interpreter is not standard 1.1)^";
	    	 return -1;
	     }

	     pass = 1;

	     print "get_prop_len 0...";
	     @get_prop_len 0 -> x;
	     if (x == 0)
	     {
		 print "OK^";
	     }
	     else
	     {
		 print "Failed (read ", x, ")^";
		 pass = 0;
	     }

	     print "Multiple text styles: ";
	     @set_text_style 6;
	     print "Bold-Italic...";
	     @set_text_style -6;
	     print "Normal^";

	     print "Sound_data: ";
	     @"EXT:14B" 7 abuf ?feep;
	     print "Sound 7 non-existant^";
	     jump foop;

	     .feep;
	     print "Sound 7 exists^";

	     .foop;
	     
	     return pass;
	 ];
