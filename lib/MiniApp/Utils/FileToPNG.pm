package MiniApp::Utils::FileToPNG;
use Moose;
use MooseX::FollowPBP;

use Carp;
use Data::Dumper;
use File::Copy qw(copy);
use File::Glob qw(bsd_glob);
use File::Path qw(make_path);
use File::Slurp qw(read_file);
use File::Temp;
use IO::Handle;
use IO::Select;
use IPC::Open2;
use List::MoreUtils qw(any);
use Mojo::DOM;
use Readonly;
use Scalar::Util qw(blessed);

Readonly my %CONVERT_FOR => (
    '.svg'  => 'convert',
    '.jpg'  => 'convert',
    '.jpeg' => 'convert',
    '.jpe'  => 'convert',
    '.jif'  => 'convert',
    '.jfif' => 'convert',
    '.jfi'  => 'convert',
    '.png'  => 'copy',
    '.pdf'  => 'gs',
    '.odt'  => 'libreoffice_via_pdf',
    '.ods'  => 'libreoffice_via_pdf',
    '.odp'  => 'libreoffice_via_pdf',
    '.odg'  => 'libreoffice_via_pdf',
    '.odg'  => 'libreoffice_via_pdf',
    '.odf'  => 'libreoffice_via_pdf',
    '.od1'  => 'libreoffice_via_pdf',
    '.odm'  => 'libreoffice_via_pdf',
    '.odb'  => 'libreoffice_via_pdf',
    '.odb'  => 'libreoffice_via_pdf',
    '.odb'  => 'libreoffice_via_pdf',
    '.ott'  => 'libreoffice_via_pdf',
    '.ots'  => 'libreoffice_via_pdf',
    '.otp'  => 'libreoffice_via_pdf',
    '.otg'  => 'libreoffice_via_pdf',
    '.otc'  => 'libreoffice_via_pdf',
    '.otf'  => 'libreoffice_via_pdf',
    '.oti'  => 'libreoffice_via_pdf',
    '.oth'  => 'libreoffice_via_pdf',
    '.pdf'  => 'convert',
    '.doc'  => 'libreoffice_via_pdf',
    '.dot'  => 'libreoffice_via_pdf',
    '.docx' => 'libreoffice_via_pdf',
    '.dotx' => 'libreoffice_via_pdf',
    '.docm' => 'libreoffice_via_pdf',
    '.dotm' => 'libreoffice_via_pdf',
    '.xls'  => 'libreoffice_via_pdf',
    '.xlt'  => 'libreoffice_via_pdf',
    '.xla'  => 'libreoffice_via_pdf',
    '.xlsx' => 'libreoffice_via_pdf',
    '.xltx' => 'libreoffice_via_pdf',
    '.xlsm' => 'libreoffice_via_pdf',
    '.xltm' => 'libreoffice_via_pdf',
    '.xlam' => 'libreoffice_via_pdf',
    '.xlsb' => 'libreoffice_via_pdf',
    '.ppt'  => 'libreoffice_via_pdf',
    '.pot'  => 'libreoffice_via_pdf',
    '.pps'  => 'libreoffice_via_pdf',
    '.ppa'  => 'libreoffice_via_pdf',
    '.pptx' => 'libreoffice_via_pdf',
    '.potx' => 'libreoffice_via_pdf',
    '.ppsx' => 'libreoffice_via_pdf',
    '.ppam' => 'libreoffice_via_pdf',
    '.pptm' => 'libreoffice_via_pdf',
    '.potm' => 'libreoffice_via_pdf',
    '.ppsm' => 'libreoffice_via_pdf',
    '.dll'  => 'no_conversion',
    '.exe'  => 'no_conversion',
);

has 'filepath' => (
    'is'      => 'ro',
    'isa'     => 'Str',
    'trigger' => sub {
        my ( $self, $filepath ) = @_;
        confess "File not found: $filepath" if not -f -r $filepath;
        return;
    },
);

has 'converted_filepaths' => (
    'is'  => 'rw',
    'isa' => 'ArrayRef[Str]',
);

has 'tempdir' => (
    'is'      => 'ro',
    'isa'     => 'File::Temp::Dir',
    'default' => sub { File::Temp->newdir },
);

has 'io_select' => (
    'is'      => 'ro',
    'isa'     => 'IO::Select',
    'lazy'    => 1,
    'default' => sub { IO::Select->new },
);

has 'filetype' => (
    'is'      => 'rw',
    'isa'     => 'Str',
    'trigger' => sub {
        my ( $self, $filetype ) = @_;
        confess "Bad filetype: $filetype" if not exists $CONVERT_FOR{$filetype};
        return;
    },
);

sub _execute {
    my ( $self, @args ) = @_;
    warn join ' ', '  >>>', @args;
    my ( $chld_out, $chld_in );
    my $pid = open2( $chld_out, undef, @args );

    my $stdout;
    while ( defined( my $line = readline($chld_out) ) ) {
        $stdout .= $line;
    }

    waitpid( $pid, 0 );
    my $child_exit_status = $? >> 8;

    confess "Can't execute " . join( ' ', @args ) if $child_exit_status != 0;

    return $stdout;
}

