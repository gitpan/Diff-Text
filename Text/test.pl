# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 3 };
use Diff::Text;
ok(1);
my $newdiff = text_diff("old.txt","new.txt",{plain=>1});
ok(1);

open (OLD_DIFF,"diff.t") or die $!;
my $olddiff = do { local $/; <OLD_DIFF>; };
close (OLD_DIFF);
ok(1) if ($newdiff eq $olddiff);
ok(0) if ($newdiff ne $olddiff);


