module Overseer
  module AWS
    module Cullers
      # Class that defines what is expected for
      # additional child class implementations
      # Acts as an interface
      class HerderDefinition
        NOT_IMPLEMENTED = 'Not yet implemented, must be in child class'

        # Not yet implemented gets called when not
        # implemented by child class
        def find_resources
          fail NOT_IMPLEMENTED
        end

        def print_resources(_resources_to_delete)
          fail NOT_IMPLEMENTED
        end

        def delete_resources(_resources_to_delete)
          fail NOT_IMPLEMENTED
        end
      end
    end
  end
end
