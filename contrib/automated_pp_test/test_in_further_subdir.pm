#!/usr/bin/perl -w
# $File: /depot/local/PAR/trunk/contrib/automated_pp_test/test_in_further_subdir.pm $ $Author: autrijus $
# $Revision: #3 $ $Change: 11731 $ $DateTime: 2004/05/01 12:21:
########################################################################
# Copyright 2004 by Malcolm Nooning
# This program does not impose any
# licensing restrictions on files generated by their execution, in
# accordance with the 8th article of the Artistic License:
#
#    "Aggregation of this Package with a commercial distribution is
#    always permitted provided that the use of this Package is embedded;
#    that is, when no overt attempt is made to make this Package's
#    interfaces visible to the end user of the commercial distribution.
#    Such use shall not be construed as a distribution of this Package."
#
# Therefore, you are absolutely free to place any license on the resulting
# executable(s), as long as the packed 3rd-party libraries are also available
# under the Artistic License.
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
# See L<http://www.perl.com/perl/misc/Artistic.html>
#
## 
########################################################################
our $VERSION = 0.01;

########################################################################

my $TRUE = 1;
my $FALSE = 0;

#########################################################################

########################################################################
# Usage:
# $error = 
#    test_in_further_subdir(
#                    $test_number,
#                    $sub_test,
#                    $test_name_string,
#                    $test_dir, 
#                    $further_subdir,  # e.g. $SUBDIR1, 2, 3 or 4
#                    $command_string,  # e.g. "pp -I", or maybe empty ""
#                    $executable_name, # e.g. $a_default_executable
#                    $expected_result, # e.g. "hello"
#                    $os, 
#                    $verbose,
#                    \$message,
#                          );
#
# $error will be one of POSIX (EXIT_SUCCESS EXIT_FAILURE)
# 
########################################################################
# Outline
# -------
# . Copy the executable to a different subdirectory
# . chdir to the new subdirectory
# . Pipe executable and collect the result.
# . Compare the result with the expected result.
# . Report back success or failure.
########################################################################
# 
package test_in_further_subdir;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = ("test_in_further_subdir");

use POSIX qw(EXIT_SUCCESS EXIT_FAILURE);
use File::Copy;
use Cwd qw(chdir);

use pipe_a_command;

use strict;

########################################################################
sub test_in_further_subdir {
  my (
       $test_number,
       $sub_test,
       $test_name_string,
       $test_dir, 
       $further_subdir,
       $command_string,
       $executable_name,
       $expected_result, 
       $os, 
       $verbose,
       $message_ref,
       $print_cannot_locate_message,
     ) = @_;

  my $final_subdir = "";
  my $final_executable = "";
  my $results_copied = "";
  my $error = EXIT_FAILURE;

  #.................................................................
  # Copy created executable to a different directory and make sure
  # it executes from there.
  $final_subdir = $test_dir . "/$further_subdir";
  $final_executable = $final_subdir . "/$executable_name";

  if(!(copy("$executable_name", "$final_executable"))) {
      $$message_ref = "\n\[300\]sub $test_name_string: " .
                  "cannot copy $executable_name to $final_subdir\n";
      return (EXIT_FAILURE);
  }

  #.................................................................
  $error = pipe_a_command(
                           $test_number,
                           $sub_test,
                           $test_name_string,
                           $final_subdir, 
                           $command_string,
                           $executable_name,
                           $expected_result,
                           $os, 
                           $verbose,
                           $message_ref,
                           $print_cannot_locate_message,
                        );

  #.................................................................
  return ($error);
  #.................................................................
}
