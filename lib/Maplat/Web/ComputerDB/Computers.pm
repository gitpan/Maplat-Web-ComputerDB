# MAPLAT  (C) 2008-2010 Rene Schickbauer
# Developed under Artistic license
# for Magna Powertrain Ilz

package Maplat::Web::ComputerDB::Computers;
use strict;
use warnings;

use 5.010;
use base qw(Maplat::Web::BaseModule);

use Maplat::Helpers::DateStrings;
use Maplat::Helpers::Padding qw(doFPad);
use PDF::Report;


our $VERSION = 0.994;

use Carp;

my @keynames = qw[old_computer_name computer_name costunit description net_internal_type net_internal_ip net_internal_mac
                             net_prod_type net_prod_ip net_prod_mac computer_domain account_user account_password
                             account_domain lastedit_time lastedit_user operating_system servicepack is_64bit
                             has_antivirus];

my @domains = qw[SGI SGI2 WIS NONE];
my @networktypes = qw[LAN WLAN NONE];

sub new {
    my ($proto, %config) = @_;
    my $class = ref($proto) || $proto;
    
    my $self = $class->SUPER::new(%config); # Call parent NEW
    bless $self, $class; # Re-bless with our class
    
    return $self;
}

sub reload {
    my ($self) = shift;
    # Nothing to do
    return;
}

sub register {
    my $self = shift;
    $self->register_webpath($self->{computeredit}->{webpath}, "get_edit");
    $self->register_webpath($self->{computerselect}->{webpath}, "get_select");
    $self->register_webpath($self->{pdflist}->{webpath}, "get_pdflist");
    $self->register_loginitem("on_login");
    return;
}

sub on_login {
    my ($self, $username, $sessionid) = @_;
    
    my $sesh = $self->{server}->{modules}->{$self->{session}};
    
    # Select Cardreader as default
    $sesh->set("SelectedComputer", "new");
    return;
}

