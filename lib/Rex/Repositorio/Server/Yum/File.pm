#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Repositorio::Server::Yum::File;

use Mojo::Base 'Mojolicious::Controller';
use File::Spec;
use File::Path;
use File::Basename qw'dirname';

# VERSION

sub serve {
  my ($self) = @_;

  my $file = $self->req->url;
  $self->app->log->debug("Serving: $file");

  my $full_repo_dir = $self->app->get_repo_dir( repo => $self->repo->{name} );
  my $repo_dir = File::Spec->rel2abs( $self->config->{RepositoryRoot} );

  $self->app->log->debug("Path: $repo_dir");
  $self->app->log->debug("Full-Path: $full_repo_dir");


  my $serve_dir = File::Spec->catdir( $repo_dir, $file );

  my $orig_file = $serve_dir;
  $orig_file =~ s/\Q$full_repo_dir\E//;
  $orig_file =~ s/\/$//;
  $orig_file =~ s/^\///;
  my $repo_url = $self->repo->{url};
  $repo_url =~ s/\/$//;

  $self->app->log->debug("Upstream-Repo-URL: $repo_url");
  $self->app->log->debug("Upstream-File: $orig_file");

  my $orig_file_url = $repo_url . "/" . $orig_file;
  $self->app->log->debug("Original-File-URL: $orig_file_url" );

  if ( -d $serve_dir ) {
    my @entries;
    opendir( my $dh, $serve_dir ) or die($!);
    while ( my $entry = readdir($dh) ) {
      next if ( $entry =~ m/^\./ );
      push @entries,
        {
        name => $entry,
        file => ( -f File::Spec->catfile( $serve_dir, $entry ) ),
        };
    }
    closedir($dh);

    @entries =
      sort { "$a->{file}-$a->{name}" cmp "$b->{file}-$b->{name}" } @entries;

    $self->stash( path    => $file );
    $self->stash( entries => \@entries );

    $self->render("file/serve");
  }
  else {
    if(-f $serve_dir) {
      $self->app->log->debug("File-Download: $serve_dir");
      return $self->render_file( filepath => $serve_dir );
    }
    else {
      $self->app->log->debug("Need to get file from upstream: $orig_file_url");
      return $self->proxy_to($orig_file_url, sub {
        my ($c, $tx) = @_;
        $c->app->log->debug("Got data from upstream...");
        mkpath(dirname($serve_dir));
        open my $fh, '>', $serve_dir or die($!);
        binmode $fh;
        print $fh $tx->res->body;
        close $fh;
      });
    }
  }
}

sub index {
  my ($self) = @_;

  my $repo_dir = File::Spec->rel2abs( $self->config->{RepositoryRoot} );

  # get tags
  opendir( my $dh, $repo_dir ) or die($!);
  my @tags;
  while ( my $entry = readdir($dh) ) {
    next if ( $entry =~ m/^\./ );
    if ( -d File::Spec->catdir( $repo_dir, $entry, $self->repo->{name} ) ) {
      push @tags, $entry;
    }
  }
  closedir($dh);

  $self->stash( "path", "/" );
  $self->stash( "tags", \@tags );
  $self->stash( repo_name => $self->repo->{name} );

  $self->render("file/index");
}

1;
