include "ir";
include "input";
include "check";
include "gen";

if (#argv != 1)
  err ("Usage: sas file");

get_ir (open (argv[0], "r"));
check ();
gen (re.sub (`^(.*/)?([^.]*)(\..*)?$`, argv[0], `\2`));
