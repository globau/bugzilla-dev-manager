package BugzillaDevConfig;

use strict;
use base 'Exporter';

use File::Slurp;

our @EXPORT = qw(
    $HTDOCS_PATH
    $DATA_PATH
    $REPO_PATH
    $YUI2_PATH
    $YUI3_PATH

    $DEFAULT_BMO_REPO
    $DEFAULT_BMO_DB
    $BUGZILLA_TRUNK_MILESTONE

    $URL_BASE
    $ATTACH_BASE
    $MODPERL_BASE
    $MODPERL_ATTACH_BASE

    $MAIL_FROM
    $MAINTAINER

    %LOCALCONFIG
    %PARAMS
    %PARAMS_BMO

    @NEVER_DISABLE_BUGMAIL

    notify_mac
);

my  $ROOT_PATH                = '/home/byron/bugzilla';
our $HTDOCS_PATH              = "$ROOT_PATH/htdocs";
our $DATA_PATH                = "$ROOT_PATH/repo/git/bugzilla-dev-manager/data";
our $REPO_PATH                = "$ROOT_PATH/repo";
our $YUI2_PATH                = "$ROOT_PATH/yui2";
our $YUI3_PATH                = "$ROOT_PATH/yui3";

our $DEFAULT_BMO_REPO         = 'bmo/4.2';
our $DEFAULT_BMO_DB           = 'bugs_bmo_201312';
our $BUGZILLA_TRUNK_MILESTONE = '5.0';

our $URL_BASE                 = 'http://bz/';
our $ATTACH_BASE              = 'http://attach.bz/';
our $MODPERL_BASE             = 'http://modperl.bz/';
our $MODPERL_ATTACH_BASE      = 'http://attach.modperl.bz/';

our $MAIL_FROM                = 'bugzilla-daemon@glob.com.au';
our $MAINTAINER               = 'byron@glob.com.au';

our %LOCALCONFIG = (
    cvsbin          => '/usr/bin/cvs',
    db_host         => 'mac',
    db_pass         => 'sockmonkey',
    db_port         => '0',
    db_user         => 'bugs',
    diffpath        => '/usr/bin',
    interdiffbin    => '/usr/bin/interdiff',
    webservergroup  => 'byron',
);

our %PARAMS = (
    allow_attachment_display            => 1,
    attachment_base                     => $ATTACH_BASE . '%s/',
    cookiepath                          => '/%s/',
    defaultpriority                     => '--',
    defaultseverity                     => 'normal',
    insidergroup                        => 'admin',
    mail_delivery_method                => 'Sendmail',
    mailfrom                            => $MAIL_FROM,
    maintainer                          => $MAINTAINER,
    memcached_namespace                 => '%s:',
    smtpserver                          => '',
    specific_search_allow_empty_words   => 0,
    timetrackinggroup                   => '',
    upgrade_notification                => 'disabled',
    urlbase                             => $URL_BASE . '%s/',
    usebugaliases                       => 1,
    useclassification                   => 1,
    useqacontact                        => 1,
    user_info_class                     => 'CGI',
    usestatuswhiteboard                 => 1,
    usetargetmilestone                  => 1,
    webdotbase                          => '/usr/bin/dot',
);

our %PARAMS_BMO = (
    password_complexity => 'letters_numbers',
    user_info_class     => 'Persona,CGI',
);

our @NEVER_DISABLE_BUGMAIL = qw(
    glob@mozilla.com
    byron.jones@gmail.com
);

sub notify_mac {
    my $message = shift;

    my @title = split /\000/, read_file('/proc/self/cmdline');
    shift @title;     # perl
    $title[0] = 'bz'; # script
    my $title = join(' ', @title);

    # growl
=cut
    system(
        'ssh',
        'byron@mac',
        join(
            ' ',
            (
                'echo',
                sprintf('"(%s) %s"', $title, $message),
                '|',
                '/usr/local/bin/growlnotify',
            )
        )
    );
=cut

    # terminal-notifier
    system(
        'ssh',
        'byron@mac',
        join(
            ' ',
            (
                '/usr/local/bin/terminal-notifier',
                '-sound Pop',
                '-activate com.googlecode.iterm2',
                '-title "' . $title . '"',
                '-message "' . $message . '"',
            )
        )
    );
}

1;
