package Bz::Util;
use Bz;

use base 'Exporter';
our @EXPORT = qw(
    message
    info
    dieInfo
    warning
    alert

    disable_messages
    enable_messages

    confirm
    prompt
    get_text
    password

    notify

    coloured
    die_coloured
    warn_coloured

    sudo_on_output
);

use File::Slurp;
use IPC::System::Simple 'runx';
use Term::ANSIColor 'colored';
use Term::ReadKey;
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

sub disable_messages {
    $_show_messages = 0;
}

sub enable_messages {
    $_show_messages = 1;
}

sub confirm {
    return lc(prompt(shift, qr/[yn]/i)) eq 'y' ? 1 : 0;
}

sub prompt {
    my ($prompt, $valid_re) = @_;
    $prompt = '?' unless $prompt;
    $prompt =~ s/\s+$//;
    $valid_re = qr/./ unless $valid_re;
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
            exit;
        }
    } until $key =~ $valid_re;
    ReadMode(0);
    print "$key\n";
    return $key;
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

1;
