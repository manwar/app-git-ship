package App::git::ship;

=head1 NAME

App::git::ship - Git command for shipping your project

=head1 VERSION

0.01

=head1 DESCRIPTION

L<App::git::ship> is a C<git> command for shipping your project to CPAN or
some other repository.

=head1 SYNOPSIS

=head2 For end user

  $ git ship -h

=head2 For developer

  package App::git::ship::some_language;
  use App::git::ship -base;

  # define attributes
  has some_attribute => sub {
    my $self = shift;
    return "default value";
  };

  # override the methods defined in App::git::ship
  sub build {
    my $self = shift;
  }

  1;

=cut

use strict;
use warnings;
use Carp;
use Data::Dumper ();

use constant DEBUG => $ENV{GIT_SHIP_DEBUG} || 0;

our $VERSION = '0.01';

=head1 ATTRIBUTES

=head2 config

  $hash_ref = $self->config;

Holds the configuration from end user. The config is by default read from
C<.git-ship.conf> in the root of your project.

=head2 project_name

  $str = $self->project_name;

Holds the name of the current project. This attribute can be read from
L</config>.

=head2 repository

  $str = $self->repository;

Returns the URL to the first repository that point to L<github|http://github.com>.
This attribute can be read from L</config>.

=cut

__PACKAGE__->attr(config => sub {
  my $self = shift;
  my $file = $self->_config_file;
  my $config;

  open my $CFG, '<', $file or $self->abort("git-ship: Read $file: $!");

  while (<$CFG>) {
    chomp;
    warn "[ship::config] $_\n" if DEBUG;
    $config->{$1} = $2 if /^\s*(\S+)\s*=\s*(.+)/;
  }

  return $config;
});

__PACKAGE__->attr(project_name => sub {
  my $self = shift;
  return $self->config->{project_name} if $self->config->{project_name};
  $self->abort('project_name is not defined in config file.');
});

__PACKAGE__->attr(repository => sub {
  my $self = shift;
  return $self->config->{repository} if $self->config->{repository};
  open my $GIT, '-|', 'git remote -v | grep github' or $self->abort("git remote -v: $!");
  my $repository = readline $GIT;
  $self->abort('Could not find any repository URL to GitHub.') unless $repository;
  return sprintf 'https://github.com/%s', +(split /[:\s+]/, $repository)[2];
});

=head1 METHODS

=head2 abort

  $self->abort($str);
  $self->abort($format, @args);

Will abort the application run with an error message.

=cut

sub abort {
  my ($self, $format, @args) = @_;
  my $message = @args ? sprintf $format, @args : $format;

  Carp::confess("git-ship: $message") if DEBUG;
  die "git-ship: $message\n";
}

=head2 attr

  $class = $class->attr($name => sub { my $self = shift; return $default_value });

or ...

  use App::git::ship -base;
  has $name => sub { my $self = shift; return $default_value };

Used to create an attribute with a lazy builder.

=cut

sub attr {
  my ($self, $name, $default) = @_;
  my $class = ref $self || $self;
  my $code = "";

  $code .= "package $class; sub $name {";
  $code .= "return \$_[0]->{$name} if \@_ == 1 and exists \$_[0]->{$name};";
  $code .= "return \$_[0]->{$name} = \$_[0]->\$default if \@_ == 1;";
  $code .= "\$_[0]->{$name} = \$_[1] if \@_ == 2;";
  $code .= '$_[0];}';

  eval "$code;1" or die "$code: $@";

  return $self;
}

=head2 author

  $str = $self->author($format);
  $str = $self->author("%an, <%ae>"); # Jan Henning Thorsen, <jhthorsen@cpan.org>

Returns a string used to describe the latest author from the C<git> log.

 %an: author name
 %ae: author email

=cut

sub author {
  my $self = shift;
  my $format = shift || '%an';

  open my $GIT, '-|', qw( git log ), "--format=$format" or $self->abort("git log --format=$format: $!");
  my $author = readline $GIT;
  chomp $author;
  return $author;
}

=head2 build

This method builds the project. The default behavior is to L</abort>.
Need to be overridden in the subclass.

=cut

sub build {
  $_[0]->abort('build() is not available for %s', ref $_[0]);
}

=head2 init

This method is called when initializing the project. The default behavior is
to populate L</config> with default data:

=over 4

=item * bugtracker

URL to the bug tracker. Will be the the L</repository> URL without ".git", but
with "/issues" at the end instead.

=item * homepage

URL to the project homepage. Will be the the L</repository> URL, without ".git".

=item * license_name

The name of the license. Default to L<artistic_2|http://www.opensource.org/licenses/artistic-license-2.0>.

=item * license_url

The URL to the license. Default to L<http://www.opensource.org/licenses/artistic-license-2.0>.

=back

=cut

sub init {
  my $self = shift;
  my $config = {};

  $self->config($config);

  $config->{bugtracker} ||= +(join '/', $self->repository =~ s!\.git$!!r, 'issues') =~ s!(\w)//!$1/!r;
  $config->{homepage} ||= $self->repository =~ s!\.git$!!r;
  $config->{license_name} ||= 'artistic_2';
  $config->{license_url} ||= 'http://www.opensource.org/licenses/artistic-license-2.0';
}

=head2 new

  $self = $class->new(%attributes);

Creates a new instance of C<$class>.

=cut

sub new {
  my $class = shift;
  bless @_ ? @_ > 1 ? {@_} : {%{$_[0]}} : {}, ref $class || $class;
}

=head2 ship

This method ships the project to some online repository. The default behavior
is to make a new tag and push it to L</repository>.

=cut

sub ship {
  $_[0]->abort('TODO', ref $_[0]);
}

=head2 system

  $self->system($program, @args);

Same as perl's C<system()>, but provides error handling and logging.

=cut

sub system {
  my ($self, $program, @args) = @_;
  my $exit_code;

  system $program => @args;
  $exit_code = $? >> 8;
  $self->abort("'$program @args' failed: $exit_code") if $exit_code;
  $self;
}

=head2 test

This method test the project. The default behavior is to L</abort>.
Need to be overridden in the subclass.

=cut

sub test {
  $_[0]->abort('test() is not available for %s', ref $_[0]);
}

=head2 import

  use App::git::ship;
  use App::git::ship -base;

Called when this class is used. It will automatically enable L<strict>,
L<warnings>, L<utf8> and Perl 5.10 features.

C<-base> will also make sure the calling class inherit from
L<App::git::ship> and gets the L<has|/attr> function.

=cut

sub import {
  my ($class, $arg) = @_;
  my $caller = caller;

  if ($arg and $arg eq '-base') {
    no strict 'refs';
    push @{"${caller}::ISA"}, __PACKAGE__;
    *{"${caller}::has"} = sub { attr($caller, @_) };
  }

  autodie->import;
  feature->import(':5.10');
  strict->import;
  warnings->import;
}

sub _config_file { $ENV{GIT_SHIP_CONFIG} || '.git-ship.conf'; }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;