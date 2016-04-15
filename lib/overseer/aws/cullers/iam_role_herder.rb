require 'overseer/aws/wrappers/iam_client'
require 'overseer/aws/cullers/herder_definition'

module Overseer
  module AWS
    module Cullers
      # Class manages culling logic for IAM Roles
      class IamRoleHerder < HerderDefinition
        def initialize
          @iam_wrapper = Wrappers::IamClient.new
          @cfn_wrapper = Wrappers::CfnClient.new
          super
        end

        def find_resources
          find_stackless_resources
        end

        def print_resources(resources_to_delete)
          @iam_wrapper.print_roles(resources_to_delete)
        end

        def delete_resources(resources_to_delete)
          @iam_wrapper.delete_roles(resources_to_delete)
        end

        def find_stackless_resources
          all_roles = @iam_wrapper.all_roles
          all_stacks = @cfn_wrapper.all_stacks_in_all_regions

          role_ids_in_stacks =
            all_stacks.keys.each_with_object([]) do |region, roles|
              cfn = Wrappers::CfnClient.new(region)
              roles.concat(all_stacks[region].flat_map do |stack|
                sleep(0.2)
                cfn.list_roles_in_stack(stack.stack_name)
              end)
            end

          stackless_roles = all_roles.reject do |role|
            role_ids_in_stacks.include?(role.role_name)
          end

          stackless_roles
        end
      end
    end
  end
end
