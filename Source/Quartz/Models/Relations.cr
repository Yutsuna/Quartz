require "./Model"


module Quartz


  # Association DSL for `AModel`.
  #
  # Reopens `AModel` to add the `belongs_to` / `has_many` relationship macros.
  # Like `field`, macros defined here are inherited by every subclass.
  #
  # ```
  # class Author < Quartz::AModel
  #   field name : String
  #   has_many books : Book          # => Author#books : Array(Book)
  # end
  #
  # class Book < Quartz::AModel
  #   field title : String
  #   belongs_to author : Author     # => adds author_id : UInt64, Book#author / #author=
  # end
  #
  # a = Author.objects.create( name: "Léo" )
  # b = Book.objects.create( title: "Crystal", author_id: a.id )
  # b.author # => #<Author id=1 name="Léo">
  # a.books  # => [#<Book id=1 title="Crystal" author_id=1>]
  # ```
  #
  abstract class AModel

    # Declares a many-to-one association.
    #
    # ```
    # belongs_to author : Author
    # ```
    macro belongs_to ( decl )
      {% unless decl.is_a?( TypeDeclaration ) %}
        {% raise "Quartz: `belongs_to` expects a type declaration like `belongs_to author : Author`, got: #{decl}" %}
      {% end %}

      field {{decl.var}}_id : UInt64 = 0_u64

      # The associated `{{decl.type}}`, or `nil` when unset / not found.
      def {{decl.var}} : {{decl.type}}?
        {{decl.type}}.objects.find?( @{{decl.var}}_id )
      end

      # Sets the foreign key from an associated record.
      def {{decl.var}}=( record : {{decl.type}} ) : {{decl.type}}
        @{{decl.var}}_id = record.id
        record
      end
    end

    #--------------------------------------------------------------------------

    # Declares a one-to-many association (the inverse of `belongs_to`).
    #
    # ```
    # has_many books : Book
    # has_many books : Book, foreign_key: written_by_id
    # ```
    #
    macro has_many ( decl, foreign_key = nil )
      {% unless decl.is_a?( TypeDeclaration ) %}
        {% raise "Quartz: `has_many` expects a type declaration like `has_many books : Book`, got: #{decl}" %}
      {% end %}
      {% fk = foreign_key ? foreign_key.id : "#{@type.name.stringify.split("::").last.underscore.id}_id".id %}

      # The associated `{{decl.type}}` records pointing back at this record.
      def {{decl.var}} : Array( {{decl.type}} )
        {{decl.type}}.objects.where { |record| record.{{fk}} == @id }
      end
    end

    #--------------------------------------------------------------------------

  end


end
