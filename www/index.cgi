#!/usr/bin/env perl
use strict;
$| = 1;

BEGIN {
    # read the bz_path from the conf
    use File::Slurp;
    my $bz_path;
    foreach (read_file('/etc/bz-dev.conf')) {
        s/#.*$//;
        s/(^\s+|\s+$)//g;
        next unless /^bz_path\s*=\s*"([^"]+)"$/;
        $bz_path = $1;
        last;
    }
    push @INC, $bz_path;
}

use Bz;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use Template;

$SIG{__DIE__} = \&CGI::Carp::confess;

use constant USE_MULTIPART => 1;

my $cgi = CGI->new();
if ($cgi->param('delete') && $cgi->param('dir')) {
    print $cgi->header(-type => 'text/plain');
    my $workdir = Bz->workdir($cgi->param('dir'));
    $workdir->delete();
    print "deleted\n";
    exit;
}

my $template = Template->new({
    ABSOLUTE    => 1,
    STRICT      => 1,
    PRE_CHOMP   => 1,
    TRIM        => 1,
    ENCODING    => 'UTF-8',
    FILTERS => {
        js => sub {
            my ($value) = @_;
            $value =~ s/([\\\'\"\/])/\\$1/g;
            $value =~ s/\n/\\n/g;
            $value =~ s/\r/\\r/g;
            $value =~ s/</\\x3c/g;
            $value =~ s/>/\\x3e/g;
            return $value;
        },
        product => sub {
            my ($value) = @_;
            return 'bugzilla' if $value eq 'Bugzilla';
            return 'bmo' if $value eq 'bugzilla.mozilla.org';
            return $value;
        },
        assignee => sub {
            my ($value) = @_;
            return '-' if $value =~ /\@bugzilla\.bugs$/;
            $value =~ s/^([^@]+).+/$1/;
            return '-' if $value eq 'nobody';
            return $value;
        },
    },
});

if (USE_MULTIPART) {
    print $cgi->multipart_init();
    print $cgi->multipart_start(-type => 'text/html; charset=UTF-8');
    print <<'EOF';
<!doctype html>
<html>
<head>
<title>bugzilla-dev</title>
<style>
body {
    font-family: "Helvetica Neue", "Nimbus Sans L", Arial, sans-serif;
    font-size: small;
    color: #888;
}
</style>
</head>
<body>
loading...
</body>
</html>
EOF
    print $cgi->multipart_end();
} else {
    print $cgi->header(-type => 'text/html; charset=UTF-8');
}

my $workdirs = Bz->workdirs;
my %ids = map { $_ => $_->bug_id ? $_->bug_id : 0 } @$workdirs;
Bz->preload_bugs($workdirs);
$workdirs = [
    sort {
        $ids{$a} <=> $ids{$b} || $a->dir cmp $b->dir
    } @$workdirs
];

if (USE_MULTIPART) {
    print $cgi->multipart_start(-type => 'text/html; charset=UTF-8');
}

$template->process(\*DATA, { workdirs => $workdirs })
    or die($template->error() . "\n");

if (USE_MULTIPART) {
    print $cgi->multipart_final();
}

__DATA__
<!doctype html>
<html>
<head>
<title>bugzilla-dev</title>
<style>

body {
    font-family: "Helvetica Neue", "Nimbus Sans L", Arial, sans-serif;
}

#bug {
    position: fixed;
    top: 0px;
    right: 0px;
}

a {
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

tr:hover {
    background: #eee;
}

td, th {
    cursor: default;
    font-size: 10pt;
}

th {
    text-align: left;
}

.delete {
    color: silver;
}

.resolved {
    text-decoration: line-through;
}

.resolved a {
    color: black;
}

</style>
<script>
function delete_instance(dir, summary) {
    if (!confirm('Do you really want to delete "' + dir + '":\n\n' + summary))
        return false;
    var tr = document.getElementById('tr_' + dir);
    var xhr = new XMLHttpRequest();
    tr.parentNode.removeChild(tr);
    xhr.open("GET", '?dir=' + encodeURIComponent(dir) + '&delete=1');
    xhr.send(null);
    return false;
}
</script>
</head>
<body>

<img src="bug.gif" width="100" height="100" id="bug">

<table border="0" cellpadding="5" cellspacing="0" width="100%">

[% shown_gap = 0 %]
[% FOREACH workdir = workdirs %]
    [% IF loop.first %]
        <tr>
            <th colspan="2">dir</th>
            <th>repo/db</th>
            <th width="100%" colspan="7">&nbsp;</th>
        </tr>
    [% END %]
    [% IF (!shown_gap && workdir.bug_id) %]
        [% shown_gap = 1 %]
        <tr>
            <td colspan="7">&nbsp;</td>
        </tr>
        <tr>
            <th colspan="2">dir</th>
            <th>product</th>
            <th>summary</th>
            <th>repo/db</th>
            <th>status</th>
            <th>assignee</th>
            <th>&nbsp;</th>
        </tr>
    [% END %]
    <tr id="tr_[% workdir.dir | html %]">
    [% IF workdir.bug_id %]
        [% bug = workdir.bug %]
        <td nowrap class="[% "resolved" IF bug.status == "RESOLVED" || bug.status == "VERIFIED" %]">
            <a href="[% workdir.dir | url %]/">[% workdir.dir | html %]</a>
        </td>
        <td>
            <a href="#" class="delete"
               onclick="return delete_instance('[% workdir.dir | js | html %]', '[% workdir.summary | js | html %]')">x</a>
        </td>
        <td nowrap>
            [% bug.product | product | html %]
        </td>
        <td>
            <a href="https://bugzilla.mozilla.org/show_bug.cgi?id=[% workdir.bug_id %]" target="_blank">
            [% workdir.summary | html %]
            </a>
        </td>
        <td nowrap>
            [% IF workdir.repo %]
                [% workdir.repo %]
            [% ELSE %]
                -
            [% END ~%]
            <br>
            [%~ IF workdir.db %]
                [% workdir.db %]
            [% ELSE %]
                -
            [% END %]
        </td>
        <td nowrap>
            [% bug.status | html %]
        </td>
        <td nowrap>
            [% bug.assignee | assignee | html %]
        </td>
      [% ELSE %]
        <td nowrap colspan="2">
            <a href="[% workdir.dir | url %]/">[% workdir.dir | html %]</a>
        </td>
        <td nowrap colspan="5">
            [% workdir.repo | html %]
        </td>
      [% END %]
    </tr>
[% END %]

</table>
</body>
</html>
