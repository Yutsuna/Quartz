require "db"


module Quartz


  # Comparison operator of a single pushed-down condition.
  enum FOp
    Eq
    Ne
    Gt
    Gte
    Lt
    Lte
    In

    # The SQL token for this operator (the `IN` list is built by the adapter).
    def to_sql : String
      case self
      in Eq  then "="
      in Ne  then "!="
      in Gt  then ">"
      in Gte then ">="
      in Lt  then "<"
      in Lte then "<="
      in In  then "IN"
      end
    end
  end


  # A single declarative comparison over one column, e.g. `age >= 18`.
  #
  # The *representable* form of a query atom, built from native Crystal values.
  # It carries no closure, so a SQL backend compiles it to parameterized SQL.
  struct FPredicate

    getter column : String
    getter op : FOp
    # Bound value for scalar ops; `nil` for `In` (see `#values`).
    getter value : DB::Any
    # Bound values for the `In` operator; empty otherwise.
    getter values : Array(DB::Any)

    def initialize( @column : String, @op : FOp, @value : DB::Any = nil, @values : Array( DB::Any ) = [] of DB::Any )
    end

  end


  # One `where`/`exclude` keyword condition: the (AND-composed) predicates it
  # expands to, plus whether the whole group is negated (`exclude`). A SQL
  # backend emits `[NOT] (p1 AND p2 ...)`; a `Range` yields the two-bound group.
  struct FCondition

    getter predicates : Array( FPredicate )
    getter negated : Bool

    def initialize( @predicates : Array( FPredicate ), @negated : Bool )
    end

  end


  # A fully representable query: a set of AND-composed conditions plus optional
  # ordering and pagination. Produced by a model's macro-generated, type-safe
  # `_q_*` helpers (see `Model.cr`) and consumed by `FAdapter#fetch`.
  #
  # It is *dual*:
  #   - `predicates` / `order_column` / `limit` / `offset` are the declarative
  #     form a SQL backend compiles (`FSqliteAdapter#fetch`).
  #   - `matchers` are typed closures built in the model's own context, so the
  #     in-memory backend (`FAdapter#fetch`'s default) evaluates the very same
  #     query with no untyped comparisons.
  class FQuerySpec( T )

    property conditions : Array( FCondition )
    property matchers : Array( Proc( T, Bool ) )
    property order_column : String?
    property order_reverse : Bool
    property limit : Int32?
    property offset : Int32?

    def initialize
      @conditions = [] of FCondition
      @matchers = [] of Proc( T, Bool )
      @order_column = nil
      @order_reverse = false
      @limit = nil
      @offset = nil
    end

    # A shallow copy whose arrays are independent, so chained transforms never
    # mutate an upstream spec.
    def _copy : FQuerySpec( T )
      spec = FQuerySpec( T ).new
      spec.conditions = @conditions.dup
      spec.matchers = @matchers.dup
      spec.order_column = @order_column
      spec.order_reverse = @order_reverse
      spec.limit = @limit
      spec.offset = @offset
      spec
    end

    # Whether `record` satisfies every condition (in-memory evaluation).
    def match?( record : T ) : Bool
      @matchers.all? { |m| m.call( record ) }
    end

    #--------------------------------------------------------------------------
    # Condition builders. Called by the model's typed `_q_*` helpers with a
    # `getter` closure reading the field — so all comparisons stay typed.

    # Adds a condition from a native Crystal value, dispatching on its shape:
    # `Range` -> bound comparisons, `Array` -> `IN`, op-`NamedTuple` -> the named
    # operator, anything else -> equality. `negated` flips the match (`exclude`).
    # `getter` reads the field off a record, so every comparison stays typed.
    def add( column : String, value : V, negated : Bool, &getter : T -> _ ) : Nil forall V
      get = getter
      preds = [] of FPredicate
      case value
      when ::Range
        if b = value.begin
          preds << FPredicate.new( column, FOp::Gte, Quartz._db_any( b ) )
        end
        if e = value.end
          preds << FPredicate.new( column, value.excludes_end? ? FOp::Lt : FOp::Lte, Quartz._db_any( e ) )
        end
        _push( negated ) { |record| value.includes?( get.call( record ) ) }
      when ::Array
        members = Array( DB::Any ).new( value.size ) { |i| Quartz._db_any( value[ i ] ) }
        preds << FPredicate.new( column, FOp::In, nil, members )
        _push( negated ) { |record| value.includes?( get.call( record ) ) }
      when ::NamedTuple
        value.each do |key, operand|
          op = _op_for( key )
          preds << FPredicate.new( column, op, Quartz._db_any( operand ) )
          _push( negated ) { |record| _cmp( get.call( record ), op, operand ) }
        end
      else
        preds << FPredicate.new( column, FOp::Eq, Quartz._db_any( value ) )
        _push( negated ) { |record| get.call( record ) == value }
      end
      @conditions << FCondition.new( preds, negated )
    end

    # Appends a matcher, applying negation once.
    private def _push( negated : Bool, &predicate : T -> Bool ) : Nil
      pred = predicate
      @matchers << ->( record : T ) { negated ? !pred.call( record ) : pred.call( record ) }
    end

    private def _op_for( key : Symbol ) : FOp
      case key
      when :eq  then FOp::Eq
      when :ne  then FOp::Ne
      when :gt  then FOp::Gt
      when :gte then FOp::Gte
      when :lt  then FOp::Lt
      when :lte then FOp::Lte
      else raise ArgumentError.new( "unknown operator #{key}" )
      end
    end

    # Typed comparison of two same-typed operands for the op-`NamedTuple` form.
    private def _cmp( a, op : FOp, b ) : Bool
      case op
      in FOp::Eq  then a == b
      in FOp::Ne  then a != b
      in FOp::Gt  then ( a <=> b ) > 0
      in FOp::Gte then ( a <=> b ) >= 0
      in FOp::Lt  then ( a <=> b ) < 0
      in FOp::Lte then ( a <=> b ) <= 0
      in FOp::In  then false
      end
    end

  end


  # Coerces a native Crystal value to `DB::Any` for parameter binding:
  # `UInt64` (the `belongs_to` FK type) -> `Int64`, native scalars/`Time`/`nil`
  # as-is, anything else (e.g. `Array(String)` elements) -> its JSON text.
  def self._db_any( value ) : DB::Any
    case value
    when UInt64 then value.to_i64
    when DB::Any then value
    else value.to_json
    end
  end


end
