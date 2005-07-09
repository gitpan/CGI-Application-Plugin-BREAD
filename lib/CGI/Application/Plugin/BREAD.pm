package CGI::Application::Plugin::BREAD;

use 5.006;
use strict;
use warnings;

use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION );

use HTML::Template;
use HTML::FillInForm;
use HTML::Pager;

@ISA = qw( Exporter AutoLoader );

our @EXPORT_OK = qw(
    bread_db
    browse_page_size
    template_path
    template_type
    log_directive	
);

our $VERSION = '0.10';

use Data::Dumper;

my ( $internal_data );

sub import
{
    my $caller = scalar( caller );
    $caller->add_callback( 'prerun' => \&_register_runmodes );
    goto &Exporter::import;
}

sub _register_runmodes
{
    my ( $self, %runmodes, $tables, $uri );
    $self = shift;
    
    #warn "CGI::Application::Plugin::BREAD::register_runmodes() called!";
    %runmodes = ( 'start' => \&_start );
    $tables = {};
    if ( $internal_data->{'classes'} ) {
        foreach my $cdbi_class ( @{$internal_data->{'classes'}} ) {
            my $table = $cdbi_class->table;
            $runmodes{ "browse_$table" }            = \&_browse;
            $runmodes{ "read_$table" }              = \&_read;
            $runmodes{ "edit_$table" }              = \&_edit;
            $runmodes{ "add_$table" }               = \&_add;
            $runmodes{ "delete_$table" }            = \&_delete;
            $runmodes{ 'add_'.$table.'_submit' }    = \&_submit;
            $runmodes{ 'edit_'.$table.'_submit' }   = \&_submit;
            $tables->{$table} = $cdbi_class;
        }
    } else {
        die "We don't have any db classes!  Did you set any up with the bread_db() method?";
    }
    $internal_data->{'tables'} = $tables;
    #die Dumper( \%ENV );
    $uri = $ENV{'SCRIPT_URI'};
    # take off any tailing parameters...
    #$uri =~ s/\?.+//;
    $internal_data->{'uri'} = $uri;
    
    $self->run_modes( %runmodes );
}

sub bread_db
{
    my ( $self, $parameter, $classes );
    
    ( $self, $parameter ) = @_;
    #warn "CGI::Application::Plugin::BREAD::bread_db() called!";
    
    # check parameter type ... it's either an arrayref or a ::Loader ref
    $classes = [];
    if ( ref( $parameter ) eq 'ARRAY' ) {
        $internal_data->{'cdbi_type'} = 'classes';
        foreach my $cdbi_class ( @$parameter ) {
            # check to see if it's loaded already
            unless ( $cdbi_class:: ) {
                my ( $file );
                $file = $cdbi_class;
                $file =~ s-::-/-g;
                eval {
                    require "$file.pm";
                    $cdbi_class->import();
                };
                die "CGI::Application::Plugin::BREAD::bread_db(): Couldn't use $cdbi_class class: $@" if ( $@ );
            }
            push @$classes, $cdbi_class;
        }
    } elsif ( ref( $parameter ) =~ /^Class::DBI::Loader/ ) {
        $internal_data->{'cdbi_type'} = 'loader';
        foreach my $class ( $parameter->classes ) {
            push @$classes, $class;
        }
    } else {
        my $ref = ref( $parameter );
        die "CGI::Application::Plugin::BREAD::bread_db(): Invalid parameter\nParameter must either be an array reference of Class::DBI classes or a Class::DBI::Loader object\nYou gave me a $ref object.";
    }
    $internal_data->{'classes'} = $classes;
}

sub browse_page_size
{
    my ( undef, $size ) = @_;
    if ( $size =~ /^\d+$/ && $size > 0 ) {
        $internal_data->{'page_size'} = $size;
    } else {
        warn "CGI::Application::Plugin::BREAD::browse_page_size(): Invalid page_size ($size) - must be a positive decimal.";
    }
}

sub template_path
{
    warn "Sorry - this feature (CAP::Bread::template_path()) hasn't been implemented yet!";
}

sub template_type
{
    warn "Sorry - this feature (CAP::Bread::template_type()) hasn't been implemented yet!";
}

sub log_directive
{
    warn "Sorry - this feature (CAP::Bread::log_directive()) hasn't been implemented yet!";
}

