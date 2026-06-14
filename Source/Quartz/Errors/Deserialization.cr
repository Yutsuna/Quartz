require "./Error"


module Quartz


  # Raised by the generated `AModel.from_json` when a required field
  # (one declared without a default) is absent from the JSON payload.
  class EDeserialization < AError

    def initialize( model : String, field : String )
      super( "missing required field '#{field}' for #{model}" )
    end

  end


end
