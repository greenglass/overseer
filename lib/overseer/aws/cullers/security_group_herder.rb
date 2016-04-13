require 'overseer/aws/wrappers/ec2_client'
require 'overseer/aws/cullers/herder_definition'

module Overseer
  module AWS
    module Cullers
      # Class manages culling logic for ec2
      class SecurityGroupHerder < HerderDefinition
        def initialize
          @ec2_wrapper = AwsWrappers::Ec2Client.new
          @cfn_wrapper = AwsWrappers::CfnClient.new
          super
        end

        def find_resources
          find_resources_to_delete
        end

        def print_resources(resources_to_delete)
          @ec2_wrapper.print_security_groups(resources_to_delete)
        end

        def delete_resources(resources_to_delete)
          @ec2_wrapper.delete_security_groups(resources_to_delete)
        rescue Aws::EC2::Errors::DependencyViolation => violation
          puts violation.message + ', can not delete'
        end

        def find_resources_to_delete
          all_resources = @ec2_wrapper.all_security_groups
          all_instances = @ec2_wrapper.all_instances
          all_stacks = @cfn_wrapper.all_stacks

          resources_to_delete = find_instanceless_resources(
            all_instances,
            all_resources
          )

          resources_to_delete = find_stackless_resources(
            all_stacks,
            resources_to_delete
          )

          resources_to_delete
        end

        def find_instanceless_resources(instances, resources)
          security_groups_in_use = instances.map do |instance|
            sleep(0.2)
            @ec2_wrapper.find_security_group_ids_by_instance(instance)
          end

          instanceless_security_groups = filter_security_groups_by_id(
            security_groups_in_use.flatten,
            resources
          )

          instanceless_security_groups
        end

        def find_stackless_resources(stacks, resources)
          security_groups_in_stacks = stacks.map do |stack|
            sleep(0.2)
            begin
              @cfn_wrapper.list_security_groups_in_stack(stack.stack_name)
            rescue Aws::CloudFormation::Errors::ValidationError
              puts 'No security group found in stack ' + stack.stack_name
            end
          end.compact

          stackless_sgs = filter_security_groups_by_id(
            security_groups_in_stacks.flatten,
            resources
          )

          stackless_sgs
        end

        def filter_security_groups_by_id(security_groups_being_used, resources)
          resources.reject do |sg|
            security_groups_being_used.include? sg.group_id
          end
        end
      end
    end
  end
end
