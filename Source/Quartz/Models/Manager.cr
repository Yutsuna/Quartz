require "../Adapters/Adapter"
require "../Adapters/Memory"
require "../Query/QuerySet"


module Quartz


  # Query facade over a pluggable storage backend.
  #
  # One instance exists per model class (created by `AModel.inherited`).
  # `FManager` owns the *query* API; physical persistence is delegated to an
  # `FAdapter`, injected at construction and defaulting to `FMemoryAdapter`.
  # Swapping the adapter swaps the backend with no change to the manager,
  # the models, or the specs.
  #
  # ```
  # User.objects.create( name: "Léo", age: 24 )
  # User.objects.all
  # User.objects.find(1)
  # User.objects.where { |u| u.age > 20 }
  # User.objects.filter { |u| u.age > 20 }.order_by { |u| u.age }   # lazy
  # ```
  class FManager( TInstance )

    #--------------------------------------------------------------------------

    def initialize( @adapter : FAdapter( TInstance ) = FMemoryAdapter( TInstance ).new )
    end

    #--------------------------------------------------------------------------
    # Storage primitives: delegated to the adapter.

    # Persists a record, assigning the next id if it has none yet.
    #
    # `before_save` -> (`before_create` if new) → store → (`after_create` if new)
    # `after_save`  -> The adapter's own `store` is the raw, hook-free primitive.
    def store( record : TInstance ) : TInstance
      new_record = !record.persisted?
      record._quartz_before_save
      record._quartz_before_create if new_record
      @adapter.store( record )
      record._quartz_after_create if new_record
      record._quartz_after_save
      record
    end

    def all : Array( TInstance )
      @adapter.all
    end

    def count : Int32
      @adapter.count
    end

    # Returns the record with the given id, or `nil`.
    def find?( id : UInt64 ) : TInstance?
      @adapter.find?( id )
    end

    # Oldest stored record, or `nil` when empty.
    def first? : TInstance?
      @adapter.first?
    end

    # Most recently inserted record, or `nil` when empty.
    def last? : TInstance?
      @adapter.last?
    end

    # Removes the record with the given id. Returns `false` if absent.
    def delete( id : UInt64 ) : Bool
      @adapter.delete( id )
    end

    # Removes every record and resets the id sequence. Mainly for specs.
    def clear : Nil
      @adapter.clear
    end

    #--------------------------------------------------------------------------
    # Derived query API: composed on top of the storage primitives.

    # Instantiates a record from keyword arguments, validates it, and persists it.
    # Raises `Quartz::EValidation` when the record is invalid.
    def create( **args ) : TInstance
      record = TInstance.new( **args )
      errs = record.errors
      raise EValidation.new( TInstance.name, errs ) unless errs.empty?
      store( record )
    end

    # Returns the record with the given id, or raises `ERecordNotFound`.
    def find( id : UInt64 ) : TInstance
      find?( id ) || raise ERecordNotFound.new( TInstance.name, id )
    end

    # Returns the first record whose fields match every given keyword
    # argument, or raises `ERecordNotFound`.
    #
    # ```
    # User.objects.find_by(name: "Bob")
    # ```
    def find_by( **args ) : TInstance
      find_by?( **args ) || raise ERecordNotFound.new( TInstance.name, args.to_s )
    end

    # Returns the first record whose fields match
    # every given keyword argument, or `nil`.
    #
    # Field names are validated against the model's schema up front,
    # so a mistyped name raises `EUnknownField` even on an empty store.
    def find_by?( **args ) : TInstance?
      _validate_field_names( **args )
      all.find { |record| _matches?( record, **args ) }
    end

    # Returns every record for which the block is truthy (eager `Array`).
    # For a lazy, chainable equivalent see `#filter` / `#query`.
    def where( & : TInstance -> Bool ) : Array( TInstance )
      all.select { |record| yield record }
    end

    #--------------------------------------------------------------------------

    # A lazy `FQuerySet` over every record — the canonical query entry point.
    # The set re-reads `all` on each terminal call, reflecting live state.
    def query : FQuerySet( TInstance )
      FQuerySet( TInstance ).new( -> { all } )
    end

    # Lazy, chainable filter (the composable sibling of `#where`).
    def filter( & block : TInstance -> Bool ) : FQuerySet( TInstance )
      query.filter( &block )
    end

    # Lazy, chainable inverse filter.
    def exclude( & block : TInstance -> Bool ) : FQuerySet( TInstance )
      query.exclude( &block )
    end

    # Lazy, chainable ordering by the key the block returns.
    def order_by( reverse : Bool = false, & block : TInstance -> _ ) : FQuerySet( TInstance )
      query.order_by( reverse, &block )
    end

    #--------------------------------------------------------------------------

    private def _validate_field_names(**args) : Nil
      args.each { |key, _value|
        name = key.to_s
        unless name == "id" || TInstance.fields.includes?( name )
          raise EUnknownField.new( TInstance.name, name )
        end
      }
    end

    private def _matches?( record : TInstance, **args ) : Bool
      args.each { |key, value|  return false unless record[ key.to_s ] == value }
      true
    end

    #--------------------------------------------------------------------------

  end


end