sub BUILD {
    my ($self) = @_;

    warn $self->get_filepath, "\n";

    my $filetype = $self->find_filetype( $self->get_filepath );

    confess "Filetype not found for file: " . $self->get_filepath if not defined $filetype;

    $self->set_filetype($filetype);

    return;
}

sub find_filetype {
    my ( $pkg, $filepath ) = @_;

    #while ( my ( $key, $data ) = each %CONVERT_FOR ) {
    foreach my $key ( sort keys %CONVERT_FOR ) {
        my $data = $CONVERT_FOR{$key};
        return $key if $filepath =~ /\Q$key\E$/;
    }

    return;
}

sub convert {
    my ($self) = @_;

    my $data = $CONVERT_FOR{ $self->get_filetype };

    if ( $data eq 'convert' ) {
        return $self->_convert_with_convert( $self->get_filepath );
    } elsif ( $data eq 'gs' ) {
        return $self->_convert_with_gs( $self->get_filepath );
    } elsif ( $data eq 'libreoffice_via_pdf' ) {
        return $self->_convert_with_libreoffice_via_pdf( $self->get_filepath );
    } elsif ( $data eq 'copy' ) {
        return $self->_convert_with_copy( $self->get_filepath );
    } elsif ( $data eq 'no_conversion' ) {
        return $self->_convert_with_no_conversion( $self->get_filepath );
    }

    confess "Can't convert $data for filetype: " . $self->get_filetype;
}

sub _convert_with_libreoffice_via_pdf {
    my ( $self, $filepath ) = @_;

    my $convert_dirpath = File::Spec->join( $self->get_tempdir, 'convert' );
    make_path($convert_dirpath);

    my ( undef, undef, $file ) = File::Spec->splitpath($filepath);

    my $to_convert_filepath = File::Spec->join( $convert_dirpath, $file );

    copy( $filepath, $to_convert_filepath ) or confess "Copy failed: $!";

    $self->_execute(
        'libreoffice3.5', '--invisible',
        '--convert-to' => 'pdf',
        '--outdir'     => $convert_dirpath,
        $to_convert_filepath
    );

    my @pdfs = bsd_glob( File::Spec->join( $convert_dirpath, '*.pdf' ) );
    confess sprintf( "unoconv of %s content-type %s failed", $filepath, $self->get_filetype ) if 1 != @pdfs;

    return $self->_convert_with_gs( $pdfs[0] );

} ## end sub _convert_with_libreoffice_via_pdf

sub _convert_with_copy {
    my ( $self, $filepath ) = @_;

    my $convert_dirpath = File::Spec->join( $self->get_tempdir, 'convert' );
    make_path($convert_dirpath);

    my ( undef, undef, $file ) = File::Spec->splitpath($filepath);

    my $to_convert_filepath = File::Spec->join( $convert_dirpath, $file );

    copy( $filepath, $to_convert_filepath ) or confess "Copy failed: $!";

    confess sprintf( "convert of %s content-type %s failed", $filepath, $self->get_filetype )
          if not -r $to_convert_filepath;

    $self->set_converted_filepaths( [$to_convert_filepath] );

    return;
}

sub _convert_with_convert {
    my ( $self, $filepath ) = @_;

    my $convert_dirpath = File::Spec->join( $self->get_tempdir, 'convert' );
    make_path($convert_dirpath);

    $self->_execute( 'convert', $filepath, File::Spec->join( $convert_dirpath, 'tumbernail.png' ) );
    my @pngs = bsd_glob( File::Spec->join( $convert_dirpath, 'tumbernail*.png' ) );

    if ( @pngs > 1 ) {
        my $index_for = sub {
            my ($index) = ( shift =~ /.*tumbernail-(\d+).png/ );
            return $index;
        };
        @pngs = sort { $index_for->($a) <=> $index_for->($b) } @pngs;
    }

    confess sprintf( "convert of %s content-type %s failed", $filepath, $self->get_filetype ) if 0 == @pngs;

    $self->set_converted_filepaths( \@pngs );

    return;

} ## end sub _convert_with_convert


sub _convert_with_gs {
    my ( $self, $filepath ) = @_;

    my $convert_dirpath = File::Spec->join( $self->get_tempdir, 'convert' );
    make_path($convert_dirpath);

    $self->_execute(
        'gs',
        '-dPARANOIDSAFER',
        '-dNOPAUSE',
        '-o' => File::Spec->join( $convert_dirpath, 'page-%05d.png' ),
        '-sDEVICE=png16m',
        '-r150',
        $filepath
    );

    my @pngs = bsd_glob( File::Spec->join( $convert_dirpath, 'page-*.png' ) );
warn Dumper \@pngs;
    my $index_for = sub {
        my ($index) = ( shift =~ /.*page-(\d+).png/ );
        return $index;
    };
    @pngs = sort { $index_for->($a) <=> $index_for->($b) } @pngs;

    confess sprintf( "convert of %s content-type %s failed", $filepath, $self->get_filetype ) if 0 == @pngs;

    $self->set_converted_filepaths( \@pngs );

    return;

} ## end sub _convert_with_convert

sub _convert_with_no_conversion {
    my ( $self, $filepath ) = @_;
    confess("Can't convert file: $filepath");
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
