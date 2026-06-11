module Quartz


# Raised by the generated `AModel#[]` and by `Manager#find_by`
# when a field name is not declared on the model.
class EUnknownField < AError

  def initialize( model : String, field : String )
    super( "unknown field '#{field}' on #{model}" )
  end

end


end
