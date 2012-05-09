#! perl

use strict;
use warnings;
use Test::More 0.88;
use Test::Differences;

use CPAN::Meta;
use CPAN::Meta::Check qw/check_requirements verify_dependencies/;

my %prereq_struct = (
	runtime => {
		requires => {
			'Config'     => 0,
			'File::Spec' => 0,
			'IO::File'	 => 0,
			'perl'			 => '5.005_03',
		},
		recommends => {
			'Pod::Text' => 0,
			'This::Should::Be::NonExistent' => 1,
			Carp => 99999,
		},
	},
	build => {
		requires => {
			'Test' => 0,
		},
	},
);

my $meta = CPAN::Meta->create({ prereqs => \%prereq_struct, version => 1, name => 'Foo'  }, { lazy_validation => 1 });

eq_or_diff([ verify_dependencies($meta, 'runtime', 'requires') ], [], 'Requirements are verified');

my $pre_req = $meta->effective_prereqs->requirements_for('runtime', 'requires');
is($pre_req->required_modules, 4, 'Requires 4 modules');
eq_or_diff(check_requirements($pre_req, 'requires'), { map { ( $_ => undef ) } qw/Config File::Spec IO::File perl/ }, 'Requirements are satisfied ');

my $pre_rec = $meta->effective_prereqs->requirements_for('runtime', 'recommends');
eq_or_diff([ sort +$pre_rec->required_modules ], [ qw/Carp Pod::Text This::Should::Be::NonExistent/ ], 'The right recommendations are present');
eq_or_diff(check_requirements($pre_rec, 'recommends'), { Carp => "Installed version ($Carp::VERSION) of Carp is not in range '99999'", 'Pod::Text' => undef, 'This::Should::Be::NonExistent' => 'Module \'This::Should::Be::NonExistent\' is not installed' }, 'Recommendations give the right errors');

done_testing();
