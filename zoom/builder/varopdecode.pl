#!/usr/bin/perl -w

use strict;

#
# Outputs some specialised code for decoding varops
#

my $arguments=$ARGV[0];
my $funcname=$ARGV[1];

print "int zmachine_decode_$funcname(ZStack* stack, ZByte* param, ZArgblock* argblock)\n";
print "{\n";

my $firstarg = $arguments/4;

if ($arguments > 4)
  {
    print "  int padding = 0;\n";
  }

my $pos=0;
for (my $x=0; $x<($arguments/4); $x++, $pos++)
  {
    print "\n  switch (param\[$pos\])\n";
    print "    {\n";

    for (my $a=0; $a<=255; $a++)
      {
	my $c = chr($a);

	my @param = map vec($c, 3-$_, 2), (0..3);

	my $omit = 0;
	my $valid = grep 
	  {
	    $omit = 1 if ($_ == 3);
	    ($_ != 3 && $omit) && 1 or 0;
	  } @param;
	
	if ($valid == 0)
	  {
	    printf("    case 0x%02x: /* ", $a);
	
	    my $an = 1;
	    my $firstomit = 5;

	    foreach (@param)
	      {
		my $at;
		
		$at="LC"   if ($_ == 0);
		$at="SC"   if ($_ == 1);
		$at="Var"  if ($_ == 2);
		$at="Omit" if ($_ == 3);
		
		$firstomit=$an if ($firstomit==5 && $_==3);

		print "arg$an - $at ";
		$an++;
	      }
	    print "*/\n";

	    $firstomit--;

	    my $pos = $firstarg;

	    for (my $b=0; $b<4; $b++)
	      {
		printf("      argblock->arg[%i] = ", $b+$x*4);
		
		my $pad = "";
		$pad = "+padding" if ($x>0);
		
		if ($param[$b] == 0)
		  {
		    printf("(param[%i$pad]<<8)|param[%i$pad];\n", $pos, $pos+1);
		    $pos+=2;
		  }
		elsif($param[$b] == 1)
		  {
		    printf("param[%i$pad];\n", $pos);
		    $pos++;
		  }
		elsif($param[$b] == 2)
		  {
		    printf("GetVar(param[%i$pad]);\n", $pos);
		    $pos++;
		  }
		else
		  {
		    print "0;\n";
		  }
	      }
	    print "      argblock->arg[7] = 0;\n";
	    
	    if ($arguments > 4)
	      {
		printf("      padding = %i;\n", $pos-$firstarg) if ($x == 0);
		printf("      padding += %i;\n", $pos-$firstarg) if ($x>0);
	      }

	    if ($x == int($arguments/4)-1 || $firstomit != 4)
	      {
		printf("      argblock->n_args = %i;\n", $firstomit+($x*4));

		my $pad = "";
		$pad = "+padding" if ($x>0);
		printf("      return %i$pad;\n\n", $pos-1);
	      }
	    else
	      {
		print "      break;\n\n";
	      }
	  }
      }

    print "    default:\n";
    print "      zmachine_fatal(\"Illegal encoding of a VARop\");\n";
    print "      return 0;\n";
    print "    }\n";
  }

print "}\n"
