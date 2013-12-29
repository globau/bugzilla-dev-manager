package Bz::App::Command::diff;
use Bz::App -command;
use Bz;

use File::Slurp;

sub abstract {
    return "XXX";
}

sub usage_desc {
    return "diff [--quick] [--stdout] [--whitespace]";
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
XXX
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;
    my $util = Bz->util;

    info("creating patch");
    chdir($workdir->path);

    if (!$opt->quick) {
        my @missing;
        foreach my $file (grep { -T $_ } $workdir->added_files()) {
            push @missing, $file unless $util->boiler_plate_exists($file);
        }
        if (@missing) {
            foreach my $file (@missing) {
                warning("$file does not contain a boilerplate");
            }
            exit unless confirm("continue?");
        }
        $workdir->run_tests(undef, 2, 4, 5, 6, 8, 9, 10, 11);
    }
    $self->diff($workdir, $opt);
    #checkForCommonMistakes($subdir, $filename);
}

sub diff {
    my ($self, $workdir, $opt) = @_;

    my $base = $workdir->bug_id || $workdir->dir;
    my $revision = 0;
    foreach my $file (glob("${base}_*.patch")) {
        next unless $file =~ /^\Q$base\E_(\d+)\.patch$/;
        $revision = $1 if $1 > $revision;
    }
    $revision++;

    $workdir->unfix();
    chdir($workdir->path);
    my $command = "bzr diff " . ($opt->whitespace ? "--diff-options -w " : '');
    my $patch = `$command`;
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
