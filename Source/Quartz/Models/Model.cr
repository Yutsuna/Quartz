require "./Annotations"


module Quartz


  # Abstract base class of every Quarz model.
  #
  # Inherit from `AModel` and declare typed fields with the `field` macro:
  #
  # ```
  # class User < Quartz::AModel
  #   field name : String
  #   field age  : Int32 = 18
  # end
  #
  # u = User.objects.create( name: "Léo", age: 24 ) # => #<User id=1 name="Léo" age=24>
  # u.to_h                                          # => {"id" => 1, "name" => "Léo", "age" => 24}
  # User.fields                                     # => ["name", "age"]
  # ```
  #
  # REPL note:
  #            re-opening a model class to add a `field` after its first
  #            definition will not regenerate `initialize`
  #            the `finished` hook already ran, redefine the whole model instead.
  #
  abstract class AModel

    # Primary Key, managed by the model's `FManager`.
    # 0 is the documented "not persisted yet" sentinel.
    # Stored ids are always positive.
    property id : UInt64 = 0_i64

    # Whether the record has been assigned an id by a manager.
    def persisted? : Bool
      !@id.zero?
    end

    #--------------------------------------------------------------------------

    # Declares a typed model field with an optional default value:
    #
    # ```
    # field name : String
    # field age  : Int32 = 18
    # ```
    #
    # Generates an annotated `property` and registers the declaration in the
    # model's `QUARTZ_FIELDS` macro-time registry, from which the `finished`
    # hook generates the rest of the API.
    # Duplicate names (including against ancestor models) and the reserved name `id` are compile-time errors.
    macro field ( decl )
      {% unless decl.is_a?( TypeDeclaration ) %}
        {% raise "Quartz: `field` expects a type declaration like `field name : String`, got: #{decl}" %}
      {% end %}
      {% if decl.var.stringify == "id" %}
        {% raise "Quartz: `id` is reserved — every model already has `property id : Int64`" %}
      {% end %}
      {% if QUARTZ_FIELDS.any? { |f| f.var.stringify == decl.var.stringify } %}
        {% raise "Quartz: duplicate field `#{decl.var}` on #{@type}" %}
      {% end %}
      {% for ancestor in @type.ancestors %}
        {% if ancestor.has_constant?("QUARTZ_FIELDS") && ancestor.constant("QUARTZ_FIELDS").any? { |f| f.var.stringify == decl.var.stringify } %}
          {% raise "Quartz: field `#{decl.var}` on #{@type} is already declared on ancestor #{ancestor}" %}
        {% end %}
      {% end %}
      {% QUARTZ_FIELDS << decl %}
      @[Quartz::FField]
      property {{decl.var}} : {{decl.type}}
    end

    #--------------------------------------------------------------------------

    macro inherited
      # Macro-time registry of the fields declared directly on this class, filled by `field`.
      # Constant mutation at macro time is the established idiom (Granite, Avram).
      #
      # Unlike runtime side effects emitted from `inherited`, it works in the interpreter.
      # The `finished` hook below merges it with every ancestor registry.
      QUARTZ_FIELDS = [] of Nil

      {% unless @type.abstract? %}
        # Per-class manager instance. A constant (not a class var) because
        # subclasses must shadow it with their own typed manager
        # class vars are inherited and would clash across the hierarchy.
        # :nodoc:
        QUARTZ_OBJECTS = Quartz::FManager( {{@type}} ).new

        # Get the manager for this model.
        def self.objects : Quartz::FManager( {{@type}} )
          QUARTZ_OBJECTS
        end
      {% end %}

      # Short class name, e.g. `"User"`.
      # TODO: maybe change the hook
      def self.model_name : String
        {{@type.name.stringify}}
      end

      #--------------------------------------------------------------------------

      macro finished
        # Merge ancestor fields (root-most first) with this class's own.
        \{% fields = [] of Nil %}
        \{% ancestor_registries = @type.ancestors.select(&.has_constant?( "QUARTZ_FIELDS" )) %}
        \{% for index in 0...ancestor_registries.size %}
          \{% for decl in ancestor_registries[ancestor_registries.size - 1 - index].constant( "QUARTZ_FIELDS" ) %}
            \{% fields << decl %}
          \{% end %}
        \{% end %}
        \{% for decl in QUARTZ_FIELDS %} \{% fields << decl %} \{% end %}

        # Union of `Int64` (id) and every field type. Return type of `to_h`
        # and `[]`.
        alias FieldValue = Int64 \{% for d in fields %} | \{{d.type}} \{% end %}

        # Keyword-only constructor over every field (inherited ones included)
        # Defaults declared on `field` apply.
        def initialize(\{% unless fields.empty? %}*, \{% end %}\{% for d in fields %} @\{{d.var}} : \{{d.type}}\{% if d.value %} = \{{d.value}}\{% end %}, \{% end %})
        end

        # Field names of this model (ancestors included), root-most first.
        def self.fields : Array( String )
          [\{% for d in fields %} \{{d.var.stringify}}, \{% end %}] of String
        end

        # Field name => type name, e.g. `{"name" => "String", "age" => "Int32"}`.
        def self.field_types : Hash( String, String )
          h = {} of String => String
          \{% for d in fields %}
          h[\{{d.var.stringify}}] = \{{d.type.stringify}}
          \{% end %}
          h
        end

        # Field access by name. Raises `Quartz::UnknownField` for a name
        # that is not declared on this model.
        def []( name : String ) : FieldValue
          case name
          when "id"
            @id
          \{% for d in fields %}
          when \{{d.var.stringify}}
            @\{{d.var}}
          \{% end %}
          else
            raise Quartz::UnknownField.new( \{{@type.name.stringify}}, name )
          end
        end

        # Hash of the record: id plus every field.
        def to_h : Hash( String, FieldValue )
          h = {} of String => FieldValue
          h["id"] = @id
          \{% for d in fields %}
          h[\{{d.var.stringify}}] = @\{{d.var}}
          \{% end %}
          h
        end

        # Two records are equal when their id and every field match.
        def ==( other : self ) : Bool
          return false unless @id == other.id
          \{% for d in fields %}
          return false unless @\{{d.var}} == other.\{{d.var}}
          \{% end %}
          true
        end

        # Hashes the same components as `==`, honoring the `==`/`hash`
        # contract (stdlib-untyped `hasher` signature).
        def hash( hasher ) : UInt64
          hasher = @id.hash( hasher )
          \{% for d in fields %}
          hasher = @\{{d.var}}.hash( hasher )
          \{% end %}
          hasher
        end

        #--------------------------------------------------------------------------

        \{% unless @type.abstract? %}
          # Persists the record through the model's manager, assigning an
          # id on first save.
          def save : self
            \{{@type}}.objects.store( self )
          end

          # Removes the record from the model's manager and resets its id,
          # so `persisted?` becomes `false` again.
          def delete : Bool
            deleted = \{{@type}}.objects.delete(@id)
            @id = 0_i64 if deleted
            deleted
          end
        \{% end %}

        # Full debug representation: `#<User id=1 name="Léo" age=24>`.
        def inspect( io : IO ) : Nil
          io << "#<" << \{{@type.name.stringify}} << " id=" << @id
          \{% for d in fields %}
          io << ' ' << \{{d.var.stringify}} << '=' << @\{{d.var}}.inspect
          \{% end %}
          io << '>'
        end

        # Concise display form: `User#1`, or `User#new` when unsaved.
        def to_s( io : IO ) : Nil
          io << \{{@type.name.stringify}} << '#'
          if @id.zero?
            io << "new"
          else
            io << @id
          end
        end

      end

      #--------------------------------------------------------------------------


    end

    #--------------------------------------------------------------------------


  end



end
