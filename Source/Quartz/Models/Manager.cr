module Quartz


  # In-memory record store
  #
  # One instance exists per model class (created by `AModel.inherited`).
  # Records are kept in an id-indexed hash.
  # ids are assigned sequentially on first store.
  #
  # ```
  # User.objects.create( name: "Léo", age: 24 )
  # User.objects.all
  # User.objects.find(1)
  # User.objects.where { |u| u.age > 20 }
  # ```
  #
  # Contract on `TInstance`
  #
  #   `TInstance` is expected to be a `Quartz::AModel` subclass.
  #   The manager relies on the API its macros generate:
  #   `TInstance.new(**args)`, `TInstance.fields`, `#id`/`#id=`
  #   (with `0` meaning "not persisted") and `#[](String)`.
  #
  # Sharing and thread safety:
  #
  #   The *index* (hash + id sequence) is synchronized with a `Mutex`
  #   query esults hold live references to the stored records (identity-map semantics),
  #   the records themselves are plain mutable objects with no synchronization of their own.
  #
  #   Mutating a returned record is visible to every holder of the reference.
  #   persist field changes with `#save`.
  #
  # NOTE:
  #   Reassigning `record.id` by hand is unsupported.
  #   store` re-keys the record, but stale reads may occur in between.
  class FManager( TInstance )

    #--------------------------------------------------------------------------

    def initialize
      @records = {} of UInt64 => TInstance
      @next_id = 1_u64
      @mutex = Mutex.new
    end

    #--------------------------------------------------------------------------

    # Instantiates a record from keyword arguments and persists it.
    def create( **args ) : TInstance
      store( TInstance.new( **args ) )
    end

    # Persists a record, assigning the next id if it has none yet.
    #
    # Used by `AModel#save`.
    # Storing a record under an id that is already taken replaces the previous record.
    #
    # Raises:
    #   `EInvalidId` for a negative explicit id.
    def store( record : TInstance ) : TInstance
      @mutex.synchronize {

        if ! record.persisted?
          record.id = @next_id
          @next_id += 1

        elsif record.id.negative?
          raise EInvalidId.new( TInstance.name, record.id )

        elsif record.id >= @next_id
          # INFO: advance the sequence before inerting
          # -> prevents a collision if the record is already present in the store
          # -> prevents an overflow from leaving the store in a broken state
          @next_id = record.id + 1
        end
        # Drop any stale entry left behind by a manual id reassignment.
        @records.reject! { |key, existing| key != record.id && existing.same?( record ) }
        @records[ record.id ] = record
      }
      record
    end

    def all : Array( TInstance )
      @mutex.synchronize { @records.values }
    end

    def count : Int32
      @mutex.synchronize { @records.size }
    end

    # Returns the record with the given id, or raises `ERecordNotFound`.
    def find( id : Int64 ) : TInstance
      find?(id ) || raise ERecordNotFound.new( TInstance.name, id )
    end

    # Returns the record with the given id, or `nil`.
    def find?( id : Int64 ) : TInstance?
      @mutex.synchronize { @records[id]? }
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

    # Returns every record for which the block is truthy.
    def where( & : TInstance -> Bool ) : Array( TInstance )
      all.select { |record| yield record }
    end

    # Oldest stored record, or `nil` when empty.
    def first? : TInstance?
      @mutex.synchronize { @records.empty? ? nil : @records.first_value }
    end

    # Most recently inserted record, or `nil` when empty.
    def last? : TInstance?
      @mutex.synchronize {
        last = nil
        @records.each_value { |record| last = record }
        last
      }
    end

    # Removes the record with the given id. Returns `false` if absent.
    def delete(id : Int64) : Bool
      @mutex.synchronize { !@records.delete(id).nil? }
    end

    # Removes every record and resets the id sequence. Mainly for specs:
    # freed ids are reused afterwards, so never call it while stale ids are
    # held elsewhere.
    def clear : Nil
      @mutex.synchronize {
        @records.clear
        @next_id = 1_u64
      }
    end

    #--------------------------------------------------------------------------

    private def _validate_field_names(**args) : Nil
      args.each { |key, _value|
        name = key.to_s
        unless name == "id" || T.fields.includes?(name)
          raise UnknownField.new(T.name, name)
        end
      }
    end

    private def _matches?(record : T, **args) : Bool
      args.each { |key, value|  return false unless record[key.to_s] == value }
      true
    end

    #--------------------------------------------------------------------------

  end


end
