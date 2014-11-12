package Bz::Util;
use Bz;

use base 'Exporter';
our @EXPORT = qw(
    message
    info
    dieInfo
    warning
    alert

    silent

    confirm
    prompt
    get_text
    password

    notify

    coloured
    die_coloured
    warn_coloured

    sudo_on_output

    vers_cmp
);

use File::Slurp 'read_file';
use IPC::System::Simple 'runx';
use Term::ANSIColor 'colored';
use Term::ReadKey qw(ReadMode ReadKey);
use Time::HiRes 'usleep';

sub coloured {
    # $message, $colour
    return -t STDOUT ? colored(@_) : shift;
}

my $_show_messages = 1;

sub message {
    return unless $_show_messages;
    print STDERR "@_\n";
}

sub info {
    print STDERR coloured("@_", 'green') . "\n";
}

sub warning {
    print STDERR coloured("@_", 'blue') . "\n";
}

sub alert {
    print STDERR coloured("@_", 'red') . "\n";
}

sub silent(&) {
    my ($sub) = @_;
    $_show_messages = 0;
    &$sub();
    $_show_messages = 1;
}

sub confirm {
    return (prompt(shift, 'yn') || '') eq 'y' ? 1 : 0;
}

sub prompt {
    my ($prompt, $options) = @_;
    $prompt = '?' unless $prompt;
    $prompt =~ s/\s+$//;
    my $valid_re = $options
        ? qr/[$options]/i
        : qr/./;
    print chr(7), coloured("$prompt ", 'yellow');
    my $start_time = (time);
    my $key;
    ReadMode(4);
    END { ReadMode(0) }
    do {
        while (not defined ($key = ReadKey(-1))) {
            if ((time) - $start_time > 10) {
                notify("needs your attention");
                $start_time = (time);
            }
            usleep(250);
        }
        if (ord($key) == 3 || ord($key) == 27) {
            print "^C\n";
            return undef;
        }
    } until $key =~ $valid_re;
    ReadMode(0);
    print "$key\n";
    return lc($key);
}

sub get_text {
    my ($prompt, $is_password) = @_;

    print chr(7), coloured("$prompt ", 'yellow');
    my $response = '';
    my $key;
    ReadMode(4);
    END { ReadMode 0 }
    while(1) {
        1 while (not defined ($key = ReadKey(-1)));
        if (ord($key) == 3 || ord($key) == 27) {
            print "^C\n";
            exit;
        }
        last if $key =~ /[\r\n]/;
        if ($key =~ /[\b\x7F]/) {
            next if $response eq '';
            chop $response;
            print "\b \b";
            next;
        }
        if ($key eq "\025") {
            my $len = length($response);
            print(("\b" x $len) . (" " x $len) . ("\b" x $len));
            $response = '';
            next;
        }
        next if ord($key) < 32;
        $response .= $key;
        print $is_password ? '*' : $key;
    }
    ReadMode(0);
    print "\n";
    return $response;
}

sub password {
    return get_text(shift, 1);
}

sub notify {
    my $message = shift;

    my @title = split /\000/, read_file('/proc/self/cmdline');
    shift @title;     # perl
    $title[0] = 'bz'; # script
    my $title = join(' ', @title);

    # terminal-notifier
    $title =~ s/"/\\"/g;
    $title =~ s/[\r\n]+/ /g;
    $message =~ s/"/\\"/g;
    $message =~ s/[\r\n]+/ /g;
    my $remote_command =
        '/usr/local/bin/terminal-notifier ' .
        '-sound Pop ' .
        '-activate com.googlecode.iterm2 ' .
        qq#-title "$title" # .
        qq#-message "$message" #;
    runx('ssh', 'byron@mac', $remote_command);
}

sub dieInfo {
    info(@_);
    exit;
}

sub die_coloured {
    return coloured("@_", 'red');
}

sub warn_coloured {
    return coloured("@_", 'yellow');
}

sub sudo_on_output {
    my ($command) = @_;
    my $output = `$command 2>&1`;
    if ($output) {
        message("escalating $command");
        system "sudo $command";
    }
}

sub vers_cmp {
    my ($a, $b) = @_;

    $a =~ s/^0*(\d.+)/$1/;
    $b =~ s/^0*(\d.+)/$1/;

    my @A = ($a =~ /([-.]|\d+|[^-.\d]+)/g);
    my @B = ($b =~ /([-.]|\d+|[^-.\d]+)/g);

    my ($A, $B);
    while (@A and @B) {
        $A = shift @A;
        $B = shift @B;
        if ($A eq '-' and $B eq '-') {
            next;
        } elsif ( $A eq '-' ) {
            return -1;
        } elsif ( $B eq '-') {
            return 1;
        } elsif ($A eq '.' and $B eq '.') {
            next;
        } elsif ( $A eq '.' ) {
            return -1;
        } elsif ( $B eq '.' ) {
            return 1;
        } elsif ($A =~ /^\d+$/ and $B =~ /^\d+$/) {
            if ($A =~ /^0/ || $B =~ /^0/) {
                return $A cmp $B if $A cmp $B;
            } else {
                return $A <=> $B if $A <=> $B;
            }
        } else {
            $A = uc $A;
            $B = uc $B;
            return $A cmp $B if $A cmp $B;
        }
    }
    @A <=> @B;
}

1;
