! ====================================
! Z-Test
! Z-Machine standards compliance test
! Written by Andrew Hunter
! Mathematical tests
! ====================================

Test randomNess "Random Number Generator test"
    with
    Run [ x y nits it avg dev mindev maxdev;
	for (x=0: x<256: x++)
	{
	    abuf-->x = 0;
	}

	! Reseed... should expose the worst in most RNGs
	@random -80 -> x;

	it = 0;
	nits = 16;

	while (it < 8192)
	{
	    for (x=0: x<nits: x++)
	    {
		@random 125 -> y;
		y--;

		if (y < 0 ||
		    y >= 125)
		{
		    print "Out of range random number ", y+1, "
			generated (range 1-125)^";
		    rfalse;
		}
		
		(abuf-->y)++;
	    	it++;
	    }

	    nits = nits*3;

	    print "After ", it, " iterations:^";

	    avg = it/125;
	    maxdev = 0;
	    mindev = 0;
	    y = 0;
	    for (x=0: x<125: x++)
	    {
		dev = avg-(abuf-->x);

		if (dev < mindev)
		    mindev = dev;
		if (dev > maxdev)
		    maxdev = dev;
		
		if (dev < 0)
		    dev = -dev;
		y = y + dev;
	    }

	    y = y / 125;

	    ! FIXME: add some more statistics. The problem with the
	    ! test as it now stands is that an RNG that just produces
	    ! incrementing numbers would give good-looking results...
	    print "  + Mean deviation ", y, "^";
	    print "  + Deviation range ", mindev, " - ", maxdev, "^";
	}

	rtrue;
    ];

! Well, some logical operators, too
Test someMath "Mathematical operator test"
    with
    Run [ x y z pass;
	pass = 1;
	
	z = -1;
	for (x=0: x<16: x++)
	{
	    @art_shift -1 x -> y;
	    if (y ~= z)
	    {
		print "Arithmetic shift ", x, " failed (expected ", z,
		    " but got ", y, ")^";
		pass = 0;
	    }
	    @log_shift -1 x -> y;
	    if (y ~= z)
	    {
		print "Logical shift ", x, " failed (expected ", z,
		    " but got ", y, ")^";
		pass = 0;
	    }
	    z = z*2;
	}
	
	z = -32768;
	for (x=0: x>-16: x--)
	{
	    @art_shift -32768 x -> y;
	    if (y ~= z)
	    {
		print "Arithmetic shift ", x, " failed (expected ", z,
		    " but got ", y, ")^";
		pass = 0;
	    }
	    z = z/2;
	}

	z = $4088;
	for (x=-1: x>-16: x--)
	{
	    @log_shift $8111 x -> y;
	    if (y ~= z)
	    {
		print "Logical shift ", x, ", failed (expected ", z, "
		    but got ", y, ")^";
		pass = 0;
	    }

	    z = z/2;
	}

	@div 32767 14 -> y;
	if (y ~= 2340)
	{
	    print "Division failed^";
	    pass = 0;
	}
	@mod 32767 14 -> y;
	if (y ~= 7)
	{
	    print "Modulo failed^";
	}

	return pass;
    ];
