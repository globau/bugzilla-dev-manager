package BugzillaDevConfig;

use strict;
use base 'Exporter';

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

    GROWL
);

our $HTDOCS_PATH              = '/opt/bugzilla/htdocs';
our $DATA_PATH                = '/opt/bugzilla/repo/git/bugzilla-dev-manager/data';
our $REPO_PATH                = '/opt/bugzilla/repo';
our $YUI2_PATH                = '/opt/bugzilla/yui2';
our $YUI3_PATH                = '/opt/bugzilla/yui3';

our $DEFAULT_BMO_REPO         = 'bmo/4.2';
our $DEFAULT_BMO_DB           = 'bugs_bmo_4_2';
our $BUGZILLA_TRUNK_MILESTONE = '5.0';

our $URL_BASE                 = 'http://fedora/';
our $ATTACH_BASE              = 'http://attach.fedora/';
our $MODPERL_BASE             = 'http://modperl.fedora/';
our $MODPERL_ATTACH_BASE      = 'http://attach.modperl.fedora/';

our $MAIL_FROM                = 'bugzilla-daemon@glob.com.au';
our $MAINTAINER               = 'byron@glob.com.au';

our %LOCALCONFIG = (
    'cvsbin' => '/usr/bin/cvs',
    'db_host' => 'mac',
    'db_pass' => 'sockmonkey',
    'db_port' => '0',
    'db_user' => 'bugs',
    'diffpath' => '/usr/bin',
    'interdiffbin' => '/usr/bin/interdiff',
    'webservergroup' => 'byron',
);

our %PARAMS = (
    allow_attachment_display => 1,
    attachment_base => $ATTACH_BASE . '%s/',
    defaultpriority => '--',
    defaultseverity => 'normal',
    insidergroup => 'admin',
    mail_delivery_method => 'Sendmail',
    mailfrom => $MAIL_FROM,
    maintainer => $MAINTAINER,
    smtpserver => '',
    specific_search_allow_empty_words => 0,
    timetrackinggroup => '',
    upgrade_notification => 'disabled',
    urlbase => $URL_BASE . '%s/',
    usebugaliases => 1,
    useclassification => 1,
    useqacontact => 1,
    user_info_class => 'CGI',
    usestatuswhiteboard => 1,
    usetargetmilestone => 1,
    'webdotbase' => '/usr/bin/dot',
);

our %PARAMS_BMO = (
    user_info_class => 'Persona,CGI',
);

our @NEVER_DISABLE_BUGMAIL = qw(
    glob@mozilla.com
    byron.jones@gmail.com
);

sub GROWL {
    my $message = shift;
    system "ssh byron\@mac 'echo \"$message\"|/usr/local/bin/growlnotify'";
}

1;
