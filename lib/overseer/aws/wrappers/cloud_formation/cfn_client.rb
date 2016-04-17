require 'aws-sdk'
require 'json'
require 'overseer/aws/wrappers/s3/s3_client'
require 'overseer/aws/wrappers'

module Overseer
  module AWS
    module Wrappers
      module CloudFormation
        # wrapper class for the amazon cfn client
        class CfnClient
          attr_accessor :cfn_client

          def initialize(region = AWS_REGION)
            @cfn_client = Aws::CloudFormation::Client.new(region: region)
          end

          def delete_stack(stack_name, options = {})
            # Delete buckets first
            s3_client = Overseer::Wrappers::S3::S3Client.new
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
              delete_stack(stack_name: stack.stack_id)
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
              if (resource.resource_type == resource_type) && resource_deleteable?(resource)
                collector.push(resource.physical_resource_id)
              end
            end
          end

          def cleanup_stacks_matching(stack_name_regex)
            puts "Cleaning up stacks matching: #{stack_name_regex.inspect}"

            stacks_tc = stacks_to_cleanup_matching(stack_name_regex)
            puts "Stacks to delete:\n" \
              "  #{stacks_tc.map(&:stack_name).join("\n  ")}"

            until stacks_tc.empty?
              delete_stacks(stacks_tc)

              sleep 3

              stacks_tc = stacks_to_cleanup_matching(stack_name_regex)
            end

            puts 'Done cleaning up stacks!'
          end

          def stacks_to_cleanup_matching(stack_name_regex)
            stacks_matching(stack_name_regex).select do |stack|
              if stack.stack_status == 'DELETE_FAILED'
                puts 'This shouldn\'t come up. Ask someone about it.' \
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

          def print_stacks(stacks)
            puts format(BASE_RESOURCE_FORMAT, 'Stack Name', 'Age', 'Status')

            stacks.each do |stack|
              puts format(
                BASE_RESOURCE_FORMAT,
                stack.stack_name,
                Wrappers.age_string_from_time(stack.creation_time),
                stack.stack_status
              )
            end
          end
        end
      end
    end
  end
end
