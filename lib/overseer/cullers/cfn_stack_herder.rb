require 'stealth_marketplace/aws_wrappers/cfn_client'
require 'stealth_marketplace/aws_resource_cull/herder_definition'

module StealthMarketplace
  module AWSResourceCull
    # Class manages culling logic for ec2 instances
    class CfnStackHerder < HerderDefinition
      def initialize
        @cfn_wrapper = AwsWrappers::CfnClient.new
        super
      end

      def find_resources
        @cfn_wrapper.all_stacks
      end

      def print_resources(resources_to_delete)
        @cfn_wrapper.print_stacks(resources_to_delete)
      end

      def delete_resources(resources_to_delete)
        resources_to_delete.each do |stack|
          @cfn_wrapper.delete_stack(stack.stack_name, async: true)
        end
      end
    end
  end
end