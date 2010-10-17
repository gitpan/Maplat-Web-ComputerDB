# MAPLAT  (C) 2008-2010 Rene Schickbauer
# Developed under Artistic license
# for Magna Powertrain Ilz

package Maplat::Web::ComputerDB::GlobalCostunits;
use strict;
use warnings;

use base qw(Maplat::Web::BaseModule);
use Maplat::Helpers::DateStrings;

our $VERSION = 0.994;

use Carp;

sub new {
    my ($proto, %config) = @_;
    my $class = ref($proto) || $proto;
    
    my $self = $class->SUPER::new(%config); # Call parent NEW
    bless $self, $class; # Re-bless with our class
    
    return $self;
}

sub reload {
    my ($self) = shift;
    
    # Nothing to do.. in here, we only use the template and database module
	return;
}

sub register {
    my $self = shift;
    $self->register_webpath($self->{webpath}, "get");
	return;
}


sub get {
    my ($self, $cgi) = @_;

    my $dbh = $self->{server}->{modules}->{$self->{db}};
    my $memh = $self->{server}->{modules}->{$self->{memcache}};

    my %webdata = 
    (
        $self->{server}->get_defaultwebdata(),
        PageTitle   =>  $self->{pagetitle},
        webpath    =>  $self->{webpath},
    );


    my $mode = $cgi->param("mode") || "view";
    if($mode eq "createline") {
        my $name = $cgi->param("costunit") || "";
        my $lineid = $cgi->param("line_id") || "";
        my $description = $cgi->param("description") || "";
        my $coords = $cgi->param("coordinates") || "";
        my @coordinates;
        my @parts = split/,/,$coords;
        foreach my $part (@parts) {
            $part = uc $part;
            $part =~ s/[^A-Z0-9]//go;
            push @coordinates, $part;
        }
        
        if($name ne "") {
            my $sth = $dbh->prepare_cached("INSERT INTO prodlines_global_costunits (costunit, line_id, description, coordinates)
                                           VALUES (?, ?, ?, ?)")
                        or croak($dbh->errstr);
            my $ok = 1;
            
            if(!$sth->execute($name, $lineid, $description, \@coordinates)) {
                $ok = 0;
            }
            
            if($ok) {
                $sth->finish;
                $dbh->commit;
                $webdata{statustext} = "Cost unit created";
                $webdata{statuscolor} = "oktext";
            } else {
                $webdata{statustext} = "Sorry, didn't work";
                $webdata{statuscolor} = "errortext";
                $dbh->rollback;
            }
        }
    } elsif($mode eq "changeline") {
        my $name = $cgi->param("costunit") || "";
        my $lineid = $cgi->param("line_id") || "";
        my $description = $cgi->param("description") || "";
        my $coords = $cgi->param("coordinates") || "";
        my @coordinates;
        my @parts = split/,/,$coords;
        foreach my $part (@parts) {
            $part = uc $part;
            $part =~ s/[^A-Z0-9]//go;
            push @coordinates, $part;
        }        
        if($name ne "") {
            my $sth = $dbh->prepare_cached("UPDATE prodlines_global_costunits
                                           SET description = ?,
                                           coordinates = ?,
                                           line_id = ?
                                           WHERE costunit = ?")
                        or croak($dbh->errstr);
            if($sth->execute($description, \@coordinates, $lineid, $name)) {
                $sth->finish;
                $dbh->commit;
                $webdata{statustext} = "Cost unit updated";
                $webdata{statuscolor} = "oktext";
            } else {
                $webdata{statustext} = "Sorry, didn't work";
                $webdata{statuscolor} = "errortext";
                $dbh->rollback;
            }
        }
    } elsif($mode eq "deleteline") {
        my $name = $cgi->param("costunit") || "";
        if($name ne "") {
            my $sth = $dbh->prepare_cached("DELETE FROM prodlines_global_costunits
                                           WHERE costunit = ?")
                        or croak($dbh->errstr);
            if($sth->execute($name)) {
                $sth->finish;
                $dbh->commit;
                $webdata{statustext} = "Cost unit deleted";
                $webdata{statuscolor} = "oktext";
            } else {
                $webdata{statustext} = "Sorry, didn't work";
                $webdata{statuscolor} = "errortext";
                $dbh->rollback;
            }
        }
    }
    
    my $stmt = "SELECT * " .
                "FROM prodlines_global_costunits " .
                "ORDER BY costunit";

    my @units;
    my $sth = $dbh->prepare_cached($stmt) or croak($dbh->errstr);
                
    $sth->execute or croak($dbh->errstr);
    while((my $unit = $sth->fetchrow_hashref)) {
        $unit->{coords} = join(',', @{$unit->{coordinates}});
        push @units, $unit;
    }
    $sth->finish;

    my $lstmt = "SELECT * " .
                "FROM prodlines_global " .
                "ORDER BY line_id";

    my @lines;
    my $lsth = $dbh->prepare_cached($lstmt) or croak($dbh->errstr);
                
    $lsth->execute or croak($dbh->errstr);
    while((my $line = $lsth->fetchrow_hashref)) {
        push @lines, $line;
    }
    $sth->finish;
    $dbh->rollback;

    $webdata{costunits} = \@units;
    $webdata{lines} = \@lines;
    
    my $template = $self->{server}->{modules}->{templates}->get("computerdb/globalcostunits", 1, %webdata);
    return (status  =>  404) unless $template;
    return (status  =>  200,
            type    => "text/html",
            data    => $template);
}


1;
__END__

=head1 NAME

Maplat::Web::ComputerDB::GlobalCostunits - manage a list of cost units

=head1 SYNOPSIS

  use Maplat::Web;
  use Maplat::Web::ComputerDB;
  
Then configure() the module as you would normally.

=head1 DESCRIPTION

    <module>
        <modname>globalcostunits</modname>
        <pm>ComputerDB::GlobalCostunits</pm>
        <options>
            <pagetitle>GlobalCostunits</pagetitle>
            <webpath>/computers/costunits</webpath>
            <db>maindb</db>
            <memcache>memcache</memcache>
        </options>
    </module>

This module provides the webmasks required to edit and list cost units in the database.

=head2 get

Internal function, renders cost units mask.

=head1 AUTHOR

Rene Schickbauer, E<lt>rene.schickbauer@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2010 by Rene Schickbauer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
