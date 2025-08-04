#!/usr/bin/perl -t

# safe-rm - https://launchpad.net/safe-rm
# prevention of accidental deletions using a directory blacklist
#
# Copyright (C) 2008-2014  Francois Marier <francois@fmarier.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use warnings;
use strict;
use Cwd 'realpath';

our $VERSION = '0.12';

my $homedir            = $ENV{HOME} || q{};
my $LEGACY_CONFIG_FILE = "$homedir/.safe-rm";
my $USER_CONFIG_FILE   = ($ENV{XDG_CONFIG_HOME} || "$homedir/.config") . "/safe-rm";
my $GLOBAL_CONFIG_FILE = '/etc/safe-rm.conf';

my %default_protected_dirs = (
    '/bin'               => 1,
    '/boot'              => 1,
    '/dev'               => 1,
    '/etc'               => 1,
    '/home'              => 1,
    '/initrd'            => 1,
    '/lib'               => 1,
    '/lib32'             => 1,
    '/lib64'             => 1,
    '/proc'              => 1,
    '/root'              => 1,
    '/sbin'              => 1,
    '/sys'               => 1,
    '/usr'               => 1,
    '/usr/bin'           => 1,
    '/usr/include'       => 1,
    '/usr/lib'           => 1,
    '/usr/local'         => 1,
    '/usr/local/bin'     => 1,
    '/usr/local/include' => 1,
    '/usr/local/sbin'    => 1,
    '/usr/local/share'   => 1,
    '/usr/sbin'          => 1,
    '/usr/share'         => 1,
    '/usr/src'           => 1,
    '/var'               => 1,
);

my %protected_dirs = ();

sub read_config_file {
    my $filename = shift;

    if ( -e $filename ) {
        if ( open my $fh, '<', $filename ) {
            while (<$fh>) {
                chomp;
                foreach my $file (glob) {
                    $protected_dirs{$file} = 1;
                }
            }
            close $fh;    # deliberatly ignore errors
        }
        else {
            print {*STDERR} "Could not open configuration file: $filename\n";
        }
    }

    return;
}

read_config_file($GLOBAL_CONFIG_FILE);
read_config_file($LEGACY_CONFIG_FILE);
read_config_file($USER_CONFIG_FILE);

if ( 0 == scalar keys %protected_dirs ) {
    %protected_dirs = %default_protected_dirs;
}

my @allowed_args = ();
foreach (@ARGV) {
    my $pathname = $_;

    # Normalize the pathname
    my $normalized_pathname = $pathname;
    if ( $normalized_pathname =~ m{/}xms or -e "$normalized_pathname" ) {

        # Convert to an absolute path (e.g. remove "..")
        $normalized_pathname = realpath($normalized_pathname);
        if ( !$normalized_pathname ) {
            $normalized_pathname = $pathname;
        }
    }
    if ( $normalized_pathname =~ m{^(.+?)/+$}xms ) {

        # Trim trailing slashes
        $normalized_pathname = $1;
    }

    # Check against the blacklist
    if ( exists $protected_dirs{$normalized_pathname} and not -l $pathname ) {
        print {*STDERR} "safe-rm: skipping $pathname\n" || 0;
    }
    elsif ( $pathname =~ /(.*)/xms ) {    # pointless untainting
        push @allowed_args, $1;
    }
}

# Prepare for actually deleting the file
local $ENV{PATH} = q{};                   # pointless untainting
local $ENV{CDPATH} = q{};                 # pointless untainting
local $ENV{IFS} = " \t\n";                # pointless untainting
my $real_rm = '/bin/rm';

# Make sure we're not calling ourselves recursively
if ( realpath($real_rm) eq realpath($0) ) {
    die 'safe-rm cannot find the real "rm" binary' . "\n";
}

# Run the real rm command, returning with the same error code
my $status = system $real_rm, @allowed_args;
my $errcode = $status >> 8;
exit $errcode;

__END__

=head1 NAME

safe-rm - wrapper around the rm command to prevent accidental deletions

=head1 USAGE

safe-rm [ ... ]
(same arguments as rm)

=head1 DESCRIPTION

safe-rm prevents the accidental deletion of important files by
replacing rm with a wrapper which checks the given arguments against a
configurable blacklist of files and directories which should never be
removed.

Users who attempt to delete one of these protected files or
directories will not be able to do so and will be shown a warning
message instead.

safe-rm is meant to replace the rm command so you can achieve this by
putting a symbolic link with the name "rm" in a directory which sits
at the front of your path. For example, given this path:

  PATH=/usr/local/bin:/bin:/usr/bin

You could create the following symbolic link:

  ln -s /usr/local/bin/safe-rm /usr/local/bin/rm

=head1 CONFIGURATION

Protected paths can be set both at the site and user levels.

Both of these configuration files can contain a list of important files
or directories (one per line):

  /etc/safe-rm.conf
  ~/.config/safe-rm

If both of these are empty, a default list of important paths will be
used.

=for stopword Wildcards
Wildcards are allowed in the configuration files, but be careful

  /usr/lib/*

will protect all of the files inside the /usr/lib directory if they are referred to directly, but it will not protect your system against:

  rm -rf /usr/lib

For a full protection, you should include both of these lines:

  /usr/lib
  /usr/lib/*

=head1 EXIT STATUS

Same exit status as the real rm command.

Note that if all file arguments are skipped by safe-rm then the exit status
will be the same as the exit status of the real rm when no files arguments
are present.

=head1 BUGS AND LIMITATIONS

Note that if you put the following in your protected paths list:

  $ cat /etc/safe-rm.conf
  /usr/lib

Then safe-rm will prevent you from deleting the directory:

  $ rm -rf /usr/lib
  Skipping /usr/lib
  /bin/rm: missing operand
  Try `/bin/rm --help' for more information.

However it cannot protect you from the following:

  $ cd /usr/lib
  $ rm -f *

=head1 AUTHOR

Francois Marier <francois@fmarier.org>

=head1 SEE ALSO

rm(1)

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008-2014 Francois Marier

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
