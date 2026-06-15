require "../Query/Predicate"


module Quartz


  # An FAdapter owns where and how records physically live
  # INFO: an in-memory hash today, a SQL table tomorrow.
  #
  # ```
  # FManager( User ).new                                # default: FMemoryAdapter
  # FManager( User ).new( FMemoryAdapter( User ).new )  # explicit
  # ```
  #
  # `TInstance` is expected to be a `Quartz::AModel` subclass.
  abstract class FAdapter( TInstance )

    #--------------------------------------------------------------------------

    # Persists a record, assigning the next id if it has none yet. Returns the
    # record. Storing under an id that is already taken replaces the previous one.
    abstract def store( record : TInstance ) : TInstance

    # Every stored record, in insertion order.
    abstract def all : Array( TInstance )

    # Number of stored records.
    abstract def count : Int32

    # The record with the given id, or `nil`.
    abstract def find?( id : UInt64 ) : TInstance?

    # Oldest stored record, or `nil` when empty.
    abstract def first? : TInstance?

    # Most recently inserted record, or `nil` when empty.
    abstract def last? : TInstance?

    # Removes the record with the given id. Returns `false` if absent.
    abstract def delete( id : UInt64 ) : Bool

    # Removes every record and resets the id sequence.
    abstract def clear : Nil

    #--------------------------------------------------------------------------

    # Evaluates a declarative push-down query: filtering, ordering and pagination.
    # The default implementation interprets the spec in memory over
    # `all` (used by `FMemoryAdapter`); a SQL backend overrides it to compile the
    # spec to `WHERE` / `ORDER BY` / `LIMIT` / `OFFSET` (see `FSqliteAdapter`).
    def fetch( spec : FQuerySpec( TInstance ) ) : Array( TInstance )
      result = all.select { |record| spec.match?( record ) }
      if column = spec.order_column
        result = TInstance._quartz_sorter( column, spec.order_reverse ).call( result )
      end
      if off = spec.offset
        result = result.skip( off )
      end
      if lim = spec.limit
        result = result.first( lim )
      end
      result
    end

    # Number of records the spec yields. Overridable as a `COUNT(*)` push-down.
    def fetch_count( spec : FQuerySpec( TInstance ) ) : Int32
      fetch( spec ).size
    end

    #--------------------------------------------------------------------------

  end


end
