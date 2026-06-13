module Quartz


# Raised by the generated `AModel#save!` when a record fails validation.
# Carries the `Quartz::Errors` collection that triggered the failure.
class EValidation < AError

  getter errors : Quartz::Errors

  def initialize( model : String, @errors : Quartz::Errors )
    super( "#{model} is invalid: #{@errors.full_messages.join( ", " )}" )
  end

end


end
