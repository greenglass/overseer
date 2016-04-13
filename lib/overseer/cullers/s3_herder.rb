require 'stealth_marketplace/aws_wrappers/s3_client'
require 'stealth_marketplace/aws_resource_cull/herder_definition'

module StealthMarketplace
  module AWSResourceCull
    # Class manages culling logic for s3
    class S3Herder < HerderDefinition
      def initialize
        @s3_wrapper = AwsWrappers::S3Client.new
        @cfn_wrapper = AwsWrappers::CfnClient.new
        super
      end

      def find_resources
        find_stackless_resources
      end

      def print_resources(resources_to_delete)
        @s3_wrapper.print_s3s(resources_to_delete)
      end

      def delete_resources(resources_to_delete)
        @s3_wrapper.delete_buckets(resources_to_delete)
      rescue Aws::S3::Errors::AccessDenied => access_denied
        puts access_denied.message + ', not deleting'
      end

      def find_stackless_resources
        all_resources = @s3_wrapper.all_buckets
        all_stacks = @cfn_wrapper.all_stacks

        s3_buckets_in_stacks = all_stacks.map do |stack|
          sleep(0.2)
          begin
            @cfn_wrapper.find_bucket(stack.stack_name)
          rescue Aws::CloudFormation::Errors::ValidationError
            puts 'No bucket found in stack ' + stack.stack_name
          end
        end.compact

        stackless_s3s = all_resources.reject do |s3|
          s3_buckets_in_stacks.any? { |s3_stack| s3_stack == s3.name }
        end

        stackless_s3s
      end
    end
  end
end
