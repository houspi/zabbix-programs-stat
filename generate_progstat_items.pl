#!/usr/bin/perl -w

use strict;

#
# Write your process list here.
my %processes = (
    'auth' => 'Dovecot auth',
    'dovecot' => 'Dovecot',
    'exim' => 'Exim',
    'httpd|apach' => 'Apache',
#    'httpd' => 'Apache',
#    'apach' => 'Apache',
    'master' => 'Postfix',
    'mysql' => 'Mysql',
    'nginx' => 'Nginx',
    'postgres' => 'PostgreSQL',
    'PassengerAgent' => 'Phusion Passenger',
    'nmbd' => 'Samba NetBIOS',
    'smbd' => 'Samba',
    'winbind' => 'Samba NSS',
# combine all Samba services into one item
# comment out previous three lines and uncomment next one
#    'smbd|nmbd|winbind' => 'Samba',
    'zabbix_agent' => 'Zabbix agent',
    'zabbix_server' => 'Zabbix server',
);

my %metrics = (
    cpu_user    =>  {   name => 'CPU User',
                        value_type => 0,
                        check_delay => '1m',
                        aggregate_functions => ['sum'],
                    },
    cpu_system  =>  {   name => 'CPU System',
                        value_type => 0,
                        check_delay => '1m',
                        aggregate_functions => ['sum'],
                    },
    ioread      =>  {   name => 'IO Read',
                        value_type => 3,
                        check_delay => '1m',
                        aggregate_functions => ['sum'],
                    },
    iowrite     =>  {   name => 'IO Write',
                        value_type => 3,
                        check_delay => '1m',
                        aggregate_functions => ['sum'],
                    },
    pmem        =>  {   name => 'MEM %',
                        value_type => 0,
                        check_delay => '5m',
                        aggregate_functions => ['sum'],
                    },
    rss         =>  {   name => 'MEM Rss',
                        value_type => 3,
                        check_delay => '5m',
                        aggregate_functions => ['sum'],
                    },
    vsz         =>  {   name => 'MEM Vsz',
                        value_type => 3,
                        check_delay => '5m',
                        aggregate_functions => ['sum', 'max'],
                    },
    count       =>  {   name => 'Processes Count',
                        value_type => 3,
                        check_delay => '5m',
                        aggregate_functions => ['count'],
                    },
);

print "Generate xml...\n";

my $ItemTemplateFile = 'item_template.tmpl';
my $ProcessTemplateFile = 'TemplateProcessInformation.tmpl';
my $ProcessTemplateFileXml = 'TemplateProcessInformation.xml';

print "$ProcessTemplateFileXml\n";

my $ItemTemplate;
open(TMPL, $ItemTemplateFile) or die "Can't open $ItemTemplateFile\n";
{
  undef $/;
  $ItemTemplate = <TMPL>;
}
close TMPL;

my $TemplateProcessInformationContent;
open(TMPL, $ProcessTemplateFile) or die "Can't open $ProcessTemplateFile\n";
{
  undef $/;
  $TemplateProcessInformationContent = <TMPL>;
}
close TMPL;

my @Items;
foreach my $process ( sort keys %processes ) {
    foreach my $metric ( sort keys %metrics ) {
        foreach my $aggregate_function ( sort @{$metrics{$metric}->{aggregate_functions}} ) {
            my $item = $ItemTemplate;
            $item =~ s/%PROCESSNAME%/$processes{$process}/g;
            $item =~ s/%METRICNAME%/$metrics{$metric}->{name}/g;
            my $process_key = $process =~ /\|/ ? "'" . $process . "'" : $process;
            $item =~ s/%PROCESS%/$process_key/g;
            $item =~ s/%METRIC%/$metric/g;
            $item =~ s/%METRICAGGREGATE%/$aggregate_function/g;
            $item =~ s/%CHECKDELAY%/$metrics{$metric}->{check_delay}/g;
            $item =~ s/%VALUETYPE%/$metrics{$metric}->{value_type}/g;
            push(@Items, $item);
        }
    }
}
$TemplateProcessInformationContent =~ s/%ITEMS%/join("", @Items)/e;
open(TMPL, ">$ProcessTemplateFileXml") or die "Can't create $ProcessTemplateFileXml\n";
print TMPL $TemplateProcessInformationContent;
close TMPL;
print "done\n";
