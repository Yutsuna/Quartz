module Quartz


  class FQuerySet

    # Terminals: evaluate the compose pipeline.

    # Materializes the pipeline into an `Array(TInstance)`.
    def to_a : Array( TInstance )
      @source.call
    end

    # Yields each resulting record. Drives every `Enumerable` mixin.
    def each( & : TInstance -> _ ) : Nil
      to_a.each { |record| yield record }
    end

    # Number of records the pipeline yields.
    def count : Int32
      to_a.size
    end

    # Whether the pipeline yields no record.
    def empty? : Bool
      to_a.empty?
    end

    # Whether the pipeline yields at least one record.
    def any? : Bool
      !empty?
    end

    # alias of `any?`.
    def exists? : Bool
      any?
    end

    # First resulting record, or `nil` when the pipeline is empty.
    def first? : TInstance?
      to_a.first?
    end

    # First resulting record. Raises `ERecordNotFound` when the pipeline is empty.
    def first : TInstance
      first? || raise ERecordNotFound.new( TInstance.name, "first of empty QuerySet" )
    end

    # Last resulting record, or `nil` when the pipeline is empty.
    def last? : TInstance?
      to_a.last?
    end

    # Last resulting record. Raises `ERecordNotFound` when the pipeline is empty.
    def last : TInstance
      last? || raise ERecordNotFound.new( TInstance.name, "last of empty QuerySet" )
    end

  end


end