sub get_edit {
    my ($self, $cgi) = @_;

    my $dbh = $self->{server}->{modules}->{$self->{db}};
    my $memh = $self->{server}->{modules}->{$self->{memcache}};
    my $sesh = $self->{server}->{modules}->{$self->{session}};
    
    my $host_addr = $cgi->remote_addr();
    my $mode = $cgi->param('mode') || 'new';
    
    my %webdata = 
    (
        $self->{server}->get_defaultwebdata(),
        PageTitle       =>  $self->{computeredit}->{pagetitle},
        webpath            =>  $self->{computeredit}->{webpath},
        ComputerSelect    =>    $self->{computerselect}->{webpath},
        domains            => \@domains,
        networktypes    => \@networktypes,
    );
    
    my %computer;
    if($mode ne "new") {
        # Get parameters from webform
        foreach my $keyname (@keynames) {
            if(!defined($computer{$keyname})) {
                $computer{$keyname} = $cgi->param($keyname) || '';
                given($keyname) {
                    when(/^(is_|has_)/o) {
                        if($computer{$keyname} eq "on") {
                            $computer{$keyname} = 1;
                        } else {
                            $computer{$keyname} = 0;
                        }
                    }
                    when(/^net_.*_ip/o) {
                        if($computer{$keyname} eq "") {
                            $computer{$keyname} = "0.0.0.0";
                        }
                    }
                    when(/^net_.*_mac/o) {
                        if($computer{$keyname} eq "") {
                            $computer{$keyname} = "00:00:00:00:00:00";
                        } else {
                            $computer{$keyname} =~ s/\-/:/go;
                        }
                    }
                    when("servicepack") {
                        if(defined($computer{$keyname})) {
                            $computer{$keyname} = $computer{$keyname} + 0;
                        } else {
                            $computer{$keyname} = 0;
                        }
                    }
                }
            }
        }
    }
    
    # Handle standard POST requests
    given($mode) {
        when("delete") {
            my $sth = $dbh->prepare("DELETE FROM computers
                                           WHERE computer_name = ?")
                    or croak($dbh->errstr);
            if($sth->execute($computer{old_computer_name})) {
                $sth->finish;
                $dbh->commit;
                $webdata{statustext} = "Computer deleted";
                $webdata{statuscolor} = "oktext";
            } else {
                $dbh->rollback;
                $webdata{statustext} = "Deletion failed";
                $webdata{statuscolor} = "errortext";
            }
            $mode = 'new';
        }
        when("create") {
            my @fields;
            my @values;
            foreach my $keyname (@keynames) {
                next if($keyname eq "old_computer_name");
                push @fields, $keyname;
                if(!defined($computer{$keyname})) {
                    $computer{$keyname} = "";
                }
                if($keyname eq "lastedit_time") {
                    push @values, "now()";
                } elsif($keyname eq "lastedit_user") {
                    push @values, $dbh->quote($webdata{userData}->{user});
                } elsif($keyname =~ /^(is_|has_)/) {
                    if($computer{$keyname} == 1) {
                        push @values, "'true'";
                    } else {
                        push @values, "'false'";
                    }

                } else {
                    push @values, $dbh->quote($computer{$keyname});
                }
            }

            my $stmt = "INSERT INTO computers (" . join(',', @fields) . ") " .
                        " VALUES (" . join(',', @values) . ")";

            my $sth = $dbh->prepare($stmt)
                    or croak($dbh->errstr);
            if($sth->execute()) {
                $sth->finish;
                $dbh->commit;
                $webdata{statustext} = "Computer created";
                $webdata{statuscolor} = "oktext";
                $mode = "edit";
            } else {
                $dbh->rollback;
                $webdata{statustext} = "Creation failed";
                $webdata{statuscolor} = "errortext";
                $mode = "create";
            }
        }
        when("edit") {
            my @fields;
            foreach my $keyname (@keynames) {
                next if($keyname eq "old_computer_name");
                my $field = "$keyname = ";
                if(!defined($computer{$keyname})) {
                    $computer{$keyname} = "";
                }
                if($keyname eq "lastedit_time") {
                    $field .= "now()";
                } elsif($keyname eq "lastedit_user") {
                    $field .= $dbh->quote($webdata{userData}->{user});
                } elsif($keyname =~ /^(is_|has_)/) {
                    if($computer{$keyname} == 1) {
                        $field .= "'true'";
                    } else {
                        $field .= "'false'";
                    }
                } else {
                    $field .= $dbh->quote($computer{$keyname});
                }
                push @fields, $field;
            }

            my $stmt = "UPDATE computers SET " . join(',', @fields) .
                        " WHERE computer_name = " . $dbh->quote($computer{old_computer_name});

            my $sth = $dbh->prepare($stmt)
                    or croak($dbh->errstr);
            if($sth->execute()) {
                $sth->finish;
                $dbh->commit;
                $webdata{statustext} = "Computer updated";
                $webdata{statuscolor} = "oktext";
            } else {
                $dbh->rollback;
                $webdata{statustext} = "Creation updated";
                $webdata{statuscolor} = "errortext";
            }
            $mode = "edit";
        }
        when("select") {
            my $stmt = "SELECT * FROM computers " .
                        "WHERE computer_name = ?";
            my $sth = $dbh->prepare($stmt)
                    or croak($dbh->errstr);
            if(!$sth->execute($computer{old_computer_name})) {
                $dbh->rollback;
                $webdata{statustext} = "Can't load computer";
                $webdata{statuscolor} = "errortext";
                $mode = "new";
            } else {
                my $line = $sth->fetchrow_hashref;
                $sth->finish;
                $dbh->rollback;
                if(defined($line)) {
                    foreach my $keyname (@keynames) {
                        next if($keyname eq "old_computer_name");
                        if(!defined($line->{$keyname})) {
                            $computer{$keyname} = "";
                        } else {
                            $computer{$keyname} = $line->{$keyname};
                        }
                    }
                    $mode = "edit";    
                } else {
                    $webdata{statustext} = "Can't load computer";
                    $webdata{statuscolor} = "errortext";
                    $mode = "new";
                }
            }
        }
    }
    

    if($mode eq "new") {
        my %defaultcomputer = (
            net_internal_type        => 'LAN',
            net_prod_type        => 'LAN',
            computer_domain        => 'SGI2',
            account_domain        => 'SGI2',
            is_64bit            => 0,
            has_antivirus        => 1,
        );
        foreach my $keyname (@keynames) {
            if(!defined($defaultcomputer{$keyname})) {
                $defaultcomputer{$keyname} = "";
            }
        }
        $webdata{computer} = \%defaultcomputer;
        $mode = "create";
    } else {
        # Beautify a bit
        if($computer{net_internal_ip} eq "0.0.0.0") {
            $computer{net_internal_ip} = "";
        }
        if($computer{net_prod_ip} eq "0.0.0.0") {
            $computer{net_prod_ip} = "";
        }
        if($computer{net_internal_mac} eq "00:00:00:00:00:00") {
            $computer{net_internal_mac} = "";
        }
        if($computer{net_prod_mac} eq "00:00:00:00:00:00") {
            $computer{net_prod_mac} = "";
        }
        $webdata{computer} = \%computer;
    }
    $webdata{EditMode} = $mode;
    
    my $ossth = $dbh->prepare_cached("SELECT * FROM computers_os
                                     ORDER BY operating_system")
            or croak($dbh->errstr);
    $ossth->execute() or croak($dbh->errstr);
    my @oss;
    while((my $line = $ossth->fetchrow_hashref)) {
        push @oss, $line;
    }
    $webdata{operating_systems} = \@oss;
    
    my $custh = $dbh->prepare_cached("SELECT * FROM prodlines_global_costunits
                                 ORDER BY costunit")
        or croak($dbh->errstr);
    $custh->execute() or croak($dbh->errstr);
    my @costunits;
    while((my $line = $custh->fetchrow_hashref)) {
        push @costunits, $line;
    }
    $webdata{costunits} = \@costunits;
    
    my $template = $self->{server}->{modules}->{templates}->get("computerdb/computers_edit", 1, %webdata);
    return (status  =>  404) unless $template;
    return (status  =>  200,
            type    => "text/html",
            data    => $template);
}


# "get_select" actually only displays the available card list, POST
# is done to the main mask to have a smoother workflow without redirects
sub get_select {
    my ($self, $cgi) = @_;

    my $dbh = $self->{server}->{modules}->{$self->{db}};
    my $memh = $self->{server}->{modules}->{$self->{memcache}};
    my $sesh = $self->{server}->{modules}->{$self->{session}};
    
    my $mode = $cgi->param('mode') || 'view';
    
    if($mode eq "view") {
        my $sth = $dbh->prepare_cached("SELECT *, co.description co_description
                                       FROM computers co, prodlines_global_costunits cu
                                       WHERE co.costunit = cu.costunit
                                       ORDER BY computer_name")
                    or croak($dbh->errstr);
        my @computers;
        
        if($sth->execute) {
            while((my $line = $sth->fetchrow_hashref)) {
                push @computers, $line;
            }
        }
        
    
        my $pdfpath =  $self->{pdflist}->{webpath} . '/' .
                int(rand(10000)) . '_' .
                int(rand(10000)) . '_';
        
        my %webdata = 
        (
            $self->{server}->get_defaultwebdata(),
            PageTitle   =>  $self->{computerselect}->{pagetitle},
            webpath        =>  $self->{computerselect}->{webpath},
            pdflist            =>    $pdfpath,
            computers        =>  \@computers,
        );
        
        my $template = $self->{server}->{modules}->{templates}->get("computerdb/computers_select", 1, %webdata);
        return (status  =>  404) unless $template;
        return (status  =>  200,
                type    => "text/html",
                data    => $template);
    } else {
        return $self->get_edit($cgi);
    }
}

sub get_pdflist {
    my ($self, $cgi) = @_;

    my $dbh = $self->{server}->{modules}->{$self->{db}};
    
        my $pdf = PDF::Report->new(PageSize          => "A4", 
                                PageOrientation => "Portrait",
                                );
    
    my ($pagewidth, $pageheight) = $pdf->getPageDimensions();
    
    my $pagecount = 1;
    
    my $usth = $dbh->prepare_cached("SELECT *, co.description co_description
                               FROM computers co, prodlines_global_costunits cu
                               WHERE co.costunit = cu.costunit
                               ORDER BY line_id, computer_name")
            or croak($dbh->errstr);
    
    $usth->execute() or croak($dbh->errstr);

    my $z = $pageheight;
        
    $pdf->setFont('Arial');

    my @computers;
    my %convert = (
        'ä'    => 'ae',
        'ö'    => 'oe',
        'ü'    => 'ue',
        'Ä'    => 'Ae',
        'Ö'    => 'Oe',
        'Ü'    => 'Ue',
        'ß'    => 'ss',
    );
    while((my $computer = $usth->fetchrow_hashref)) {
        foreach my $key (keys %convert) {
            my $val = $convert{$key};
            $computer->{co_description} =~ s/$key/$val/g;
        }
        push @computers, $computer;

        if($z == $pageheight) {
            $pdf->newpage(1);
            $z -= 20;
        
            if(defined($self->{pdflist}->{logo})) {
                $pdf->addImg($self->{pdflist}->{logo}, 40, $z - 58);
            }
        
            $pdf->setSize(10);
            $pdf->addRawText("Page $pagecount", $pagewidth - 150, 20, "grey");
            $pdf->addRawText(getISODate(), 40, 20, "grey");
            $pdf->setSize(30);
            $z -= 110;
            $pdf->addRawText("Computer list", 100, $z, "black", 0);
            $z -= 40;
            $pdf->setSize(12);
            $pdf->addRawText("ProdLine", 40, $z, "black");
            $pdf->addRawText("Hostname", 115, $z, "black");
            $pdf->addRawText("Operating System", 200, $z, "black");
            $pdf->addRawText("Description", 360, $z, "black");
            
            $z -= 14;
        }    

        $pdf->setSize(12);
        $pdf->addRawText($computer->{line_id}, 40, $z, "black");
        $pdf->addRawText($computer->{computer_name}, 115, $z, "black");
        my $osname = $computer->{operating_system} . ' SP ' . $computer->{servicepack};
        $pdf->addRawText($osname, 200, $z, "black");
        $pdf->addRawText($computer->{co_description}, 360, $z, "black");
        $z -= 14;
    
        if($z < 60) {
            $pagecount++;
            $z = $pageheight;
        }
    }

    $usth->finish;
    $dbh->rollback;
    
    # Add "computer data sheet"
    if($z != $pageheight) {
        $pagecount++;
        $z = $pageheight;
    }
    
    if(1) {
    foreach my $computer (@computers) {
            $pdf->newpage(1);
            $z = $pageheight - 20;
        
            if(defined($self->{pdflist}->{logo})) {
                $pdf->addImg($self->{pdflist}->{logo}, 40, $z - 58);
            }
        
            $pdf->setSize(10);
            $pdf->addRawText("Page $pagecount", $pagewidth - 150, 20, "grey");
            $pdf->addRawText(getISODate(), 40, 20, "grey");
            $pdf->setSize(30);
            $z -= 110;
            $pdf->addRawText("Computer data sheet", 100, $z, "black", 0);
            $z -= 40;
            $pdf->addRawText($computer->{line_id}, 40, $z, "black");
            $pdf->addRawText($computer->{computer_name}, 200, $z, "black");
            
            # ------------- COMPUTER -----------
            $z -= 50;
            $pdf->setSize(20);
            $pdf->addRawText("Computer", 40, $z, "black", 0);
            $z -= 24;
            $pdf->setSize(12);
            $pdf->addRawText("Hostname: " . $computer->{computer_name}, 40, $z, "black");
            $z -= 14;
            $pdf->addRawText("Location: " . $computer->{line_id}, 40, $z, "black");
            $z -= 14;
            $pdf->addRawText("Cost Unit: " . $computer->{costunit}, 40, $z, "black");
            $z -= 14;
            $pdf->addRawText("Description: " . $computer->{co_description}, 40, $z, "black");
            $z -= 14;
            
            # --------------- OS ----------------
            $z -= 20;
            $pdf->setSize(20);
            $pdf->addRawText("Operating System", 40, $z, "black", 0);
            $z -= 24;
            $pdf->setSize(12);
            $pdf->addRawText("OS: " . $computer->{operating_system}, 40, $z, "black");
            $z -= 14;
            $pdf->addRawText("Servicepack: " . $computer->{servicepack}, 40, $z, "black");
            $z -= 14;
            if($computer->{is_64bit}) {
                $pdf->addRawText("32/64 Bit: 64 Bit", 40, $z, "black");
            } else {
                $pdf->addRawText("32/64 Bit: 32 Bit", 40, $z, "black");
            }
            $z -= 14;
            if($computer->{has_antivirus}) {
                $pdf->addRawText("AntiVirus: McAfee Antivirus", 40, $z, "black");
            } else {
                $pdf->addRawText("AntiVirus: none", 40, $z, "black");
            }
            $z -= 14;

            # --------------- Domain ----------------
            $z -= 20;
            $pdf->setSize(20);
            $pdf->addRawText("Domain", 40, $z, "black", 0);
            $z -= 24;
            $pdf->setSize(12);
            $pdf->addRawText("Computer Domain: " . $computer->{computer_domain}, 40, $z, "black");
            $z -= 14;
            $pdf->addRawText("Login Domain: " . $computer->{computer_domain}, 40, $z, "black");
            $z -= 14;
            $pdf->addRawText("Username: " . $computer->{account_user}, 40, $z, "black");
            $z -= 14;
            $pdf->addRawText("Password: " . $computer->{account_password}, 40, $z, "black");
            $z -= 14;

            # --------------- ext. Network ----------------
            $z -= 20;
            $pdf->setSize(20);
            $pdf->addRawText("ext. Network", 40, $z, "black", 0);
            $z -= 24;
            $pdf->setSize(12);
            $pdf->addRawText("Type: " . $computer->{net_prod_type}, 40, $z, "black");
            $z -= 14;
            $pdf->addRawText("IP: " . $computer->{net_prod_ip}, 40, $z, "black");
            $z -= 14;
            $pdf->addRawText("MAC: " . $computer->{net_prod_mac}, 40, $z, "black");
            $z -= 14;

            # --------------- int. Network ----------------
            $z -= 20;
            $pdf->setSize(20);
            $pdf->addRawText("int. Network", 40, $z, "black", 0);
            $z -= 24;
            $pdf->setSize(12);
            $pdf->addRawText("Type: " . $computer->{net_internal_type}, 40, $z, "black");
            $z -= 14;
            $pdf->addRawText("IP: " . $computer->{net_internal_ip}, 40, $z, "black");
            $z -= 14;
            $pdf->addRawText("MAC: " . $computer->{net_internal_mac}, 40, $z, "black");
            $z -= 14;
            $pagecount++;

    }
    }
    
    
    my $report = $pdf->Finish();
    
    return (status  =>  404) unless $report;
    return (status  =>  200,
        type    => "application/pdf",
        data    => $report);
}

1;
__END__

=head1 NAME

Maplat::Web::ComputerDB::Computers - manage a list of Computers

=head1 SYNOPSIS

  use Maplat::Web;
  use Maplat::Web::ComputerDB;
  
Then configure() the module as you would normally.

=head1 DESCRIPTION

    <module>
        <modname>globalcomputers</modname>
        <pm>ComputerDB::Computers</pm>
        <options>
            <computerselect>
                <webpath>/computers/computerselect</webpath>
                <pagetitle>Computer Select</pagetitle>
            </computerselect>
            <pdflist>
                <webpath>/computers/pdflist</webpath>
                <logo>/path/to/logo/on/pdf.gif</logo>
            </pdflist>
            <computeredit>
                <webpath>/computers/computeredit</webpath>
                <pagetitle>Computer Edit</pagetitle>
            </computeredit>
            <db>maindb</db>
            <memcache>memcache</memcache>
            <session>sessionsettings</session>
        </options>
    </module>

This module provides the webmasks required to edit and list computers in the database and to print a PDF.

=head2 on_login

Internal function, sets some basic states in every login session

=head2 get_edit

Internal function, renders the "Edit computer" mask

=head2 get_select

Internal function, renders the "List Computers" mask

=head2 get_pdflist

Internal function, creates the PDF computer list

=head1 AUTHOR

Rene Schickbauer, E<lt>rene.schickbauer@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2010 by Rene Schickbauer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
