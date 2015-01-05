package Bz::Repo;
use Bz;
use Moo;

use Cwd 'abs_path';
use File::Basename;
use File::Find;
use File::Slurp;
use IPC::System::Simple qw(EXIT_ANY capturex runx);

has is_workdir      => ( is => 'ro', default => sub { 0 } );
has is_bmo          => ( is => 'lazy' );
has is_upstream     => ( is => 'lazy' );
has dir             => ( is => 'lazy' );
has path            => ( is => 'lazy' );
has url             => ( is => 'lazy' );
has branch          => ( is => 'lazy' );

use overload (
    '""' => sub { $_[0]->dir }
);

sub _build_is_bmo {
    my ($self) = @_;
    return $self->url =~ m#webtools/bmo/bugzilla\.git$#;
}

sub _build_is_upstream {
    my ($self) = @_;
    return $self->url =~ m#bugzilla/bugzilla\.git$#;
}

sub _build_dir {
    my ($self) = @_;
    my $repo_path = Bz->config->repo_path;
    (my $dir = $self->path) =~ s/^\Q$repo_path\E\///;
    return $dir;
}

sub _build_path {
    my ($self) = @_;
    return Bz->config->repo_path . '/' . $self->dir;
}

sub _build_url {
    my ($self) = @_;
    my $repo = $self->git(qw(config --local --get remote.origin.url));
    chomp($repo);
    return $repo;
}

sub _build_branch {
    my ($self) = @_;
    foreach my $line ($self->git('branch')) {
        if ($line =~ /^\* \(no branch, rebasing ([^\)]+)/) {
            return $1;
        }
        next unless $line =~ /^\* (\S+)/;
        return $1;
    }
    die "failed to determine current branch\n";
}

sub git {
    my ($self, @args) = @_;
    my $cwd = abs_path();
    chdir($self->path);
    if (defined wantarray()) {
        return capturex(EXIT_ANY, 'git', @args);
    } else {
        return runx(EXIT_ANY, 'git', @args);
    }
    chdir($cwd);
}

sub git_status {
    my ($self, $status_mask) = @_;

    my @files;
    my $cwd = abs_path();
    chdir($self->path);
    foreach my $line ($self->git(qw(status --porcelain))) {
        chomp $line;
        if ($line =~ /^(..) (.+)$/) {
            my ($status, $file) = ($1, $2);
            next if $status_mask &&  $status !~ /^$status_mask$/;
            $file =~ s/^.+? -> //
                if substr($status, 0, 1) eq 'R';
            push @files, $file;
        }
    }
    chdir($cwd);
    return @files;
}

sub update {
    my ($self) = @_;
    info("updating repo " . $self->dir);
    $self->fix();
    my $cwd = abs_path();
    chdir($self->path);
    $self->git(qw(pull --rebase));
    chdir($cwd);
}

sub delete_cache {
}

sub fix {
    my ($self) = @_;
    $self->fix_line_endings();
    if (!$self->is_workdir) {
        $self->revert_permissions();
    }
    $self->delete_crud();
    $self->fix_permissions();
}

sub unfix {
}

sub fix_line_endings {
    my ($self) = @_;
    find(
        sub {
            my $file = $_;
            return if -d $file;
            return unless -T $file;
            return if $file =~ /\/\.git\//;
            my $content = read_file($file, binmod => ':raw');
            return unless $content =~ /\015\012/;
            my $filename = $File::Find::name;
            $filename =~ s/^\.\///;
            message("converting $filename to unix line endings");
            $content =~ s/\015\012/\012/g;
            write_file($file, { binmod => ':raw' }, $content);
        },
        $self->path
    );
}

sub revert_permissions {
    my ($self) = @_;

    my $cwd = abs_path();
    chdir($self->path);
    my $file;
    foreach my $line ($self->git('diff')) {
        if ($line =~ /^diff --git a\/(\S+)/) {
            $file = $1;
            next;
        }
        next unless $line =~ /^old mode \d\d\d(\d\d\d)/;
        my $perm = $1;
        message("fixing properties for $file --> $perm");
        sudo_on_output("chmod $perm $file");
    }
    chdir($cwd);
}

