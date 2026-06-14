require "./Adapter"


module Quartz


  # In-memory adapter for Quartz models.
  # Records are stored in a Hash, keyed by their `id`.
  # The adapter is thread-safe, but the records themselves are not.
  class FMemoryAdapter( TInstance ) < FAdapter( TInstance )

    #--------------------------------------------------------------------------

    def initialize
      @records = {} of UInt64 => TInstance
      @next_id = 1_u64
      @mutex = Mutex.new
    end

    #--------------------------------------------------------------------------

    # Persists a record, assigning the next id if it has none yet.
    def store( record : TInstance ) : TInstance
      @mutex.synchronize {

        if ! record.persisted?
          record.id = @next_id
          @next_id += 1

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

    # Returns the record with the given id, or `nil`.
    def find?( id : UInt64 ) : TInstance?
      @mutex.synchronize { @records[id]? }
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
    def delete( id : UInt64 ) : Bool
      @mutex.synchronize { !@records.delete( id ).nil? }
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

  end


end