sub _start
{
    my ( $self, $table_ar, $table_hr, $uri, $template_html, $template );
    $self = shift;
    
    $table_ar = [];
    $table_hr = $internal_data->{'tables'};
    while( my ( $table, undef ) = each %$table_hr ) {
        push @$table_ar, {
                'table' => $table,
            };
    }
    $uri = $internal_data->{'uri'};
    
    $template_html = <<_EOF_;
<html>
<head>
<title>Database Administration</title>
</head>
<body>
This application is setup to manage the following tables:
<ul>
<TMPL_LOOP NAME="tables">
<li><TMPL_VAR NAME="table" ESCAPE=HTML>: <a href="$uri?rm=browse_<TMPL_VAR NAME="table" ESCAPE=HTML>">Browse</a> or <a href="$uri?rm=add_<TMPL_VAR NAME="table" ESCAPE=HTML>">Add</a></li>
</TMPL_LOOP>
</ul>
</body>
</html>
_EOF_
    
    $template = HTML::Template->new( 'scalarref' => \$template_html );
    $template->param( 'tables' => $table_ar );
    $template->output;
}

sub _browse
{
    my ( $self, $runmode, $table, $class, @columns, $colspan, @other_columns, $objects_iterator, $headers, $records, $subtemplate, $uri, $template_html, $template, $get_data_sub, $pager );
    
    $self = shift;
    $runmode = $self->get_current_runmode();
    ( $table ) = $runmode =~ /^browse_(.+)$/;
    
    $class = $internal_data->{'tables'}->{$table};
    $internal_data->{'page_size'} = 20 if ! $internal_data->{'page_size'};
    
    @columns = $class->columns;
    $colspan = scalar( @columns );
    $objects_iterator = $class->retrieve_all;
    $headers = [];
    $subtemplate = '';
    $uri = $internal_data->{'uri'};
    # pull out primary column (if we have it) first...
    if ( my $primary = $class->primary_column ) {
        push @$headers, { 'header' => $primary };
        $subtemplate .= qq%<td><nobr><A HREF="$uri?rm=edit_$table&id=<TMPL_VAR NAME="$primary" ESCAPE=HTML>"><TMPL_VAR NAME="$primary" ESCAPE=HTML></A> <a href="$uri?rm=delete_<TMPL_VAR NAME="table" ESCAPE=HTML>&$primary=<TMPL_VAR NAME="$primary" ESCAPE=HTML>" onClick="javascript: if (confirm('Are You Sure?')){return true;}else{return false;}">Delete</a></nobr></td>%;
        # now need to take it out of @columns
        @other_columns = grep( !/^$primary$/, @columns );
    } else {
        @other_columns = @columns;
    }
    foreach my $header ( sort @other_columns ) {
        push @$headers, { 'header' => $header };
        $subtemplate .= qq%<td><TMPL_VAR NAME="$header" ESCAPE=HTML></td>%;
    }
    
    $template_html = <<_EOF_;
<html>
<head>
<title>Database Administration :: Browsing <TMPL_VAR NAME="table" ESCAPE=HTML> Table</title>
</head>
<body>

<p>
The <b><TMPL_VAR NAME="table" ESCAPE=HTML></b> table has the following <TMPL_VAR NAME="count" ESCAPE=HTML> records, broken up into <TMPL_VAR NAME="num_pages" ESCAPE=HTML> pages of <TMPL_VAR NAME="pagesize" ESCAPE=HTML> each:
</p>

<TMPL_VAR NAME="PAGER_JAVASCRIPT">
  <FORM METHOD="POST">
  <TABLE BORDER=0 BGCOLOR=#000000 WIDTH=100%>
  <TR><TD><TABLE BORDER=0 WIDTH=100%>
    <tr BGCOLOR="#FFFFFF">
    <TMPL_LOOP NAME="headers">
    <th><TMPL_VAR NAME="header" ESCAPE=HTML></th>
    </TMPL_LOOP>
    </tr>
  <TMPL_LOOP NAME="PAGER_DATA_LIST">
    <TR BGCOLOR="#FFFFFF">
        $subtemplate
    </TR>
  </TMPL_LOOP>
  <TR><TD BGCOLOR=#DDDDDD COLSPAN=$colspan ALIGN=CENTER>
    <TMPL_VAR NAME="PAGER_PREV">
    <TMPL_VAR NAME="PAGER_JUMP">
    <TMPL_VAR NAME="PAGER_NEXT">
  </TD></TR>
  </TABLE>
  </TABLE>
  <TMPL_VAR NAME="PAGER_HIDDEN">
</FORM>

</body>
</html>
_EOF_
    
    $template = HTML::Template->new( 'scalarref' => \$template_html, 'global_vars' => 1 );
    $template->param(
            'table'     => $table,
            'headers'   => $headers,
            'count'     => $objects_iterator->count,
            'pagesize'  => $internal_data->{'page_size'},
            'num_pages' => sprintf( "%d", ($objects_iterator->count/$internal_data->{'page_size'})+1 )
        );
    
    $get_data_sub = sub
       {
            my ( $offset, $rows, @objects, $records );
            ( $offset, $rows ) = @_;
            @objects = $objects_iterator->slice( $offset, $rows+$offset-1 );
            $records = [];
            
            foreach my $obj ( @objects ) {
                my %data = ();
                foreach my $column ( @columns ) {
                    my $subdata = $obj->get( $column );
                    $subdata = ref( $subdata ) if ref( $subdata );
                    $data{$column} = $subdata;
                }
                push @$records, \%data;
            }

            return $records;
        };
    
    $pager = HTML::Pager->new(
            'template'          => $template,
            'query'             => $self->query,
            'rows'              => $objects_iterator->count,
            'page_size'         => $internal_data->{'page_size'},
            'get_data_callback' => $get_data_sub,
            'persist_vars'      => [ 'rm' ],
        );
    $pager->output();

}

