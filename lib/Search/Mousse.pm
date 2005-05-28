package Search::Mousse;
use strict;
our $VERSION = '0.29';
use base qw(Class::Accessor::Chained::Fast);
__PACKAGE__->mk_accessors(
  qw(directory name stemmer key_to_id id_to_key id_to_value word_to_id)
);
use CDB_File;
use CDB_File_Thawed;
use List::Uniq qw(uniq);
use Path::Class;

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;

	my %args = @_;
	$self->directory($args{directory});
  $self->name($args{name});
  $self->stemmer(
    $args{stemmer} ||
    sub {
      my $words = lc shift;
      return uniq(split / /, $words);
    }
  );

	$self->_init;
  return $self;
}

sub _init {
  my ($self) = @_;
  my $name   = $self->name;
  my $dir    = $self->directory;

  my $filename = file($dir, "${name}_key_to_id.cdb");
  tie my %cdb1, 'CDB_File', $filename or die "tie failed: $!\n";
  $self->key_to_id(\%cdb1);

  $filename = file($dir, "${name}_id_to_key.cdb");
  tie my %cdb2, 'CDB_File', $filename or die "tie failed: $!\n";
  $self->id_to_key(\%cdb2);

  $filename = file($dir, "${name}_id_to_value.cdb");
  tie my %cdb3, 'CDB_File_Thawed', $filename or die "tie failed: $!\n";
  $self->id_to_value(\%cdb3);

  $filename = file($dir, "${name}_word_to_id.cdb");
  tie my %cdb4, 'CDB_File_Thawed', $filename or die "tie failed: $!\n";
  $self->word_to_id(\%cdb4);
}

sub fetch {
  my ($self, $key) = @_;

  my $id = $self->key_to_id->{$key};
  return unless $id;
  return $self->id_to_value->{$id};
}

sub search {
  my ($self, $words) = @_;

  my @ids = $self->_search_ids($words);

  my @values = map { $self->id_to_value->{$_} } @ids;
  return @values;
}

sub search_keys {
  my ($self, $words) = @_;
  my @ids = $self->_search_ids($words);

  my @keys = map { $self->id_to_key->{$_} } @ids;
  return @keys;
}

sub _search_ids {
  my ($self, $words) = @_;

  my @words = $self->stemmer->($words);

  #  use YAML; die Dump ($data->{word_to_id});

  my $word = pop @words;
  return unless exists $self->word_to_id->{$word};
  my @ids = @{ $self->word_to_id->{$word} };
  foreach $word (@words) {
    return unless exists $self->word_to_id->{$word};
    my @newids = @{ $self->word_to_id->{$word} };
    my %in = map { ($_, 1) } @newids;
    @ids = grep { $in{$_} } @ids;
  }
  @ids = uniq(@ids);
  return @ids;
}

1;

__END__

=head1 NAME

Search::Mousse - A simple and fast inverted index

=head1 SYNOPSIS

  my $mousse = Search::Mousse->new(
    directory => $directory,
    name      => 'recipes',
  );
  my $recipe = $mousse->fetch("Hearty Russian Beet Soup");
  my @recipes = $mousse->search("crumb");
  my @recipe_keys = $mousse->search_keys("italian soup");
  
=head1 DESCRIPTION

L<Search::Mousse> provides a simple and fast inverted index.

It is intended for constant databases (this is why it can be fast).
Documents have a key, keywords (which the document can later be search
for with) and a value (which can be a Perl data structure or object).

Use L<Search::Mousse::Writer> to construct a database.

The default stemmer is:

  sub {
    my $words = lc shift;
    return uniq(split / /, $words);
  }

Why is it called Search::Mousse? Well, in culinary terms, mousses are
simple to make, can include quite complicated ingredients, and are
inverted before presentation.

=head1 CONSTRUCTOR

=head2 new

The constructor takes a few arguments: the directory to store files in,
and a name for the database. If you have a custom stemmer, also pass it in:

  my $mousse = Search::Mousse->new(
    directory => $directory,
    name      => 'recipes',
  );
  
  my $mousse2 = Search::Mousse->new(
    directory => $directory,
    name      => 'photos',
    stemmer   => \&stemmer,
  );

=head1 METHODS

=head2 fetch

Returns a value from the database, given a key:

  my $recipe = $mousse->fetch("Hearty Russian Beet Soup");

=head2 search

Returns a list of values that have all the keywords passed:

  my @recipes = $mousse->search("white bread");

=head2 search_keys

Returns a list of keys that have all the keywords passed:

  my @recipe_keys = $mousse->search_keys("italian soup");

=head1 SEE ALSO

L<Search::Mousse::Writer>

=head1 AUTHOR

Leon Brocard, C<< <acme@astray.com> >>

=head1 COPYRIGHT

Copyright (C) 2005, Leon Brocard

This module is free software; you can redistribute it or modify it
under the same terms as Perl itself.
