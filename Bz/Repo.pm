package Bz::Repo;
use Bz;
use Moo;

use File::Basename;
use File::Find;
use File::Slurp;

has dir     => ( is => 'lazy', builder => sub { dirname($_[0]->path) } );
has path    => ( is => 'lazy', builder => sub { Bz->config->repo_path . '/' . $_[0]->dir } );

sub update {
    my ($self) = @_;
    info("updating repo " . $self->dir);
    $self->fix();
    chdir($self->path);
    system "bzr up";
}

sub fix {
    my ($self, $quick) = @_;
    $quick = 0 unless $quick;
    chdir($self->path);

    find(
        sub {
            my $file = $_;
            return if -d $file;
            if ($file =~ /\~\d+\~$/ || $file =~ /^\._/ || $file =~ /\.(orig|rej)$/) {
                print "deleting $file\n";
                unlink($file);
                return;
            }
            return if $quick;
            return unless -T $file;
            return if $file =~ /\/\.bzr\//;
            my $content = read_file($file, binmod => ':raw');
            return unless $content =~ /\015\012/;
            my $filename = $File::Find::name;
            $filename =~ s/^\.\///;
            print "converting $filename to unix line endings\n";
            $content =~ s/\015\012/\012/g;
            write_file($file, { binmod => ':raw' }, $content);
        },
        '.'
    );
    return if $quick;

    foreach my $line (`bzr diff`) {
        next unless $line =~ /modified file '([^']+)' \(properties changed: ([+-]x) to [+-]x\)/;
        my ($file, $perm) = ($1, $2);
        print "fixing permissions for $file\n";
        system "chmod $perm $file";
    }

    foreach my $file (`find . -type f -perm /111`) {
        chomp $file;
        next if $file =~ /\.(cgi|pl|swp)$/i;
        next if $file =~ /^\.\/contrib\//;
        print "fixing permissions for $file\n";
        system "chmod -x $file";
    }
}

1;