sub _read
{
    # not sure if this is needed...
}

sub _edit
{
    my ( $self, $runmode, $table, $html, $class, $obj, %data, $fif );
    
    $self = shift;
    $runmode = $self->get_current_runmode();
    ( $table ) = $runmode =~ /^edit_(.+)$/;

    $html = _get_add_or_edit_form( $self );

    $class = $internal_data->{'tables'}->{$table};
    $obj = $class->retrieve( $self->query->param( 'id' ) );
    %data = ();
    foreach my $column ( sort $class->columns ) {
        $data{ $column } = $obj->get( $column );
    }
    
    $fif = HTML::FillInForm->new();
    $fif->fill(
            'scalarref' => \$html,
            'fdat'      => \%data
        );
}

sub _add
{
    my ( $self );
    
    $self = shift;
    
    _get_add_or_edit_form( $self );
}

sub _delete
{
    my ( $self, $runmode, $table, $class, $obj );
    
    $self = shift;
    $runmode = $self->get_current_runmode();
    ( $table ) = $runmode =~ /^delete_(.+)$/;
    $class = $internal_data->{'tables'}->{$table};
    $obj = $class->retrieve( $self->query->param( 'id' ) );
    
    $obj->delete;
    
    $self->header_type( 'redirect' );
    $self->header_props( -url => $internal_data->{'uri'} );
}

sub _submit
{
    my ( $self, $runmode, $mode, $table, $class, $form );

    $self = shift;
    $runmode = $self->get_current_runmode();
    ( $mode, $table ) = $runmode =~ /^(add|edit)_(.+)_submit$/;
    $class = $internal_data->{'tables'}->{$table};
    
    $form = $class->as_form( params => $self->query );
    if ( $form->submitted ) {
        if ( $mode eq 'add' ) {
            my $obj = $class->create_from_form( $form );
        } elsif ( $mode eq 'edit' ) {
            my $obj = $class->update_from_form( $form );
        } else {
            warn "CGI::Application::Plugin::BREAD::_submit(): Unknown mode ($mode) - Expecting add or edit.";
        }
    }
    
    # redirecting user back to main page
    $self->header_type( 'redirect' );
    $self->header_props( -url => $internal_data->{'uri'} );
}

sub _get_add_or_edit_form
{
    my ( $self, $subtitle, $form, $rm_hidden, $runmode, $mode, $table, $class, $template_html, $template );
    
    $self = shift;
    
    if ( $self->query->param( 'id' ) ) {
        $subtitle = q%Editing Entry # <TMPL_VAR NAME="id" ESCAPE=HTML>%;
    } else {
        $subtitle = 'Adding an Entry';
    }

    $runmode = $self->get_current_runmode();
    ( $mode, $table ) = $runmode =~ /^(add|edit)_(.+)$/;
    $class = $internal_data->{'tables'}->{$table};
    $class->form_builder_defaults( { method => 'post' } );

    $form = $class->as_form( params => $self->query )->render;
    $rm_hidden = '<input type="hidden" name="rm" value="' . $mode . '_' . $table . '_submit" />';
    $form =~ s/<input/$rm_hidden<input/;

    $template_html = <<_EOF_;
<html>
<head>
<title>Database Administration :: $subtitle to the <TMPL_VAR NAME="table" ESCAPE=HTML> Table</title>
</head>
<body>

$form

</body>
</html>
_EOF_
    
    $template = HTML::Template->new( 'scalarref' => \$template_html, 'associate' => $self->query );
    $template->param(
            'table'     => $table,
        );
    $template->output;
}

