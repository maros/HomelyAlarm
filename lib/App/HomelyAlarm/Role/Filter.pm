# ============================================================================
package App::HomelyAlarm::Role::Filter;
# ============================================================================
use utf8;

use namespace::autoclean;
use Moose::Role;

sub for_filter {
    my ($self) = @_;
    my %filter;
    my $meta = $self->meta;
    foreach my $attribute ($meta->get_all_attributes) {
        next
            unless $attribute->does('Filter');
        my $name = $attribute->name;
        $filter{$name} = $self->$name;
    }
    return %filter;
}

1;