sub fix_permissions {
    my ($self) = @_;

    my $cwd = abs_path();
    chdir($self->path);
    foreach my $file (`find . -type f -perm /111`) {
        chomp $file;
        next if $file =~ /\.(cgi|pl|swp)$/;
        next if $file =~ /^\.\/contrib\//;
        message("fixing permissions for $file");
        $file = '"' . $file . '"' if $file =~ / /;
        sudo_on_output("chmod -x $file");
    }
    chdir($cwd);
}

sub delete_crud {
    my ($self) = @_;

    my $path = $self->path;
    my @crud_dirs;
    find(
        sub {
            my $filename = $File::Find::name;
            return unless
                $filename =~ /\~\d+\~$/
                || basename($filename) =~ /^\._/
                || $filename =~ /\.orig$/
                || $filename =~ /\.moved$/
                || $filename =~ /\.rej$/;
            my $name = $filename;
            $name =~ s#^\Q$path\E/##;
            message("deleting $name");
            if (-d $filename) {
                push @crud_dirs, $filename;
            } else {
                unlink($filename);
            }
        },
        $path
    );
    foreach my $dir (@crud_dirs) {
        rmdir($dir);
    }
    if (-d "$path/data/deleteme") {
        message("deleting data/deleteme");
        system (qq#rm -rf "$path/data/deleteme"#);
        if (-d "$path/data/deleteme") {
            system (qq#sudo rm -rf "$path/data/deleteme"#);
        }
    }
}

sub new_files {
    my ($self) = @_;
    my @files;

    foreach my $file ($self->git_status('\?\?')) {
        if (-f $file) {
            push @files, $file;
        } elsif ($file ne 'tmp/') {
            chdir($self->path);
            find(sub {
                push @files, $File::Find::name if -f $_;
            }, $file);
        }
    }
    return @files;
}

sub new_code_files {
    my ($self) = @_;
    return grep { /\.(pm|pl|tmpl|js|css|t)$/ } $self->new_files;
}

sub modified_files {
    my ($self) = @_;
    return $self->git_status('.M');
}

sub deleted_files {
    my ($self) = @_;
    return $self->git_status(' D');
}

sub staged_files {
    my ($self) = @_;
    return $self->git_status('[^ \?D].');
}

sub staged_changes {
    my ($self) = @_;
    return $self->git_status('[^ \?].');
}

sub committed_files {
    my ($self) = @_;

    my $cwd = abs_path();
    chdir($self->path);
    my @files;
    foreach my $line ($self->git('diff', '--name-status', 'origin/' . $self->branch, $self->branch)) {
        chomp $line;
        if ($line =~ /^[AM]\s+(.+)$/) {
            push @files, $1;
        }
    }
    chdir($cwd);
    return @files;
}

sub added_files {
    my ($self) = @_;
    return $self->git_status('A ');
}

sub test {
    my ($self) = @_;
    $self->check_for_tabs();
    $self->check_for_unknown_files();
    $self->check_for_common_mistakes();
}

sub _test_ignore {
    my ($self, $file, @extra) = @_;
    return 1 if -d $file;
    return 1 unless -T $file;
    my $root = $self->path;
    if (substr($file, 0, length($root)) eq $root) {
        substr($file, 0, length($root) + 1) = '';
    }

    my @ignore_prefix = qw(
        contrib/
        data/
        docs/
        .git/
        js/jquery/
        js/yui/
        js/yui3/
        template_cache/
        tmp/
    );
    my @ignore_suffix = qw(
        .orig
        .patch
    );

    foreach my $prefix (@ignore_prefix) {
        return 1 if substr($file, 0, length($prefix)) eq $prefix;
    }
    foreach my $suffix (@ignore_suffix) {
        return 1 if substr($file, length($file) - length($suffix)) eq $suffix;
    }
    foreach my $extra (@extra) {
        return 1 if $file eq $extra;
    }
    return 0;
}

sub check_for_tabs {
    my ($self) = @_;

    my $root = $self->path;
    my @invalid;
    my @ignore = qw(
        js/change-columns.js
        t/002goodperl.t
    );
    find(sub {
            my $file = $File::Find::name;
            return if $self->_test_ignore($file, @ignore);
            my $content = read_file($file);
            return unless $content =~ /\t/;
            push @invalid, $file;
        },
        $root
    );

    return unless @invalid;
    alert('The following files contain tabs:');
    foreach my $filename (@invalid) {
        substr($filename, 0, length($root) + 1) = '';
        warning($filename);
    }
}

sub check_for_unknown_files {
    my ($self) = @_;

    my @unknown;
    foreach my $file ($self->new_files) {
        next if
            ($file =~ /\.htaccess$/ && $file ne '.htaccess')
            || $file =~ /\.(patch|orig)$/
        ;
        push @unknown, $file;
    }
    return unless @unknown;

    alert('The following files are new but are not staged');
    my $root = quotemeta($self->path);
    foreach my $filename (@unknown) {
        $filename =~ s/^$root\///o;
        warning($filename);
    }
}

sub check_for_common_mistakes {
    my ($self) = @_;

    my $cwd = abs_path();
    chdir($self->path);
    my @lines = $self->git(qw(diff --staged));
    foreach my $file ($self->new_code_files()) {
        push @lines, $self->git('diff', '/dev/null', $file);
    }

    my %whitespace;
    my %xxx;
    my $hunk_file;
    foreach my $line (@lines) {
        next unless $line =~ /^\+/;
        if ($line =~ /^\+\+\+ [ab]\/(\S+)/) {
            $hunk_file = $1;
            next;
        }
        next if $self->_test_ignore($hunk_file);
        chomp($line);
        if ($line =~ /\s+$/) {
            my $ra = $whitespace{$hunk_file} ||= [];
            push @$ra, $line;
        }
        if ($line =~ /XXX/) {
            my $ra = $xxx{$hunk_file} ||= [];
            push @$ra, $line;
        }
    }
    if (scalar keys %whitespace) {
        alert("trailing whitespace added:");
        foreach my $file (sort keys %whitespace) {
            warning($file);
            foreach my $line (@{ $whitespace{$file} }) {
                message("  $line");
            }
        }
    }
    if (scalar keys %xxx) {
        alert("line with XXX added:");
        foreach my $file (sort keys %xxx) {
            warning($file);
            foreach my $line (@{ $xxx{$file} }) {
                message("   $line");
            }
        }
    }

    my @missing_bp;
    foreach my $file (($self->new_code_files(), $self->staged_files())) {
        next if $self->_test_ignore($file);
        push @missing_bp, $file
            unless Bz->boiler_plate->exists($file);
    }
    if (@missing_bp) {
        alert("missing boiler plate:");
        foreach my $file (sort @missing_bp) {
            warning($file);
        }
    }
    chdir($cwd);
}

sub download_patch {
    my ($self, $attach_id) = @_;
    message("fetching attachment #$attach_id");

    my $attachment = Bz->bugzilla->attachment($attach_id);
    message(sprintf("Bug %s: %s", $attachment->{bug_id}, $attachment->{description} || $attachment->{summary}));
    die "attachment is not a patch\n" unless $attachment->{is_patch} == '1';

    my $bug_id = $attachment->{bug_id};
    my $filename = "$bug_id-$attach_id.patch";
    my $content = $attachment->{data};
    $content =~ s/\015\012/\012/g;

    if ($self->is_workdir && $self->bug_id && $self->bug_id != $bug_id) {
        my $summary = Bz::Bug->new({ id => $bug_id })->summary;
        exit unless confirm("the patch from a different bug:\nBug $bug_id: $summary\ncontinue?");
    }

    my $cwd = abs_path();
    chdir($self->path);
    info("creating $filename");
    write_file($filename, { binmode => ':raw' }, $content);
    chdir($cwd);
    return $filename;
}

sub apply_patch {
    my ($self, $filename) = @_;

    my $cwd = abs_path();
    chdir($self->path);
    my @patch = read_file($filename);

    my $p = 0;
    foreach my $line (@patch) {
        if ($line =~ /^diff --git a\//) {
            $p = 1;
            last;
        }
    }

    open(my $patch, "|patch -p$p");
    foreach my $line (@patch) {
        # === renamed file 'extensions/BMO/web/js/choose_product.js' => 'extensions/BMO/web/js/prod_comp_search.js'
        if ($line =~ /^=== renamed file '([^']+)' => '([^']+)'/) {
            message("renamed '$1' => '$2'");
            rename($1, $2);
            next;
        }
        print $patch $line;
    }
    close($patch);
    chdir($cwd);
}

1;
