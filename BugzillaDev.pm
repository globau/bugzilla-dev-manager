package BugzillaDev;

use strict;

use Cwd qw(getcwd abs_path);
use File::Basename;
BEGIN {
    push @INC, abs_path(dirname(__FILE__));
}
use BugzillaDevConfig;
use XMLRPC::Lite;
use HTTP::Cookies;
use Term::ANSIColor 'colored';
use DBI;
use DBD::mysql;
use File::Slurp;
use Term::ReadKey;
use Time::HiRes 'usleep';
use Socket;

$| = 1;

our (@ISA, @EXPORT);
BEGIN {
    require Exporter;
    @ISA = 'Exporter';
    @EXPORT = qw(
        initHandlers
        info dieInfo alert confirm prompt
        getBmoProxy soapErrChk
        dirToBugID
        getBugSummary
        getDirSummary setDirSummary
        getDirData setDirData
        pushd popd
        getDbh databaseExists
        trim
    );
}

sub initHandlers {
    $SIG{__DIE__} = sub { die _coloured("@_", 'red') . "\n" };
    $SIG{__WARN__} = sub { print _coloured("@_", 'yellow') . "\n" };
}
initHandlers();

my $USER_PATH = "~/.bz-dev";
$USER_PATH =~ s{^~([^/]*)}{$1 ? (getpwnam($1))[7] : (getpwuid($<))[7]}e;
mkdir($USER_PATH) unless -d $USER_PATH;

sub _coloured {
    # $message, $colour
    if (-t STDOUT) {
        return colored(@_);
    } else {
        return shift;
    }
}

sub getBmoProxy {
    my $host = shift || 'bugzilla.mozilla.org';
    gethostbyname($host) || return;

    my $cookie_jar = HTTP::Cookies->new(file => "$USER_PATH/cookies.txt", autosave => 1);
    my $proxy = XMLRPC::Lite->proxy(
        "https://$host/xmlrpc.cgi",
        'cookie_jar' => $cookie_jar,
    );
    my $response;

    my ($user, $pass) = ('', '');
    if (open(FH, "$USER_PATH/authentication.txt")) {
        $user = <FH>;
        $pass = <FH>;
        $user =~ s/[\r\n]+$//;
        $pass =~ s/[\r\n]+$//;
    }
    if ($user && $pass) {
        $response = $proxy->call(
            'User.login',
            {
                login => $user,
                password => $pass,
                remember => 1,
            }
        );
        soapErrChk($response);
    }

    return $proxy;
}

sub soapErrChk {
    my $soapresult = shift;
    if ($soapresult->fault) {
        my ($package, $filename, $line) = caller;
        die $soapresult->faultcode . ' ' . $soapresult->faultstring .
            " in SOAP call near $filename line $line.\n";
    }
}

sub getBugSummary {
    my ($id) = @_;
    my $proxy = getBmoProxy() || return '';
    my $response = $proxy->call(
        'Bug.get',
        {
            ids => [ $id ],
            include_fields => [ 'id', 'summary' ],
        }
    );
    soapErrChk($response);
    my $rh = shift @{$response->result->{bugs}};
    return $rh->{summary};
}

sub getDirSummary {
    my ($dir, $cache_only) = @_;
    my $id = dirToBugID($dir)
        or return '';
    my $value = getDirData($dir, 'summary');
    return $value if $value ne '';
    return '' if $cache_only;
    my $summary = getBugSummary($id);
    setDirData($dir, 'summary', $summary);
    return $summary;
}

sub setDirSummary {
    my ($dir, $summary) = @_;
    setDirData($dir, 'summary', $summary);
}

sub setDirData {
    my ($dir, $name, $value) = @_;
    my $file = getDirDataFile($dir, $name)
        or return;
    my $path = dirname($file);
    mkdir($path) unless -d $path;
    write_file($file, $value);
    system qq#chgrp apache "$file" 2>/dev/null#;
    system qq#chmod g+rw "$file" 2>/dev/null#;
    return 1;
}

sub getDirData {
    my ($dir, $name) = @_;
    my $file = getDirDataFile($dir, $name);
    return '' unless $file && -e $file;
    return read_file($file, err_mode => 'quiet') || '';
}

sub getDirDataFile {
    my ($dir, $name) = @_;
    return if $dir eq '' || $dir =~ /(?:\.\.|\||\/|\~)/;
    return if $name eq '' || $name =~ /(?:\.\.|\||\/|\~)/;
    return "$HTDOCS_PATH/$dir/data/$name";
}
 

{
    my %dbh;

    sub getDbh {
        my ($subdir) = @_;

        my @localconfig = read_file("$HTDOCS_PATH/$subdir/localconfig");
        my %config;
        foreach my $line (@localconfig) {
            next unless $line =~ /^\s*\$db_([a-z]+)\s*=\s*'([^']+)'/;
            $config{$1} = $2;
        }

        my $name = $config{name};
        if (!exists $dbh{$name}) {
            $dbh{$name} = DBI->connect(
                "DBI:mysql:database=$config{name};host=$config{host};port=$config{port}",
                $config{user}, $config{pass},
                { mysql_enable_utf8 => 1, mysql_auto_reconnect => 1, },
            );
            exit unless $dbh{$name};
            $dbh{$name}->do('SET NAMES utf8');
        }
        return $dbh{$name};
    }
}

sub databaseExists {
    my ($name, %config) = @_;
    my $dbh = DBI->connect(
        "DBI:mysql:database=$name;host=$config{db_host};port=$config{port}",
        $config{db_user}, $config{db_pass},
        { RaiseError => 0, PrintError => 0 }
    );
    return $dbh ? 1 : 0;
}

{
    my @push_paths;

    sub pushd {
        my ($path) = @_;
        push @push_paths, abs_path(getcwd());
        chdir($path) or die "cd '$path': $!\n";
    }

    sub popd {
        my $path = pop @push_paths;
        chdir($path) or die "cd '$path': $!\n";
    }
}

sub info {
    print STDERR _coloured("@_", 'green') . "\n";
}

sub alert {
    print STDERR _coloured("@_", 'red') . "\n";
}

sub dieInfo {
    info(@_);
    exit;
}

sub confirm {
    return lc(prompt(shift, qr/[yn]/i)) eq 'y' ? 1 : 0;
}

sub prompt {
    my ($prompt, $valid_re) = @_;
    $prompt = '?' unless $prompt;
    $prompt =~ s/\s+$//;
    $valid_re = qr/./ unless $valid_re;
    print chr(7), _coloured("$prompt ", 'yellow');
    my $start_time = (time);
    my $key;
    ReadMode(4);
    END { ReadMode(0) }
    do {
        while (not defined ($key = ReadKey(-1))) {
            if ((time) - $start_time > 10) {
                my @message = split /\000/, read_file('/proc/self/cmdline');
                shift @message;     # perl
                $message[0] = 'bz'; # script
                my $message = join(' ', @message);
                GROWL("($message) needs your attention");
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

sub dirToBugID {
    my ($dir) = @_;
    if ($dir =~ /^\d+$/) {
        return $dir;
    }
    if ($dir =~ /^(\d+)-/) {
        return $1;
    }
    return 0;
}

sub trim {
    my $value = shift;
    $value =~ s/(^\s+|\s+$)//g;
    return $value;
}

1;

