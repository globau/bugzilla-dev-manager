#!/usr/bin/perl

use strict;

use lib '/opt/bugzilla/repo/git/bugzilla-dev-manager';

use constant SKIP_BUG_INFO => 0;

use BugzillaDev;
use BugzillaDevConfig;

use CGI;
use CGI::Carp 'fatalsToBrowser';
use File::Path 'remove_tree';
use File::Slurp;
use Template;

my $cgi = CGI->new();
my $proxy = getBmoProxy();

if ($cgi->param('dir')) {
    print "Content-type: text/plain\n\n";
    my $dir = scalar $cgi->param('dir');
    if ($cgi->param('delete')) {
        if (!-d $dir) {
            print "invalid dir: $dir\n";
        } else {
            remove_tree($dir, { safe => 1, error => \my $errors });
            if (@$errors) {
                print join("\n", @$errors);
            } else {
                print "ok\n";
            }
        }
    } else {
        print setDirData($dir, 'comment', scalar $cgi->param('comment')), "\n";
    }
    exit;
}

my $template = Template->new({
    ABSOLUTE => 1,
    STRICT => 1,
    PRE_CHOMP => 1,
    TRIM => 1,
    ENCODING => 'UTF-8',
    FILTERS => {
        nbsp => sub {
            my ($value) = @_;
            return $value eq '' ? '&nbsp;' : $value;
        },
        js => sub {
            my ($value) = @_;
            $value =~ s/([\\\'\"\/])/\\$1/g;
            $value =~ s/\n/\\n/g;
            $value =~ s/\r/\\r/g;
            $value =~ s/</\\x3c/g;
            $value =~ s/>/\\x3e/g;
            return $value;
        },
    },
});

my $vars = {};
$vars->{instances} = get_instances();

print $cgi->header();
$template->process("$DATA_PATH/index.tt2", $vars)
    or die($template->error() . "\n");

#

sub get_instances {
    # get directories, sort non-bugs first
    my @dirs =
        sort {
            my $a_bug = dirToBugID($a) ? 1 : 0;
            my $b_bug = dirToBugID($b) ? 1 : 0;
            return
                ($a_bug <=> $b_bug)
                or ($a cmp $b)
            ;
        }
        grep {
            -d $_
            && !-e "$_/.hidden"
            && -e "$_/localconfig"
        }
        glob("*");

    # init instances
    my $instances = [];
    foreach my $dir (@dirs) {
        my $id = dirToBugID($dir);
        push @$instances, {
            dir => $dir,
            id => $id,
            summary => getDirSummary($dir, 1),
            product => '',
            status => '',
            assigned_to => '',
            repo => getDirData($dir, 'repo-version'),
            comment => getDirData($dir, 'comment'),
            db => get_db($dir),
        }
    }

    return $instances if SKIP_BUG_INFO || !$proxy;

    # read bug info
    my $response = $proxy->call(
        'Bug.get',
        {
            ids => [ grep { $_ } map { $_->{id} } @$instances ],
            include_fields => [ 'id', 'summary', 'status', 'assigned_to', 'product' ],
        }
    );
    soapErrChk($response);

    # process response
    foreach my $rh (@{$response->result->{bugs}}) {
        my $id = $rh->{id};
        foreach my $instance (grep { $_->{id} == $id } @$instances) {
            foreach my $field (keys %$rh) {
                $instance->{$field} = $rh->{$field};
            }
            setDirSummary($instance->{dir}, $instance->{summary});

            # make assigned_to shorter
            my $assigned_to = $instance->{assigned_to};
            if ($assigned_to =~ /\@bugzilla\.bugs$/) {
                $assigned_to = '-';
            } else {
                $assigned_to =~ s/^([^@]+).+/$1/;
                $assigned_to = '-' if $assigned_to eq 'nobody';
            }
            $instance->{assigned_to} = $assigned_to;
        }
    }

    return $instances;
}

sub get_db {
    my $subdir = shift;
    open(FH, "$HTDOCS_PATH/$subdir/localconfig") or die "$subdir/localconfig: $!";
    my @file = <FH>;
    close FH;
    foreach my $line (@file) {
        next unless $line =~ /^\$db_name\s*=\s*'([^']+)'/;
        return $1;
    }
    return "unknown";
}

