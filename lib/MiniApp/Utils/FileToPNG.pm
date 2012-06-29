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
    'image/svg+xml' => {
        'name'         => 'Scalable Vector Graphics',
        'extension'    => ['.svg'],
        'convert_with' => 'convert',
    },
    'image/jpeg' => {
        'name'         => 'JPEG',
        'extension'    => [ '.jpg', '.jpeg', '.jpe', '.jif', '.jfif', '.jfi' ],
        'convert_with' => 'convert',
    },
    'image/png' => {
        'name'         => 'Portable Network Graphics',
        'extension'    => ['.png'],
        'convert_with' => 'copy',
    },
    'application/pdf' => {
        'name'         => 'Portable Document Format',
        'extension'    => ['.pdf'],
        'convert_with' => 'unoconv',
    },
    'application/vnd.oasis.opendocument.text' => {
        'name'         => 'Open Document Text',
        'extension'    => ['.odt'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.spreadsheet' => {
        'name'         => 'Open Document Spreadsheet',
        'extension'    => ['.ods'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.presentation' => {
        'name'         => 'Open Document Presentation',
        'extension'    => ['.odp'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.graphics' => {
        'name'         => 'Open Document Drawing',
        'extension'    => ['.odg'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.chart' => {
        'name'         => 'Open Document Chart',
        'extension'    => ['.odg'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.formula' => {
        'name'         => 'Open Document Formula',
        'extension'    => ['.odf'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.image' => {
        'name'         => 'Open Document Image',
        'extension'    => ['.od1'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.text-master' => {
        'name'         => 'Open Document Master Document',
        'extension'    => ['.odm'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.sun.xml.base' => {
        'name'         => 'Open Document Database',
        'extension'    => ['.odb'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.base' => {
        'name'         => 'Open Document Database',
        'extension'    => ['.odb'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.database' => {
        'name'         => 'Open Document Database',
        'extension'    => ['.odb'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.text-template' => {
        'name'         => 'Open Document Text Template',
        'extension'    => ['.ott'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.spreadsheet-template' => {
        'name'         => 'Open Document Spreadsheet Template',
        'extension'    => ['.ots'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.presentation-template' => {
        'name'         => 'Open Document Presentation Template',
        'extension'    => ['.otp'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.graphics-template' => {
        'name'         => 'Open Document Drawing Template',
        'extension'    => ['.otg'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.chart-template' => {
        'name'         => 'Open Document Chart template',
        'extension'    => ['.otc'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.formula-template' => {
        'name'         => 'Open Document Formula template',
        'extension'    => ['.otf'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.image-template' => {
        'name'         => 'Open Document Image template',
        'extension'    => ['.oti'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.oasis.opendocument.text-web' => {
        'name'         => 'Open Document Web page template',
        'extension'    => ['.oth'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/vnd.ms-office' => {
        'name'         => 'Microsoft Office',
        'extension'    => ['.pdf'],
        'convert_with' => 'unoconv_via_pdf',
    },
    'application/msword' => {
        'name'               => 'Microsoft Office Word',
        'extension'          => ['.doc'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/msword' => {
        'name'               => 'Microsoft Office Word',
        'extension'          => ['.dot'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => {
        'name'               => 'Microsoft Office Word',
        'extension'          => ['.docx'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.openxmlformats-officedocument.wordprocessingml.template' => {
        'name'               => 'Microsoft Office Word',
        'extension'          => ['.dotx'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-word.document.macroEnabled.12' => {
        'name'               => 'Microsoft Office Word',
        'extension'          => ['.docm'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-word.template.macroEnabled.12' => {
        'name'               => 'Microsoft Office Word',
        'extension'          => ['.dotm'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-excel' => {
        'name'               => 'Microsoft Office Excel',
        'extension'          => ['.xls'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-excel' => {
        'name'               => 'Microsoft Office Excel',
        'extension'          => ['.xlt'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-excel' => {
        'name'               => 'Microsoft Office Excel',
        'extension'          => ['.xla'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => {
        'name'               => 'Microsoft Office Excel',
        'extension'          => ['.xlsx'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.openxmlformats-officedocument.spreadsheetml.template' => {
        'name'               => 'Microsoft Office Excel',
        'extension'          => ['.xltx'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-excel.sheet.macroEnabled.12' => {
        'name'               => 'Microsoft Office Excel',
        'extension'          => ['.xlsm'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-excel.template.macroEnabled.12' => {
        'name'               => 'Microsoft Office Excel',
        'extension'          => ['.xltm'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-excel.addin.macroEnabled.12' => {
        'name'               => 'Microsoft Office Excel',
        'extension'          => ['.xlam'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-excel.sheet.binary.macroEnabled.12' => {
        'name'               => 'Microsoft Office Excel',
        'extension'          => ['.xlsb'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-powerpoint' => {
        'name'               => 'Microsoft Office Powerpoint',
        'extension'          => [ '.ppt', '.pot', '.pps', '.ppa' ],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.openxmlformats-officedocument.presentationml.presentation' => {
        'name'               => 'Microsoft Office Powerpoint',
        'extension'          => ['.pptx'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.openxmlformats-officedocument.presentationml.template' => {
        'name'               => 'Microsoft Office Powerpoint',
        'extension'          => ['.potx'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.openxmlformats-officedocument.presentationml.slideshow' => {
        'name'               => 'Microsoft Office Powerpoint',
        'extension'          => ['.ppsx'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-powerpoint.addin.macroEnabled.12' => {
        'name'               => 'Microsoft Office Powerpoint',
        'extension'          => ['.ppam'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-powerpoint.presentation.macroEnabled.12' => {
        'name'               => 'Microsoft Office Powerpoint',
        'extension'          => ['.pptm'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-powerpoint.template.macroEnabled.12' => {
        'name'               => 'Microsoft Office Powerpoint',
        'extension'          => ['.potm'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/vnd.ms-powerpoint.slideshow.macroEnabled.12' => {
        'name'               => 'Microsoft Office Powerpoint',
        'extension'          => ['.ppsm'],
        'use_file_extension' => 1,
        'convert_with'       => 'unoconv_via_pdf',
    },
    'application/octet-stream' => {
        'name'               => 'Executable',
        'extension'          => ['.dll', '.exe'],
        'use_file_extension' => 1,
        'convert_with'       => 'no_conversion',
    }
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

    my $filetype = $self->find_filetype( $self->get_filepath );

    confess "Filetype not found for file: " . $self->get_filepath if not defined $filetype;

    $self->set_filetype($filetype);

    return;
}

sub find_filetype {
    my ( $pkg, $filepath ) = @_;

    my ( $filetype, undef ) = $pkg->_execute( 'file', '--mime-type', '--brief', $filepath );
    chomp $filetype;

    if ( $filetype eq 'application/zip' ) {
        $filetype = undef;

        my $tempdir = blessed($pkg) ? $pkg->get_tempdir : File::Temp->newdir;

        my $unzip_dirpath = File::Spec->join( $tempdir, 'unzip' );
        make_path($unzip_dirpath);

        die "Can't create directory: $unzip_dirpath" if not -d -r $unzip_dirpath;

        $pkg->_execute( 'unzip', $filepath, '-d', $unzip_dirpath );

        my $manifest_filepath = File::Spec->join( $unzip_dirpath, 'META-INF', 'manifest.xml' );
        if ( -f $manifest_filepath ) {
            my $dom = Mojo::DOM->new( '' . read_file($manifest_filepath), { binmode => ':raw' } );
            my $element = $dom->at('file-entry[full-path="/"]');
            if ( defined $element ) {    # Open Office
                $filetype = $element->attrs('manifest:media-type');
            }
        }
    } ## end if ( $filetype eq 'application/zip')

    if ( not defined $filetype ) {
        while ( my ( $key, $data ) = each %CONVERT_FOR ) {
            next if not $data->{'use_file_extension'};
            if ( any { $filepath =~ /\Q$_\E$/ } @{ $data->{'extension'} } ) {
                $filetype = $key;
                last;
            }
        }
    }

    return $filetype;
} ## end sub find_filetype

sub convert {
    my ($self) = @_;

    my $data = $CONVERT_FOR{ $self->get_filetype };

    if ( $data->{'convert_with'} eq 'unoconv' ) {
        return $self->_convert_with_unoconv;
    } elsif ( $data->{'convert_with'} eq 'unoconv_via_pdf' ) {
        return $self->_convert_with_unoconv_via_pdf;
    } elsif ( $data->{'convert_with'} eq 'copy' ) {
        return $self->_convert_with_copy;
    } elsif ( $data->{'convert_with'} eq 'convert' ) {
        return $self->_convert_with_convert;
    } elsif ( $data->{'convert_with'} eq 'no_conversion' ) {
        return $self->_convert_with_no_conversion;
    }

    confess "Can't convert $data->{'convert_with'} for filetype: " . $self->get_filetype;
}

sub _convert_with_unoconv {
    my ($self) = @_;

    my $convert_dirpath = File::Spec->join( $self->get_tempdir, 'convert' );
    make_path($convert_dirpath);

    my ( undef, undef, $file ) = File::Spec->splitpath( $self->get_filepath );

    my $to_convert_filepath = File::Spec->join( $convert_dirpath, $file );

    copy( $self->get_filepath, $to_convert_filepath ) or confess "Copy failed: $!";

    $self->_execute( 'unoconv', '-f', 'png', $to_convert_filepath );

    my @pngs = bsd_glob( File::Spec->join( $convert_dirpath, '*.png' ) );
    confess sprintf( "unoconv of %s content-type %s failed", $self->get_filepath, $self->get_filetype ) if 1 != @pngs;

    $self->set_converted_filepaths( \@pngs );

    return;
} ## end sub _convert_with_unoconv

sub _convert_with_unoconv_via_pdf {
    my ($self) = @_;

    my $convert_dirpath = File::Spec->join( $self->get_tempdir, 'convert' );
    make_path($convert_dirpath);

    my ( undef, undef, $file ) = File::Spec->splitpath( $self->get_filepath );

    my $to_convert_filepath = File::Spec->join( $convert_dirpath, $file );

    copy( $self->get_filepath, $to_convert_filepath ) or confess "Copy failed: $!";

    $self->_execute( 'unoconv', '-f', 'pdf', $to_convert_filepath );
    my @pdfs = bsd_glob( File::Spec->join( $convert_dirpath, '*.pdf' ) );
    confess sprintf( "unoconv of %s content-type %s failed", $self->get_filepath, $self->get_filetype ) if 1 != @pdfs;

    $self->_execute( 'convert', $pdfs[0], File::Spec->join( $convert_dirpath, 'tumbernail.png' ) );
    my @pngs = bsd_glob( File::Spec->join( $convert_dirpath, 'tumbernail-*.png' ) );

    if ( @pngs > 1 ) {
        my $index_for = sub { 
            my ( $index ) = (shift =~ /.*tumbernail-(\d+).png/);
            return $index 
        };
        @pngs = sort { $index_for->($a) <=> $index_for->($b) } @pngs;
    }

    confess sprintf( "convert of %s content-type %s failed", $self->get_filepath, $self->get_filetype ) if 0 == @pngs;

    $self->set_converted_filepaths( \@pngs );

    return;
} ## end sub _convert_with_unoconv_via_pdf

sub _convert_with_copy {
    my ($self) = @_;

    my $convert_dirpath = File::Spec->join( $self->get_tempdir, 'convert' );
    make_path($convert_dirpath);

    my ( undef, undef, $file ) = File::Spec->splitpath( $self->get_filepath );

    my $to_convert_filepath = File::Spec->join( $convert_dirpath, $file );

    copy( $self->get_filepath, $to_convert_filepath ) or confess "Copy failed: $!";

    confess sprintf( "convert of %s content-type %s failed", $self->get_filepath, $self->get_filetype )
          if not -r $to_convert_filepath;

    $self->set_converted_filepaths([ $to_convert_filepath ]);

    return;
}

sub _convert_with_convert {
    my ($self) = @_;

    my $convert_dirpath = File::Spec->join( $self->get_tempdir, 'convert' );
    make_path($convert_dirpath);

    my ( undef, undef, $file ) = File::Spec->splitpath( $self->get_filepath );

    my $to_convert_filepath = File::Spec->join( $convert_dirpath, "$file.png" );

    $self->_execute( 'convert', $self->get_filepath, $to_convert_filepath );

    confess sprintf( "convert of %s content-type %s failed", $self->get_filepath, $self->get_filetype )
          if not -r $to_convert_filepath;

    $self->set_converted_filepaths( [$to_convert_filepath ]);

    return;
}

sub _convert_with_no_conversion {
    my ($self) = @_;

    my $filepath = $self->get_filepath;
    confess( "Can't convert file: $filepath" );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
