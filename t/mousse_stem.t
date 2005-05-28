#!perl
use strict;
use File::Path;
use List::Uniq qw(uniq);
use MealMaster;
use Test::More tests => 9;
use Text::Soundex;
use_ok("Search::Mousse");
use_ok("Search::Mousse::Writer");

my $directory = "t/tmp";
rmtree($directory);
mkdir($directory) || die $!;

my $mousse = Search::Mousse::Writer->new(
  directory => $directory,
  name      => 'recipes',
  stemmer   => \&stemmer,
);

my $mm = MealMaster->new;
my @recipes = $mm->parse("t/0222-1.TXT");
foreach my $recipe (@recipes) {
  my $title = ucfirst(lc($recipe->title));
  $recipe->title($title);
  my $categories = join ' ', @{ $recipe->categories };
  my $words = lc "$title $categories";
  $mousse->add($recipe->title, $recipe, $words);
}
$mousse->write;

$mousse = Search::Mousse->new(
  directory => $directory,
  name      => 'recipes',
  stemmer   => \&stemmer,
);

my $recipe = $mousse->fetch("Hearty Russian Beet Soup");
ok(!$recipe);

$recipe = $mousse->fetch("Hearty russian beet soup");
is($recipe->title, "Hearty russian beet soup");

$recipe = $mousse->fetch("Chiles rellenos casserole");
is($recipe->title, "Chiles rellenos casserole");

$recipe = $mousse->fetch("Crumb topping mix");
is($recipe->title, "Crumb topping mix");

my @search = $mousse->search("crumb");
is_deeply([sort map { $_->title } @search ], [
  'Cookie crumb crust mix',
  'Crumb topping mix',
]);

@search = $mousse->search_keys("italian");
is_deeply([sort @search ], [
  'Italian cooking sauce mix',
  'Italian meat sauce mix',
  'Italian minestrone soup coca-cola',
]);

@search = $mousse->search_keys("italiaan soos");
is_deeply([sort @search], [
  'Italian cooking sauce mix',
  'Italian meat sauce mix',
]);

sub stemmer {
  my $words = lc shift;
  my @words = uniq(split / /, $words);
  @words = grep { defined } soundex(@words);
  return @words;
}
