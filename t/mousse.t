#!perl
use strict;
use File::Path;
use MealMaster;
use Test::More tests => 9;
use_ok("Search::Mousse");
use_ok("Search::Mousse::Writer");

my $directory = "t/tmp";
rmtree($directory);
mkdir($directory) || die $!;

my $mousse = Search::Mousse::Writer->new(
  directory => $directory,
  name      => 'recipes',
);

my $mm = MealMaster->new;
my @recipes = $mm->parse("t/0222-1.TXT");
foreach my $recipe (@recipes) {
  my $title = ucfirst(lc($recipe->title));
  $recipe->title($title);
  my $categories = join ' ', @{ $recipe->categories };
  $mousse->add($recipe->title, $recipe, "$title $categories");
}
$mousse->write;

$mousse = Search::Mousse->new(
  directory => $directory,
  name      => 'recipes',
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

@search = $mousse->search_keys("italian sauce");
is_deeply([sort @search], [
  'Italian cooking sauce mix',
  'Italian meat sauce mix',
]);

__END__

my $cg = Search::ContextGraph->new(auto_reweight => 0);

while (my($id, $recipe) = each %{$mousse->id_to_value}) {
  my $title      = $recipe->title;
  my $id         = $mousse->key_to_id($title);
  my $categories = join ' ', @{ $recipe->categories };
  my @words      = split / /, lc "$title $categories";
  eval { $cg->add($id, \@words) };
}
$cg->reweight_graph();

my %related_recipes;
foreach $recipe ($mousse->all_values) {
  isa_ok($recipe, "MealMaster::Recipe");
  my $title      = $recipe->title;
  my $id         = $mousse->key_to_id($title);
  my(@ids);
  eval {
      local $SIG{ALRM} = sub { die "alarm\n" };
      alarm 1;
      my ($docs, $words) = $cg->find_similar($id);
      foreach my $k (sort { $docs->{$b} <=> $docs->{$a} } keys %$docs) {
          next if $k eq $id;
          push @ids, $k;
      }
      @ids = splice(@ids, 0, 20);
      alarm 0;
  };
  $related_recipes{$id} = \@ids;
}
