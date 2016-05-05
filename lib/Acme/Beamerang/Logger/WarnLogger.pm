use 5.006;    # our
use strict;
use warnings;

package Acme::Beamerang::Logger::WarnLogger;

our $VERSION = '0.001000';

# ABSTRACT: A modernish default lightweight logger

# AUTHORITY

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
#
# Also, this class intentionally nuked all "custom levels" support to keep the complexity
# and to avoid AUTOLOAD shenianigans.

use strict;
use warnings;
use Carp qw( croak );

use Term::ANSIColor qw( colored );
{
    no strict 'refs';
    delete ${ __PACKAGE__ . q[::] }{$_}
      for qw( croak colored );    # namespace clean
}
my ( @levels, %level_num, %level_labels );

BEGIN {
    @levels = qw( trace debug info warn error fatal );
    @level_num{@levels} = ( 0 .. $#levels );
    my %level_colors = (
        trace => [],
        debug => ['blue'],
        info  => ['white'],
        warn  => ['yellow'],
        error => ['magenta'],
        fatal => ['red'],
    );
    for my $level (@levels) {
        $level_labels{$level} = sprintf "%-5s", $level;
        if ( exists $level_colors{$level} and @{ $level_colors{$level} || [] } )
        {
            $level_labels{$level} =
              colored( $level_colors{$level}, $level_labels{$level} );
        }
    }
}

sub new {
    my ( $class, $args ) = @_;

    my $self = bless {}, $class;

    $self->{env_prefix} = $args->{env_prefix}
      or die 'no env_prefix passed to ' . __PACKAGE__ . '->new';

    for my $field (qw( group_env_prefix default_upto label )) {
        $self->{$field} = $args->{$field} if exists $args->{$field};
    }
    return $self;
}

sub _log {
    my $self    = shift;
    my $level   = shift;
    my $message = join( "\n", @_ );
    $message .= qq[\n] unless $message =~ /\n\z/;
    my $label = $level_labels{$level};

    $label .= ' ' . $self->{label} if $self->{label};
    warn "[${label}] $message";
}

_gen_level($_) for (@levels);

sub _gen_level_sub {
    my ( $level, $is_name ) = @_;
    return sub {
        my $self = shift;
        $self->_log( $level, @_ ) if $self->$is_name;
    };
}

sub _gen_is_level_sub {
    my ($level) = @_;
    my $ulevel = '_' . uc $level;
    return sub {
        my $self = shift;

        my ( $ep, $gp ) = @{$self}{qw( env_prefix group_env_prefix )};

        my ( $ep_level, $ep_upto ) = ( $ep . $ulevel, $ep . '_UPTO' );

        my ( $gp_level, $gp_upto ) = ( $gp . $ulevel, $gp . '_UPTO' )
          if defined $gp;

        # Explicit true/false takes precedence
        return !!$ENV{$ep_level} if defined $ENV{$ep_level};

        # Explicit true/false takes precedence
        return !!$ENV{$gp_level} if $gp_level and defined $ENV{$gp_level};

        my $upto;

        if ( defined $ENV{$ep_upto} ) {
            $upto = lc $ENV{$ep_upto};
            croak "Unrecognized log level '$upto' in \$ENV{$ep_upto}"
              if not defined $level_num{$upto};
        }
        elsif ( $gp_upto and defined $ENV{$gp_upto} ) {
            $upto = lc $ENV{$gp_upto};
            croak "Unrecognized log level '$upto' in \$ENV{$gp_upto}"
              if not defined $level_num{$upto};
        }
        elsif ( exists $self->{default_upto} ) {
            $upto = $self->{default_upto};
        }
        else {
            return 0;
        }
        return $level_num{$level} >= $level_num{$upto};
    };
}

# Once an XS Sub namer is used once, always use the same one
# the idea being if Sub::Util is loaded first, and we name some
# subs with it, Sub::Name being loaded later won't make the subs get
# named with a different implementation. ( Because they implement it differently )
{
    my $sub_name_impl;

    sub _name_sub {
        return $sub_name_impl->(@_) if $sub_name_impl;
        if ( $INC{'Sub/Name.pm'} ) {
            $sub_name_impl = Sub::Name->can('subname');
            return $sub_name_impl->(@_);
        }
        if ( $INC{'Sub/Util.pm'} ) {
            $sub_name_impl = Sub::Util->can('set_subname');
            return $sub_name_impl->(@_);
        }
        return;
    }
}
sub _gen_level {
    my ($level) = @_;
    my $is_name = "is_$level";

    my $level_sub = _gen_level_sub( $level, $is_name );
    my $is_level_sub = _gen_is_level_sub($level);

    _name_sub( "$level",   $level_sub );
    _name_sub( "$is_name", $is_level_sub );

    no strict 'refs';
    *{$level}   = $level_sub;
    *{$is_name} = $is_level_sub;
}
1;

