# MAPLAT  (C) 2008-2010 Rene Schickbauer
# Developed under Artistic license
# for Magna Powertrain Ilz
package Maplat::Web::ComputerDB;
use strict;
use warnings;

# ------------------------------------------
# MAPLAT - Magna ProdLan Administration Tool
# ------------------------------------------

our $VERSION = 0.994;

#=!=START-AUTO-INCLUDES
use Maplat::Web::ComputerDB::Computers;
use Maplat::Web::ComputerDB::GlobalCostunits;
use Maplat::Web::ComputerDB::GlobalOperatingSystem;
use Maplat::Web::ComputerDB::GlobalProdlines;
#=!=END-AUTO-INCLUDES

1;
__END__

=head1 NAME

Maplat::Web::ComputerDB - Include the Maplat::Web::ComputerDB plugins

=head1 SYNOPSIS

This file loads all the required plugins for Maplat::Web::ComputerDB. It should
be included before configuring the modules.
  
  use Maplat::Web;
  use Maplat::Web::ComputerDB;

=head1 DESCRIPTION

This file loads all the required plugins for Maplat::Web::ComputerDB. It should
be included before configuring the modules.


=head1 SEE ALSO

Maplat::Web::ComputerDB::Computers
Maplat::Web::ComputerDB::GlobalCostunits
Maplat::Web::ComputerDB::GlobalOperatingSystem
Maplat::Web::ComputerDB::GlobalProdlines

=head1 AUTHOR

Rene Schickbauer, E<lt>rene.schickbauer@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2010 by Rene Schickbauer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
