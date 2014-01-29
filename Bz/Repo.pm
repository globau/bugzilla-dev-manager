package Bz::Repo;
use Bz;
use Moo;

use File::Basename;
use File::Find;
use File::Slurp;
use IPC::System::Simple qw(EXIT_ANY capturex runx);

has is_workdir      => ( is => 'ro', default => sub { 0 } );
has dir             => ( is => 'lazy' );
has path            => ( is => 'lazy' );
has bzr_location    => ( is => 'lazy' );

use overload (
    '""' => sub { $_[0]->dir }
);

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

sub _build_bzr_location {
    my ($self) = @_;

    my $bzr_location = '';
    my $filename = $self->path . "/.bzr/branch/branch.conf";
    if (-e $filename) {
        my $conf = read_file($filename);
        ($bzr_location) = $conf =~ /bound_location\s*=\s*(.+)\n/;
    }
    return $bzr_location;
}

sub bzr {
    my ($self, @args) = @_;
    chdir($self->path);
    if (defined wantarray()) {
        return capturex(EXIT_ANY, 'bzr', @args);
    } else {
        return runx(EXIT_ANY, 'bzr', @args);
    }
}

sub update {
    my ($self) = @_;
    info("updating repo " . $self->dir);
    $self->fix();
    chdir($self->path);
    $self->bzr('up');
}

sub fix {
    my ($self) = @_;
    $self->fix_line_endings();
    if (!$self->is_workdir) {
        $self->revert_permissions();
    }
    $self->fix_permissions();
    $self->delete_crud();
}

sub fix_line_endings {
    my ($self) = @_;
    find(
        sub {
            my $file = $_;
            return if -d $file;
            return unless -T $file;
            return if $file =~ /\/\.bzr\//;
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

    chdir($self->path);
    foreach my $line ($self->bzr('diff')) {
        next unless $line =~ /modified file '([^']+)' \(properties changed: ([+-]x) to [+-]x\)/;
        my ($file, $perm) = ($1, $2);
        message("fixing properties for $file");
        $file = '"' . $file . '"' if $file =~ / /;
        sudo_on_output("chmod $perm $file");
    }
}

sub fix_permissions {
    my ($self) = @_;

    chdir($self->path);
    foreach my $file (`find . -type f -perm /111`) {
        chomp $file;
        next if $file =~ /\.(cgi|pl|swp)$/;
        next if $file =~ /^\.\/contrib\//;
        message("fixing permissions for $file");
        $file = '"' . $file . '"' if $file =~ / /;
        sudo_on_output("chmod -x $file");
    }
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

sub added_files {
    my ($self) = @_;

    chdir($self->path);
    my $in_added = 0;
    my @added_files;
    foreach my $line ($self->bzr('st')) {
        chomp $line;
        if ($line =~ /^  (.+)/) {
            my $file = $1;
            next if $file =~ /\@$/;
            push @added_files, $file if $in_added && !-d $file;
        } else {
            $in_added = $line eq 'added:';
        }
    }
    return @added_files;
}

sub test {
    my ($self) = @_;
    $self->check_for_tabs();
    $self->check_for_unknown_files();
    $self->check_for_common_mistakes();
}

sub check_for_tabs {
    my ($self) = @_;

    my $root = $self->path,
    my @invalid;
    my @ignore = qw(
        js/change-columns.js
        t/002goodperl.t
    );
    find(sub {
            my $file = $File::Find::name;
            return if -d $file;
            return unless -T $file;
            return if $file =~ /^\Q$root\E\/(\.bzr|contrib|data|js\/yui\d?|docs)\//;
            return if $file =~ /\.patch$/;
            my $filename = $file;
            $filename =~ s/^\Q$root\E\///;
            return if grep { $_ eq $filename } @ignore;
            my $content = read_file($file);
            return unless $content =~ /\t/;
            push @invalid, $file;
        },
        $root
    );

    return unless @invalid;
    alert('The following files contain tabs:');
    foreach my $filename (@invalid) {
        $filename =~ s/^\Q$root\E\///;
        warning($filename);
    }
}

sub check_for_unknown_files {
    my ($self) = @_;

    chdir($self->path);
    my @lines = $self->bzr('st');
    chomp(@lines);

    my @unknown;
    my $current;
    foreach my $line (@lines) {
        if ($line =~ /^([^:]+):/) {
            $current = $1;
        } elsif ($current eq 'unknown') {
            $line =~ s/^\s+//;
            next if $line =~ /\.(patch|orig)$/;
            push @unknown, $line;
        }
    }
    return unless @unknown;

    alert('The following files are new but are missing from bzr:');
    my $root = quotemeta($self->path);
    foreach my $filename (@unknown) {
        $filename =~ s/^$root\///o;
        warning($filename);
    }
}

sub check_for_common_mistakes {
    my ($self, $filename) = @_;

    chdir($self->path);
    my @lines;
    if ($filename) {
        @lines = read_file($filename);
    } else {
        @lines = `bzr diff`;
    }

    my %whitespace;
    my %xxx;
    my $hunk_file;
    foreach my $line (@lines) {
        next unless $line =~ /^\+/;
        if ($line =~ /^\+\+\+ (\S+)/) {
            $hunk_file = $1;
            next;
        }
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
                warning("  $line");
            }
        }
    }
    if (scalar keys %xxx) {
        alert("line with XXX added:");
        foreach my $file (sort keys %xxx) {
            warning($file);
            foreach my $line (@{ $xxx{$file} }) {
                warning("   $line");
            }
        }
    }
}

sub download_patch {
    my ($self, $attach_id) = @_;
    message("fetching attachment #$attach_id");

    my $attachment = Bz->bugzilla->attachment($attach_id);
    message(sprintf("Bug %s: %s", $attachment->{bug_id}, $attachment->{description} || $attachment->{summary}));
    die "attachment is not a patch\n" unless $attachment->{is_patch} == '1';
    if ($attachment->{is_obsolete} == '1') {
        return unless confirm('attachment is obsolete, continue?');
    }

    my $bug_id = $attachment->{bug_id};
    my $filename = "$bug_id-$attach_id.patch";
    my $content = $attachment->{data};
    $content =~ s/\015\012/\012/g;

    if ($self->can('bug_id') && $self->bug_id && $self->bug_id != $bug_id) {
        my $summary = Bz::Bug->new({ id => $bug_id })->summary;
        exit unless confirm("the patch from a different bug:\nBug $bug_id: $summary\ncontinue?");
    }

    chdir($self->path);
    info("creating $filename");
    write_file($filename, { binmode => ':raw' }, $content);
    return $filename;
}

sub apply_patch {
    my ($self, $filename) = @_;

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
}

1;
