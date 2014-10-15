package Bz::App::Command::diff;
use parent 'Bz::App::Base';
use Bz;

use File::Slurp;

sub abstract {
    return "generate a new patch";
}

sub usage_desc {
    return "bz diff [--quick] [--stdout] [--whitespace]";
}

sub opt_spec {
    return (
        [ "quick|q",        "don't run tests" ],
        [ "stdout",         "output diff to stdout" ],
        [ "whitespace|w",   "ignore whitespace" ],
    );
}

sub description {
    return <<EOF;
executes a subset of tests, then creates a patch with the current changes.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;
    my $boiler_plate = Bz->boiler_plate;

    info("creating patch");
    chdir($workdir->path);

    die "no files are staged\n"
        unless $workdir->staged_files();

    $workdir->unfix();
    if (my @files = $workdir->modified_files) {
        alert("the following file" . (scalar(@files) == 1 ? ' is' : 's are') . " modified but not staged:");
        foreach my $file (@files) {
            warning($file);
        }
    }
    $workdir->fix();

    if (!$opt->quick) {
        my @missing;
        foreach my $file (grep { -T $_ } $workdir->added_files()) {
            push @missing, $file unless $boiler_plate->exists($file);
        }
        if (@missing) {
            foreach my $file (@missing) {
                warning("$file does not contain a boilerplate");
            }
            exit unless confirm("continue?");
        }
        $workdir->test(undef, [2, 4, 5, 6, 8, 9, 10, 11]);
    }
    $self->diff($workdir, $opt);
}

sub diff {
    my ($self, $workdir, $opt) = @_;

    my $base = $workdir->dir;
    my $revision = 0;
    foreach my $file (glob("${base}_*.patch")) {
        next unless $file =~ /^\Q$base\E_(\d+)\.patch$/;
        $revision = $1 if $1 > $revision;
    }
    $revision++;

    $workdir->unfix();
    chdir($workdir->path);
    my @command = ('diff', '--staged', '--full-index');
    push @command, ('-w') if $opt->whitespace;
    my $patch = $workdir->git(@command);
    my $filename;
    if ($opt->stdout) {
        print $patch;
    } else {
        $filename = "${base}_$revision.patch";
        message("creating $filename");
        write_file($filename, $patch);
    }
    $workdir->fix();
    info("$filename created") if $filename;
    return $filename;
}

1;
