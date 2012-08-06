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
    '.pdf'  => 'convert',
    '.odt'  => 'unoconv_via_pdf',
    '.ods'  => 'unoconv_via_pdf',
    '.odp'  => 'unoconv_via_pdf',
    '.odg'  => 'unoconv_via_pdf',
    '.odg'  => 'unoconv_via_pdf',
    '.odf'  => 'unoconv_via_pdf',
    '.od1'  => 'unoconv_via_pdf',
    '.odm'  => 'unoconv_via_pdf',
    '.odb'  => 'unoconv_via_pdf',
    '.odb'  => 'unoconv_via_pdf',
    '.odb'  => 'unoconv_via_pdf',
    '.ott'  => 'unoconv_via_pdf',
    '.ots'  => 'unoconv_via_pdf',
    '.otp'  => 'unoconv_via_pdf',
    '.otg'  => 'unoconv_via_pdf',
    '.otc'  => 'unoconv_via_pdf',
    '.otf'  => 'unoconv_via_pdf',
    '.oti'  => 'unoconv_via_pdf',
    '.oth'  => 'unoconv_via_pdf',
    '.pdf'  => 'convert',
    '.doc'  => 'unoconv_via_pdf',
    '.dot'  => 'unoconv_via_pdf',
    '.docx' => 'unoconv_via_pdf',
    '.dotx' => 'unoconv_via_pdf',
    '.docm' => 'unoconv_via_pdf',
    '.dotm' => 'unoconv_via_pdf',
    '.xls'  => 'unoconv_via_pdf',
    '.xlt'  => 'unoconv_via_pdf',
    '.xla'  => 'unoconv_via_pdf',
    '.xlsx' => 'unoconv_via_pdf',
    '.xltx' => 'unoconv_via_pdf',
    '.xlsm' => 'unoconv_via_pdf',
    '.xltm' => 'unoconv_via_pdf',
    '.xlam' => 'unoconv_via_pdf',
    '.xlsb' => 'unoconv_via_pdf',
    '.ppt'  => 'unoconv_via_pdf',
    '.pot'  => 'unoconv_via_pdf',
    '.pps'  => 'unoconv_via_pdf',
    '.ppa'  => 'unoconv_via_pdf',
    '.pptx' => 'unoconv_via_pdf',
    '.potx' => 'unoconv_via_pdf',
    '.ppsx' => 'unoconv_via_pdf',
    '.ppam' => 'unoconv_via_pdf',
    '.pptm' => 'unoconv_via_pdf',
    '.potm' => 'unoconv_via_pdf',
    '.ppsm' => 'unoconv_via_pdf',
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
    } elsif ( $data eq 'unoconv_via_pdf' ) {
        return $self->_convert_with_unoconv_via_pdf( $self->get_filepath );
    } elsif ( $data eq 'copy' ) {
        return $self->_convert_with_copy( $self->get_filepath );
    } elsif ( $data eq 'no_conversion' ) {
        return $self->_convert_with_no_conversion( $self->get_filepath );
    }

    confess "Can't convert $data for filetype: " . $self->get_filetype;
}

sub _convert_with_unoconv_via_pdf {
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

    return $self->_convert_with_convert( $pdfs[0] );

} ## end sub _convert_with_unoconv_via_pdf

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

    # TO: gs -dPARANOIDSAFER -dNOPAUSE -o page_%03d.png -sDEVICE=png16m -r300 xxx.pdf
    $self->_execute(
        'gs',
        '-dPARANOIDSAFER',
        '-dNOPAUSE',
        '-o' => File::Spec->join( $convert_dirpath, 'page-%05d.png' ),
        '-sDEVICE=png16m',
        '-r300',
        $filepath
    );

    #$self->_execute( 'convert', $filepath, File::Spec->join( $convert_dirpath, 'tumbernail.png' ) );
    my @pngs = bsd_glob( File::Spec->join( $convert_dirpath, 'page-*.png' ) );

    if ( @pngs > 1 ) {
        my $index_for = sub {
            my ($index) = ( shift =~ /.*page-(\d+).png/ );
            return $index;
        };
        @pngs = sort { $index_for->($a) <=> $index_for->($b) } @pngs;
    }

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
