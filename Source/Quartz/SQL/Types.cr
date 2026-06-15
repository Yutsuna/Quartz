require "db"

module Quartz


  module SQL

    #----------------------------------------------------------------------

    # TODO: in the future optimise the types because we can use tiny int ect...
    SQL_TYPE_MAP = {
        "String"  => "TEXT",
        "Time"    => "TEXT",
        "Bool"    => "INTEGER",
        "Int8"    => "INTEGER",
        "Int16"   => "INTEGER",
        "Int32"   => "INTEGER",
        "Int64"   => "INTEGER",
        "UInt64"  => "INTEGER",
        "Float32" => "REAL",
        "Float64" => "REAL",
    }

    def self.to_sql_type( type : String )
      SQL_TYPE_MAP[ type ]? || "TEXT"
    end

    def self.to_crystal_type( type : String )
      SQL_TYPE_MAP.key( type ) || "String"
    end

    #----------------------------------------------------------------------

    alias NativeType = String | Int8 | Int16 | Int32 | Int64 | UInt64 | Float32 | Float64 | Bool | Time | Nil

    def self.to_db_arg( value : NativeType )
      value
    end

    def self.to_db_arg( value : UInt64 ) : Int64
      value.to_i64
    end

    def self.to_db_arg (value : UInt64? ) : Int64?
      value.try(&.to_i64)
    end

    def self.to_db_arg( value )
      value.to_json
    end

    #----------------------------------------------------------------------

    {% for type in [String, Bool, Int8, Int16, Int32, Int64, Float32, Float64, Time] %}
      def self.from_rs( rs : DB::ResultSet, type : {{type}}.class ) : {{type}}
        rs.read( {{type}} )
      end

      def self.from_rs( rs : DB::ResultSet, type : {{type}}?.class ) : {{type}}?
        rs.read( {{type}}? )
      end
    {% end %}

    def self.from_rs( rs : DB::ResultSet, type : UInt64.class ) : UInt64
      rs.read( Int64 ).to_u64
    end

    def self.from_rs( rs : DB::ResultSet, type : UInt64?.class ) : UInt64?
      rs.read( Int64? ).try(&.to_u64)
    end

    def self.from_rs( rs : DB::ResultSet, type : T.class ) : T forall T
      {% if T.union? && T.union_types.any? { |t| t.stringify == "Nil" } %}
        {% base = T.union_types.find { |t| t.stringify != "Nil" } %}
        rs.read( String? ).try { |s| {{base}}.from_json( s ) }
      {% else %}
        T.from_json( rs.read( String ) )
      {% end %}
    end

    #----------------------------------------------------------------------

    macro sql_type_of( type )
      {% rt = type.stringify %}
      {% if SQL_TYPE_MAP.has_key?( rt ) %}
        {{SQL_TYPE_MAP[ rt ]}}
      {% else %}
        TEXT
      {% end %}
    end

    #----------------------------------------------------------------------


  end


end
