! ====================================
! Z-Test
! Z-Machine standards compliance test
! Written by Andrew Hunter
! Miscellaneous strange tests
! ====================================

Constant maxUndo = 4000;

Test oddTests "Miscellaneous tests"
    with
    Run [ x y;
	print "Undo: ";
	for (x=0: x<maxUndo: x++)
	{
	    @save_undo -> y;
	    if (y == -1)
		jump noUndo;
	    if (y == 0)
		jump undoFailed;
	    if (y == 2)
		jump undoRestored;
	    if (y ~= 1)
	    {
		print "Bad save value^";
		rfalse;
	    }
	}

	@read_char 1 -> x;
	
	.undoRestored;
	print "x ";
	@restore_undo -> y;

	if (x == 0)
	    print ">=", maxUndo, " levels of undo supported^";
	else
	 print maxUndo-x, " levels of undo supported^";

	jump undone;

	.noUndo;
	print "Not supported^";
	jump undone;

	.undoFailed;
	print "Failed^";
	rfalse;

	.undone;

	rtrue;
    ];

