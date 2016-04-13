require 'overseer/aws/wrappers/iam_client'
require 'overseer/aws/cullers/herder_definition'

module Overseer
  module AWS
    module Cullers
      # Class manages culling logic for IAM Instance Profiles
      class IamInstanceProfileHerder < HerderDefinition
        def initialize
          @iam_wrapper = AwsWrappers::IamClient.new
          @cfn_wrapper = AwsWrappers::CfnClient.new
          super
        end

        def find_resources
          find_stackless_resources
        end

        def print_resources(resources_to_delete)
          @iam_wrapper.print_instance_profiles(resources_to_delete)
        end

        def delete_resources(resources_to_delete)
          @iam_wrapper.delete_instance_profiles(resources_to_delete)
        end

        def find_stackless_resources
          all_instance_profiles = @iam_wrapper.all_instance_profiles
          all_stacks = @cfn_wrapper.all_stacks_in_all_regions

          instance_profile_ids_in_stacks =
            all_stacks.keys.each_with_object([]) do |region, instance_profiles|
              cfn = AwsWrappers::CfnClient.new(region)
              instance_profiles.concat(all_stacks[region].flat_map do |stack|
                sleep(0.2)
                cfn.list_instance_profiles_in_stack(stack.stack_name)
              end)
            end

          stackless_instance_profiles = all_instance_profiles.reject do |profile|
            instance_profile_ids_in_stacks.include?(profile.instance_profile_name)
          end
          stackless_instance_profiles
        end
      end
    end
  end
end
