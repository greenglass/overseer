require 'overseer/aws/wrappers/ec2_client'
require 'overseer/aws/wrappers/cfn_client'
require 'overseer/aws/cullers/herder_definition'

module Overseer
  module AWS
    module Cullers
      # Class manages culling logic for ec2 instances
      class StacklessEc2Herder < HerderDefinition
        def initialize
          @cfn_wrapper = Wrappers::CfnClient.new
          @ec2_wrapper = Wrappers::Ec2Client.new
          super
        end

        def find_resources
          instances = find_stackless_instances

          # a little bit of magic to give each instance a name attribute
          # so it's nicer to use in the cullfile
          instances.each do |inst|
            class << inst
              attr_accessor :name
            end
            inst.name = @ec2_wrapper.get_instance_name(inst)
          end
        end

        def print_resources(resources_to_delete)
          @ec2_wrapper.print_ec2s(resources_to_delete)
        end

        def delete_resources(resources_to_delete)
          resources_to_delete.each do |inst|
            @ec2_wrapper.terminate_instance(inst)
          end
        end

        def find_stackless_instances
          all_stacks = @cfn_wrapper.all_stacks
          all_instances = @ec2_wrapper.all_instances

          running_instances = all_instances.reject do |inst|
            ['stopped', 'shutting-down', 'terminated'].any? do |state|
              state == inst.state.name
            end
          end

          ec2s_in_stacks = all_stacks.map do |stack|
            sleep(0.4) # to avoid throttling exception from querying aws too fast
            begin
              @cfn_wrapper.find_machine(stack.stack_name)
            rescue Aws::CloudFormation::Errors::ValidationError
              puts 'No machine found in stack ' + stack.stack_name
            end
          end.compact

          stackless_ec2s = running_instances.reject do |inst|
            ec2s_in_stacks.any? { |ec2_stack| ec2_stack == inst.instance_id }
          end

          stackless_ec2s
        end
      end
    end
  end
end
