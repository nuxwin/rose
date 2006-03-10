package Rose::DB::Object::MixIn;

use strict;

use Carp;

our $Debug = 0;

our $VERSION = '0.62';

use Rose::Class::MakeMethods::Set
(
  inheritable_set => 
  [
    '_export_tag' =>
    {
      clear_method   => 'clear_export_tags',
      list_method    => 'export_tags',
      add_method     => 'add_export_tag',
      adds_method    => 'add_export_tags',
      delete_method  => 'delete_export_tag',
      deletes_method => 'delete_export_tags',
    },
  ],
);

sub import
{
  my($class) = shift;

  my $target_class = (caller)[0];

  my($force, @methods, %import_as);
  
  foreach my $arg (@_)
  {
    if($arg =~ /^-?-force$/)
    {
      $force = 1;
    }
    elsif($arg =~ /^:(.+)/)
    {
      my $methods = $class->export_tag($1) or
        croak "Unknown export tag - '$arg'";

      push(@methods, @$methods);
    }
    elsif(ref $arg eq 'HASH')
    {
      while(my($method, $name) = each(%$arg))
      {
        push(@methods, $method);
        $import_as{$method} = $name;
      }
    }
    else
    {
      push(@methods, $arg);
    }
  }

  foreach my $method (@methods)
  {
    my $code = $class->can($method) or 
      croak "Could not import method '$method' from $class - no such method";

    my $import_as = $import_as{$method} || $method;

    if($target_class->can($import_as) && !$force)
    {
      croak "Could not import method '$import_as' from $class into ",
            "$target_class - a method by that name already exists. ",
            "Pass a '--force' argument to import() to override ",
            "existing methods."
    }

    no strict 'refs';      
    $Debug && warn "${target_class}::$import_as = ${class}->$method\n";
    *{$target_class . '::' . $import_as} = $code;
  }
}

sub export_tag
{
  my($class, $tag) = (shift, shift);

  if(index($tag, ':') == 0)
  {
    croak 'Tag name arguments to export_tag() should not begin with ":"';
  }

  if(@_ && !$class->_export_tag_value($tag))
  {
    $class->add_export_tag($tag);
  }

  if(@_ && (@_ > 1 || (ref $_[0] || '') ne 'ARRAY'))
  {
    croak 'export_tag() expects either a single tag name argument, ',
          'or a tagname and a reference to an array of method names';
  }

  my $ret = $class->_export_tag_value($tag, @_);
  
  croak "No such tag: $tag"  unless($ret);

  return wantarray ? @$ret : $ret;
}

1;

__END__

=head1 NAME

Rose::DB::Object::MixIn - A base class for mix-ins.

=head1 SYNOPSIS

  package MyMixInClass;

  use Rose::DB::Object::MixIn(); # Use empty parentheses here
  our @ISA = qw(Rose::DB::Object::MixIn);

  __PACKAGE__->export_tag(all => [ q(my_cool_method my_other_method) ]);

  sub my_cool_method  { ... }
  sub my_other_method { ... }
  ...

  package MyClass;
  # Import methods my_cool_method() and my_other_method()
  use MyMixInClass qw(:all);
  ...

  package MyOtherClass;  
  # Import just my_cool_method()
  use MyMixInClass qw(my_cool_method);
  ...

  package YetAnotherClass;
  # Import just my_cool_method() as cool()
  use MyMixInClass { my_cool_method => 'cool' }

=head1 DESCRIPTION

L<Rose::DB::Object::MixIn> is a base class for mix-ins.  A mix-in is a class that exports methods into another class.  This export process is controlelr with an L<Exporter>-like interface, but L<Rose::DB::Object::MixIn> does not inherit from L<Exporter>.

When you L<use|perlfunc/use> a L<Rose::DB::Object::MixIn>-derived class, its L<import|/import> method is called at compile time.  In other words, this:

    use Rose::DB::Object::MixIn 'foo', 'bar';

is the same thing as this:

    BEGIN { Rose::DB::Object::MixIn->import('foo', 'bar') }

To prevent the L<import|/import> method from being run, put empty parentheses "()" after the package name instead of a list of arguments.

    use Rose::DB::Object::MixIn();

See the L<synopsis|/SYNOPSIS> for an example of when this is handy: using L<Rose::DB::Object::MixIn> from within a subclass.  Note that the empty parenthesis are important.  The following is I<not> equivalent:

    use Rose::DB::Object::MixIn; # not the same thing as the example above!

See the documentation for the L<import|/import> method below to learn what arguments it accepts.

=head1 CLASS METHODS

=over 4

=item B<import ARGS>

Import the methods specified by ARGS into the package from which this method was called.  If the current class L<can|perlfunc/can> already perform one of these methods, a fatal error will occur.  To override an existing method, you must use the C<--force> argument (see below).

Valid formats for ARGS are as follows:

=over 4

=item * B<A method name>

Literal method names will be imported as-is.

=item * B<A tag name>

Tags names are indicated by a leading colon.  For exampe, ":all" specifies the "all" tag.  A tag is a stand-in for a list of methods.  See the L<export_tag|/export_tag> method to learn how to create tags.

=item * B<A reference to a hash>

Each key/vaue pair in this has is a method name and the name that it will be imported as.  In this way, you can import methods under different names in order to avoid conflicts.

=item * B<-force>

The special argument "-force" will cause the specified methods to be imported even if the calling class L<can|perlfunc/can> already perform one or more of those methods.

=back

See the L<synopsis|/SYNOPSIS> for several examples of the L<import|/import> method in action.  (Remember, it's called implicitly when you L<use|perlfunc/use> a L<Rose::DB::Object::MixIn>-derived class with anything other than an empty set of parenthesis "()" as arguments.)

=item B<clear_export_tags>

Delete the entire list of L<export tags|/export_tags>.

=item B<export_tag NAME [, ARRAYREF]>

Get or set the list of method names associated with a tag.  The tag name should not begin with a colon.  If ARRAYREF is passed, then the list methods associated with the specific tag is set.

Returns a list (in list context) or a reference to an array (in scalar context).  The array reference return value should be treated as read-only.  If no such tag exists, and if an ARRAYREF is not passed, then a fatal error will occur.

=item B<export_tags>

Returns a list (in list context) and a reference to an array (in scalar context) containing the complete list of export tags.  The array reference return value should be treated as read-only.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.