package CPAN::Meta::Check;
use strict;
use warnings;

use Exporter 5.57 'import';
our @EXPORT = qw//;
our @EXPORT_OK = qw/check_requirements requirements_for verify_dependencies/;
our %EXPORT_TAGS = (all => [ @EXPORT, @EXPORT_OK ] );

use CPAN::Meta;
use Module::Metadata;
use Version::Requirements;

sub _check_dep {
	my ($reqs, $module) = @_;

	my $version = $module eq 'perl' ? $] : do { 
		my $metadata = Module::Metadata->new_from_module($module);
		return "Module '$module' is not installed" if not defined $metadata;
		eval { $metadata->version };
	};
	return "Missing version info for module '$module'" if $reqs->as_string_hash->{$module} and not $version;
	return sprintf 'Installed version (%s) of %s is not in range \'%s\'', $version, $module, $reqs->as_string_hash->{$module} if not $reqs->accepts_module($module, $version || 0);
	return;
}

sub _check_conflict {
	my ($reqs, $module) = @_;
	my $metadata = Module::Metadata->new_from_module($module);
	return if not defined $metadata;
	my $version = eval { $metadata->version };
	return "Missing version info for module '$module'" if not $version;
	return sprintf 'Installed version (%s) of %s is in range \'%s\'', $version, $module, $reqs->as_string_hash->{$module} if $reqs->accepts_module($module, $version);
	return;
}

sub requirements_for {
	my ($meta, $phases, $type) = @_;
	if (!ref $phases) {
		return $meta->effective_prereqs->requirements_for($phases, $type);
	}
	else {
		my $ret = Version::Requirements->new;
		for my $phase (@{ $phases }) {
			$ret->add_requirements($meta->effective_prereqs->requirements_for($phase, $type));
		}
		return $ret;
	}
}

sub check_requirements {
	my ($reqs, $type) = @_;

	my %ret;
	if ($type ne 'conflicts') {
		for my $module ($reqs->required_modules) {
			$ret{$module} = _check_dep($reqs, $module);
		}
	}
	else {
		for my $module ($reqs->required_modules) {
			$ret{$module} = _check_conflict($reqs, $module);
		}
	}
	return \%ret;
}

sub verify_dependencies {
	my ($meta, $phases, $type) = @_;
	my $reqs = requirements_for($meta, $phases, $type);
	my $issues = check_requirements($reqs, $type);
	return grep { defined } values %{ $issues };
}

1;

#ABSTRACT: Verify requirements in a CPAN::Meta object

__END__

=head1 SYNOPSIS

 warn "$_\n" for verify_requirements($meta, [qw/runtime build test/], 'requires');

=head1 DESCRIPTION

This module verifies if modules are 

=func check_requirements($reqs, $type)

This function checks if all dependencies in C<$reqs> (a L<Version::Requirements|Version::Requirements> object) are met, taking into account that 'conflicts' dependencies have to be checked in reverse. It returns a hash with the modules as values and any problems as keys, the value for a succesfully found module will be undef.

=func verify_requirements($meta, $phases, $types)

Check all requirements in C<$meta> for phases C<$phases> and types C<$types>.

=func requirements_for($meta, $phases, $types)

This function returns a unified L<Version::Requirements|Version::Requirements> object for all C<$type> requirements for C<$phases>. $Phases may be either one (scalar) value or an arrayref of valid values as defined by the L<CPAN::Meta spec|CPAN::Meta::Spec>. C<$type> must be a a relationship as defined by the same spec.

