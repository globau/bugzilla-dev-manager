package BugzillaDevConfig;

use strict;
use base 'Exporter';

our @EXPORT = qw(
    $HTDOCS_PATH
    $DATA_PATH
    $REPO_PATH
    $YUI_PATH

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
);

our $HTDOCS_PATH              = '/opt/bugzilla/htdocs';
our $DATA_PATH                = '/opt/bugzilla/repo/git/bugzilla-dev-manager/data';
our $REPO_PATH                = '/opt/bugzilla/repo';
our $YUI_PATH                 = '/opt/bugzilla/yui';

our $DEFAULT_BMO_REPO         = 'bmo/4.0';
our $DEFAULT_BMO_DB           = 'bugs_bmo_20120301';
our $BUGZILLA_TRUNK_MILESTONE = '4.4';

our $URL_BASE                 = 'http://fedora/';
our $ATTACH_BASE              = 'http://attach.fedora/';
our $MODPERL_BASE             = 'http://modperl.fedora/';
our $MODPERL_ATTACH_BASE      = 'http://attach.modperl.fedora/';

our $MAIL_FROM                = 'bugzilla-daemon@glob.com.au';
our $MAINTAINER               = 'byron@glob.com.au';

our %LOCALCONFIG = (
    'db_host' => 'mac',
    'db_port' => '0',
    'db_user' => 'bugs',
    'db_pass' => 'sockmonkey',
    'cvsbin' => '/usr/bin/cvs',
    'interdiffbin' => '/usr/bin/interdiff',
    'diffpath' => '/usr/bin',
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
);

our %PARAMS_BMO = (
    user_info_class => 'BrowserID,CGI',
);

1;
