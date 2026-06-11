module Quartz


# Raised by `Manager#store` when a record carries an invalid explicit id.
# Valid ids are positive; `0` means "not persisted yet" (auto-assign).
class InvalidId < AError

  def initialize(model : String, id : Int64)
    super( "invalid id #{id} for #{model} — ids must be positive" )
  end

end

end
