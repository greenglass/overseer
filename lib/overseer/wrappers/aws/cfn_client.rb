require 'aws-sdk'
require 'json'
require 'stealth_marketplace/aws_wrappers/s3_client'
require 'stealth_marketplace/aws_wrappers'
require 'stealth_marketplace/cfn_template_type_provider'

module StealthMarketplace
  module AwsWrappers
    # wrapper class for the amazon cfn client
    class CfnClient
      attr_accessor :cfn_client

      def initialize(region = AWS_REGION)
        @cfn_client = Aws::CloudFormation::Client.new(region: region)
        @template_provider = CfnTemplateTypeProvider.new
      end

      def validate_template(template)
        valid_template = @template_provider.provider_template_hash(
          template
        )

        @cfn_client.validate_template(valid_template)
        @template_provider.delete_bucket unless valid_template[:template_url].nil?
      end

      def handle_create_stack(create_output, exception)
        stack_events_response = @cfn_client.describe_stack_events(
          stack_name: create_output.data.stack_id
        )

        stack_events_array = stack_events_response.data.stack_events

        stack_events_formatted = stack_events_array.map do |event|
          "#{event.resource_status}: #{event.resource_status_reason}"
        end

        fail_message = "#{exception}\n" \
          "Last events:\n" \
          "  #{stack_events_formatted.join("\n  ")}\n"
        fail(StealthMarketplaceError, fail_message)
      end

      def create_stack(stack_name, template_body, policy_body, parameters)
        # 51,200 bytes is the max size allowed when using template_body
        @template_provider.bucket = stack_name + '-template-provider'
        template_options = @template_provider.provider_template_hash(
          template_body
        )

        stack_options = template_options.merge(
          stack_name: stack_name,
          stack_policy_body: policy_body,
          parameters: parse_parameters(parameters)
        )

        create_output = @cfn_client.create_stack(
          create_stack_options(stack_options)
        )

        begin
          @cfn_client.wait_until(:stack_create_complete, stack_name: stack_name) do |w|
            w.max_attempts = 120
            w.delay = 30
          end
        rescue => exception
          handle_create_stack(create_output, exception)
        ensure
          @template_provider.delete_bucket unless template_options[:template_url].nil?
        end
      end

      def create_stack_options(options)
        stack_options = {
          notification_arns: [],
          capabilities: ['CAPABILITY_IAM'],
          disable_rollback: true
        }.merge! options
        stack_options
      end

      def delete_stack(stack_name, options = {})
        # Delete buckets first
        s3_client = StealthMarketplace::AwsWrappers::S3Client.new
        bucket_list = list_buckets_in_stack(stack_name)

        bucket_list.each do |bucket|
          s3_client.delete_bucket(bucket, options) rescue Aws::S3::Errors::NoSuchBucket
        end if bucket_list

        @cfn_client.delete_stack(stack_name: stack_name)
        @cfn_client.wait_until(
          :stack_delete_complete,
          stack_name: stack_name
        ) unless options[:async]
      end

      def all_stacks
        @cfn_client.describe_stacks.each_with_object([]) do |resp, obj|
          obj.concat resp.stacks
        end
      end

      def all_stacks_in_all_regions
        ALL_REGIONS.each_with_object({}) do |region, stacks|
          stacks[region] = CfnClient.new(region).all_stacks
        end
      end

      def stacks_matching(stack_name_regex)
        all_stacks.select do |stack|
          stack.stack_name.match(stack_name_regex)
        end
      end

      def cleanup_matching(resource_regex)
        cleanup_stacks_matching resource_regex
      end

      def delete_stacks(stacks_to_delete)
        stacks_to_delete.each do |stack|
          @cfn_client.delete_stack(stack_name: stack.stack_id)
        end
      end

      def list_resources(stack_name)
        @cfn_client.list_stack_resources(stack_name: stack_name)[0]
      end

      def resource_deleteable?(resource)
        resource.physical_resource_id &&
          resource.resource_status != 'DELETE_COMPLETE'
      end

      def list_buckets_in_stack(stack_name)
        list_resource_type_in_stack('AWS::S3::Bucket', stack_name)
      end

      def list_instances_in_stack(stack_name)
        list_resource_type_in_stack('AWS::EC2::Instance', stack_name)
      end

      def list_roles_in_stack(stack_name)
        list_resource_type_in_stack('AWS::IAM::Role', stack_name)
      end

      def list_instance_profiles_in_stack(stack_name)
        list_resource_type_in_stack('AWS::IAM::InstanceProfile', stack_name)
      end

      def list_security_groups_in_stack(stack_name)
        list_resource_type_in_stack('AWS::EC2::SecurityGroup', stack_name)
      end

      def list_resource_type_in_stack(resource_type, stack_name)
        list_resources(stack_name).each_with_object([]) do |resource, collector|
          if resource.resource_type == resource_type &&
             resource_deleteable?(resource)
            collector.push(resource.physical_resource_id)
          end
        end
      end

      def cleanup_stacks_matching(stack_name_regex)
        puts "Cleaning up stacks matching: #{stack_name_regex.inspect}"

        stacks_tc = stacks_to_cleanup_matching(stack_name_regex)
        puts "Stacks to delete:\n" \
          "  #{stacks_tc.map(&:stack_name).join("\n  ")}"

        while stacks_tc.size > 0
          delete_stacks(stacks_tc)

          sleep 3

          stacks_tc = stacks_to_cleanup_matching(stack_name_regex)
        end

        puts 'Done cleaning up stacks!'
      end

      def stacks_to_cleanup_matching(stack_name_regex)
        stacks_matching(stack_name_regex).select do |stack|
          if stack.stack_status == 'DELETE_FAILED'
            puts 'diamondg: This shouldn\'t come up. Ask someone about it.' \
              "\nStatus=#{stack.stack_status}"
          end
          stack.stack_status != 'DELETE_IN_PROGRESS'
        end
      end

      def parse_parameters(hash_parameters)
        hash_parameters.collect do |key, value|
          { parameter_key: key, parameter_value: value }
        end
      end

      def find_security_group(stack_name)
        resp = @cfn_client.describe_stack_resources(stack_name: stack_name)
        resources = resp.data.stack_resources

        group = resources.find do |resource|
          resource.resource_type == 'AWS::EC2::SecurityGroup'
        end

        group && group.physical_resource_id
      end

      def find_bucket(stack_name)
        resp = @cfn_client.describe_stack_resources(stack_name: stack_name)
        resources = resp.data.stack_resources

        bucket_resource = resources.find do |resource|
          resource.resource_type == 'AWS::S3::Bucket'
        end

        bucket_resource && bucket_resource.physical_resource_id
      end

      def find_machine(stack_name)
        resp = @cfn_client.describe_stack_resources(stack_name: stack_name)

        resources = resp.data.stack_resources

        machine_resource = resources.find do |resource|
          resource.resource_type == 'AWS::EC2::Instance'
        end

        machine_resource && machine_resource.physical_resource_id
      end

      def print_stacks(stacks)
        puts format(BASE_RESOURCE_FORMAT, 'Stack Name', 'Age', 'Status')

        stacks.each do |stack|
          puts format(
            BASE_RESOURCE_FORMAT,
            stack.stack_name,
            AwsWrappers.age_string_from_time(stack.creation_time),
            stack.stack_status
          )
        end
      end

      def list_private_ips_in_stack(stack_name)
        instances = list_instances_in_stack(stack_name)
        instances.each_with_object([]) do |instance, collector|
          collector.push(
            StealthMarketplace::AwsWrappers::Ec2Client.new.instance_private_ip(instance)
          )
        end
      end
    end
  end
end
