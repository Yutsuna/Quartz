require "./Field"
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

    # Runs this record's validations into `errors`.
    # Overridden per class by the `finished` hook when validations are declared
    protected def _quartz_validate( errors : Quartz::Errors ) : Nil
    end

    # Lifecycle callback chains (see `Callbacks.cr`). No-op base versions so the
    # `super`-chained per-class seeds (emitted by `macro inherited`) bottom out
    # here for models that declare no callbacks. Public (despite the internal
    # `_quartz_` prefix) because `FManager#store` fires the save hooks.
    def _quartz_before_create : Nil
    end

    def _quartz_after_create : Nil
    end

    def _quartz_before_save : Nil
    end

    def _quartz_after_save : Nil
    end

    def _quartz_before_delete : Nil
    end

    def _quartz_after_delete : Nil
    end

    # Validation errors for this record, recomputed on each call.
    def errors : Quartz::Errors
      errs = Quartz::Errors.new
      _quartz_validate( errs )
      errs
    end

    # Whether the record passes every declared validation.
    def valid? : Bool
      errors.empty?
    end

    #--------------------------------------------------------------------------

    macro inherited
      # Macro-time registry of the fields declared directly on this class, filled by `field`.
      # Constant mutation at macro time is the established idiom (Granite, Avram).
      #
      # Unlike runtime side effects emitted from `inherited`, it works in the interpreter.
      # The `finished` hook below merges it with every ancestor registry.
      QUARTZ_FIELDS = [] of Nil

      # Seed override that begins this class's validation chain by deferring to
      # the ancestor chain. Each `validates` / `validate` (see `Validations.cr`)
      # redefines `_quartz_validate` and chains to here with `previous_def`, so
      # ancestor rules run via `super` and own rules accumulate in order.
      protected def _quartz_validate( errors : Quartz::Errors ) : Nil
        super
      end

      # Per-class seeds that begin each lifecycle-callback chain by deferring to
      # the ancestor chain. Each `before_*` / `after_*` macro (see `Callbacks.cr`)
      # redefines its hook with `previous_def`, so ancestor hooks run via `super`
      # and own hooks accumulate in declaration order — exactly like validations.
      {% for hook in %w(before_create after_create before_save after_save before_delete after_delete) %}
        def _quartz_{{hook.id}} : Nil
          super
        end
      {% end %}

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

        # Union of `UInt64` (id) and every field type. Return type of `to_h`
        # and `[]`.
        alias FieldValue = UInt64 \{% for d in fields %} | \{{d.type}} \{% end %}

        # Keyword-only constructor over every field (inherited ones included)
        # Defaults declared on `field` apply.
        def initialize(
          \{% unless fields.empty? %}*, \{% end %}
          \{% for d in fields %}
          @\{{d.var}} : \{{d.type}}\{% unless d.value.is_a?( Nop ) %} = \{{d.value}}\{% end %},
          \{% end %}
        )
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

        # Field access by name. Raises `Quartz::EUnknownField` for a name
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
            raise Quartz::EUnknownField.new( \{{@type.name.stringify}}, name )
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
        def hash( hasher ) : Crystal::Hasher
          hasher = @id.hash( hasher )
          \{% for d in fields %}
          hasher = @\{{d.var}}.hash( hasher )
          \{% end %}
          hasher
        end

        # JSON object of the record: `"id"` first, then every field. Defining the
        # `JSON::Builder` overload gives `to_json` (String) and `to_json(io)` for
        # free via the stdlib `Object` overloads.
        def to_json( json : JSON::Builder ) : Nil
          json.object do
            json.field( "id", @id )
            \{% for d in fields %}
            json.field( \{{d.var.stringify}}, @\{{d.var}} )
            \{% end %}
          end
        end

        # Builds a transient record (id 0 unless an `"id"` key is present) from a
        # JSON string. Absent keys fall back to the field's default; an absent
        # required field (one with no default) raises `Quartz::EDeserialization`.
        # Does not persist or validate, mirroring `new`.
        def self.from_json( string : String ) : self
          any = JSON.parse( string )
          record = new(
            \{% for d in fields %}
            \{{d.var}}: (
              if node = any[ \{{d.var.stringify}} ]?
                ( \{{d.type}} ).new( JSON::PullParser.new( node.to_json ) )
              else
                \{% if d.value.is_a?( Nop ) %}
                raise Quartz::EDeserialization.new( \{{@type.name.stringify}}, \{{d.var.stringify}} )
                \{% else %}
                \{{d.value}}
                \{% end %}
              end
            ),
            \{% end %}
          )
          if id_node = any[ "id" ]?
            record.id = id_node.as_i64.to_u64
          end
          record
        end

        #--------------------------------------------------------------------------

        \{% unless @type.abstract? %}
          # Persists the record through the model's manager, assigning an
          # id on first save. The save lifecycle callbacks (see `Callbacks.cr`)
          # fire inside `FManager#store`, the shared persist choke point.
          def save : self
            \{{@type}}.objects.store( self )
          end

          # Validates, then persists. Raises `Quartz::EValidation`
          # (carrying the `errors`) when the record is invalid.
          # Inherits `save`'s callbacks (fired after validation passes).
          def save! : self
            errs = errors
            raise Quartz::EValidation.new( \{{@type.name.stringify}}, errs ) unless errs.empty?
            save
          end

          # Removes the record from the model's manager and resets its id,
          # so `persisted?` becomes `false` again. Fires `before_delete` before
          # the removal and `after_delete` only when a record was actually removed.
          def delete : Bool
            _quartz_before_delete
            deleted = \{{@type}}.objects.delete(@id)
            if deleted
              @id = 0_i64
              _quartz_after_delete
            end
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
