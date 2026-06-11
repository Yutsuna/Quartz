module Quartz


# Raised by `FManager#store` when a record carries an invalid explicit id.
# Valid ids are positive; `0` means "not persisted yet" (auto-assign).
class EInvalidId < AError

  def initialize(model : String, id : UInt64)
    super( "invalid id #{id} for #{model}" )
  end

end


end
