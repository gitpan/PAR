# $File: //member/autrijus/.vimrc $ $Author: autrijus $
# $Revision: #14 $ $Change: 4137 $ $DateTime: 2003/02/08 11:41:59 $

my ($parl_exe, $par_exe, $dynperl) = @ARGV;
exit unless $dynperl;

local $/;
open _FH, $par_exe or die $!;
binmode _FH;
my $input_exe = <_FH>;
close _FH;
open _FH, $parl_exe or die $!;
binmode _FH;
my $output_exe = <_FH>;
close _FH;
my $offset = index($output_exe, $input_exe);
open _FH, '>>', $parl_exe or die $!;
binmode _FH;
print _FH pack('N', $offset);
close _FH;
