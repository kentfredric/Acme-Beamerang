use 5.006;    # our
use strict;
use warnings;

package Acme::Beamerang::Logger;

our $VERSION = '0.001000';

# ABSTRACT: A simple logging container for Beamerang Things

# AUTHORITY

use parent 'Log::Contextual';

# This class provides a few patterns not in the Log::Contextual::Easy::Default
# and Log::Contextual::WarnLogger features.
#
# 1. Has a shared prefix for all compontents that use it, which is used
#    when the per-package prefix is omitted. This is mostly just to simplify "All on"
#    and "All off" behaviours will still allowing fine-grained control for precision tracing.
#
# 2. Has a "default" upto level of "warn", so that warn levels and higher can be used like
#    normal warnings and be user visible.
#
# 3. Has a "logger label" which provides a compacted module name that is infix-compacted
#    to 21 characters to make flow more obvious in conjunction with the "shared prefix"
#    option.
#
# 4. Has ANSI Color tinting of log messages for easy skimming, which incidentally makes any app
#    that uses this look much more modern.
#
# The biggest downside of doing this has been the details are so specific that I had to
#    rewrite all the existing logic to support it :/

sub _elipsis {
    my ($module) = @_;
    return sprintf "%21s", $module if ( length $module ) <= 21;
    $module =~ /\A(.{10}).*(.{10})\z/;
    return sprintf "%s…%s", $1, $2;
}

sub arg_default_logger {
    if ( $_[1] ) {
        return $_[1];
    }
    else {
        require Acme::Beamerang::Logger::WarnLogger;
        my $caller  = caller(3);
        my $package = uc($caller);
        $package =~ s/::/_/g;
        return Acme::Beamerang::Logger::WarnLogger->new(
            {
                env_prefix       => $package,
                group_env_prefix => 'BEAMERANG',
                label            => _elipsis($caller),
                default_upto     => 'warn',
            }
        );
    }
}

sub default_import { qw(:dlog :log ) }

1;

