package App::FileSortUtils;

use 5.010001;
use strict;
use warnings;

use Exporter 'import';

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

my @file_types = qw(file dir);

my @file_fields = qw(name size mtime ctime);

$SPEC{sort_files} = {
    v => 1.1,
    summary => 'Sort files in a directory and display the result in a flexible way',
    description => <<'MARKDOWN',


MARKDOWN
    args => {
        dir => {
            summary => 'Directory to sort files of, defaults to current directory',
            schema => 'dirname::default_cur',
            pos => 0,
            tags => ['category:input'],
        },

        type => {
            summary => 'Only include files of certain type',
            schema => ['str*', in=>\@file_types],
            cmdline_aliases => {
                t => {},
                f => {summary=>'Shortcut for --type=file', is_flag=>1, code=>sub { $_[0]{type} = 'file' }},
                d => {summary=>'Shortcut for --type=dir' , is_flag=>1, code=>sub { $_[0]{type} = 'dir'  }},
            },
            tags => ['category:filtering'],
        },

        by_field => {
            summary => 'Field name to sort against',
            schema => ['str*', in=>\@file_fields],
            tags => ['category:sorting'],
        },
        reverse => {
            summary => 'Reverse order of sorting',
            schema => 'true*',
            cmdline_aliases => {r=>{}},
            tags => ['category:sorting'],
        },
        key => {
            summary => 'Perl code to generate key to sort against',
            schema => 'code_from_str*',
            description => <<'MARKDOWN',

If `key` option is not specified, then: 1) if sorting is `by_code` then the code
will receive files as records (hashes) with keys like `name`, `size`, etc; 2) if
sorting is `by_field` then the associated field is used as key; 3) if sorting is
`by_sortsub` then by default the `name` field will be used as the key.

To select a field, use this:

    '$_->{FIELDNAME}'

for example:

    '$_->{size}'

Another example, to generate length of name as key:

    'length($_->{name})'

MARKDOWN
            tags => ['category:sorting'],
        },

        detail => {
            cmdline_aliases => {l=>{}},
            tags => ['category:output'],
        },
    },
    args_rels => {
        choose_one => [qw/by_field by_sortsub by_code/],
    },
};
sub sort_files {
    my %args = @_;

    my $dir = $args{dir} // '.';
    opendir my $dh, $dir or return [500, "Can't opendir '$dir': $!"];
    my @files;
    while (defined(my $e) = readdir $dh) {
        next if $e eq '.' || $e eq '..';
        $rec = {name=>$e};
        my @st = lstat $e or do {
            warn "Can't stat '$e' in '$dir': $!, skipped";
            next;
        };
        $rec->{size} = $st[7];
        $rec->{mtime} = $st[9];
        $rec->{ctime} = $st[10];
        push @files, $rec;
    }
    closedir $dh;

    my ($code_key, $code_cmp);
  SET_CODE_CMP: {
        if (defined $args{key}) {
            $code_key = $key;
        }
        if (defined $args{by_code}) {
            $code_key //= sub { $_ };
            $code_cmp = $args{by_code};
            last;
        }

        if (defined $args{by_field}) {
            if ($args{by_field} eq 'name') {
                $code_key //= sub { $_->{name} };
                $code_cmp = sub { $a cmp $b };
            } elsif ($args{by_field} eq 'size') {
                $code_key //= sub { $_->{size} };
                $code_cmp = sub { $a <=> $b };
            } elsif ($args{by_field} eq 'ctime') {
                $code_key //= sub { $_->{ctime} };
                $code_cmp = sub { $a <=> $b };
            } elsif ($args{by_field} eq 'mtime') {
                $code_key //= sub { $_->{mtime} };
                $code_cmp = sub { $a <=> $b };
            } else {
                return [400, "Invalid value in by_field: $args{by_field}"];
            }
        }

        return [400, "Please specify one of by_field/by_sortsub/by_code"];
    } # SET_CODE_CMP

  SORT: {
        @files = sub {
            $a = $code_key->($a);
            $b = $code_key->($b);
            $code_cmp->($a, $b);
        } @files;
    } # SORT

    unless ($args{detail}) {
        @files = map { $_->{name} } @files;
    }

    [200, "OK", \@files];
}

1;
#ABSTRACT: Utilities related to sorting files in a directory

=head1 DESCRIPTION

This distribution provides the following command-line utilities:

# INSERT_EXECS_LIST


=head1 SEE ALSO

=cut