1;
__END__

=head1 NAME

CGI::Application::Plugin::BREAD

=head2 Description

A lot of emphasis has been put on Ruby on Rails, Catalyst or other type of easy-to-use and easy-to-setup BREAD applications.  BREAD (oh how we love acronyms) stands for Browse, Read, Edit, Add and Delete.  CRUD (Create, Retrieve, Update and Delete) also suffices, but BREAD just sounds better.  Either way you slice it (pun intended), this Plugin will allow you to setup a database management tool for your users in no time.

=head2 Synopsis

The instance script stays the same.

In your CGI::Application module:

  package MyBREADApp;

  use base 'CGI::Application';
  use CGI::Application::Plugin::BREAD;

  sub setup
  {
    $self = shift;
    my $loader = Class::DBI::Loader->new(
            dsn                     => "dbi:mysql:mysql",
            user                    => "webuser",
            password                => "webpass",
            namespace               => "WHATEVER",
            relationships           => 1,
            additional_classes      => [ 'Class::DBI::FormBuilder' ],
        );
    $self->bread_db( $loader );
  }

=head2 Details

Then just point your browser to your instance script and you can use the following URL patterns:

=begin html

http://example.com/mybreadapp.cgi<br>
http://example.com/mybreadapp.cgi?rm=browse_users<br>
http://example.com/mybreadapp.cgi?rm=read_users&id=5<br>
http://example.com/mybreadapp.cgi?rm=edit_users&id=5<br>
http://example.com/mybreadapp.cgi?rm=add_users<br>
http://example.com/mybreadapp.cgi?rm=delete_users&id=5

=end html

The patterns follow a standardized set of prefixes (C<browse_>, C<read_>, C<edit_>, C<add_> and C<delete_>) and then the name of the table (in the example above, C<users>).

This module doesn't deal with authentication (yet) -- if you want to protect the application, it's recommended that you place the instance script in a secured directory or Apache Directive.  We foresee adding more microlevels of authentication, such that you can define which users can delete, add, edit, etc.

This module comes with some rudimentary templates that are built-in, just in case you want a simplified approach and don't really care about the look & feel.  If this needs more polish, you can override the built-in templates with your own template files.  The plugin will automatically look for any overriding template files in the local directory and then also in a C<templates> subdirectory.  Optionally, you can also point the BREAD plugin to a directory where your own templates reside.  Template files must match the runmode names.  So the plugin will look for browse_users.TMPL (which can be an HTML::Template, Template::Toolkit or Petal)

This module can automatically log any work done.  Unless you specify some logging directives, it will append to a temp file called bread_YYMMDD.log.  Otherwise, you can specify a logging directive in your cgiapp_init (or setup) method, which follows the LogDispatch technique.

=head3 bread_db

This method points the BREAD plugin to what database to work with.  There's a lot of flexibility in the parameter choices.  You can provide an array reference of Class::DBI classes or Class::DBI::Loader.  This method will inspect your parameter by looking at its reference.

=head3 browse_page_size

Optional configuration method in which you can override the default page size of 20 records.

=head3 template_path (NOT YET IMPLEMENTED)

Totally optional - if you specify this, the plugin will also look for an overriding template file in the directory that you specify here.  The method expects a simple scalar parameter.

=head3 template_type (NOT YET IMPLEMENTED)

Again, totally optional.  If you're going to override the built-in templates and if you're going to not use the HTML::Template default, then you can specify the template type by giving a parameter of 'TemplateToolkit' or 'Petal'.  These parameters get passed into the CGI::Application::Plugin::AnyTemplate, so if their parameters change in the future, so will these.

=head3 log_directive (NOT YET IMPLEMENTED)

Another optional directive.  This parameter shares the same from CGI::Application::Plugin::LogDispatch, so the parameter matches that specification.

=head1 See Also

L<CGI::Application>, L<HTML::Template>, L<Template::Toolkit>, L<Petal.pm>, L<DBI.pm>, L<Class::DBI>, L<Class::DBI::Loader>

L<http://www.cgi-app.org> CGI::Application Wiki

=head1 BUGS

This release is "alpha" - please do not use this in a production
environment until we reach version 1.0.  This release is meant
to gather feedback and keep our momentum going.

Post bugs to the RT:

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=CGI-Application-Plugin-BREAD>

=head1 AUTHORS

Jason Purdy, <jason@purdy.info>

=head1 LICENSE

Copyright (C) 2005 Jason Purdy, <jason@purdy.info>

This library is free software. You can modify and or distribute it under the same terms as Perl itself.

=cut
