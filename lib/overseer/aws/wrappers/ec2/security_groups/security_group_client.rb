require 'aws-sdk'
require 'overseer/aws/wrappers'
require 'overseer/aws/wrappers/ec2'

module Overseer
  module AWS
    module Wrappers
      module Ec2
        module SecurityGroups
          # wrapper for security groups in ec2
          class SecurityGroupClient
            def initialize
            end

            def all_security_groups
              @ec2_client.describe_security_groups.security_groups
            end

            def find_security_group_id(vpc_id, group_name)
              groups = @ec2_client.describe_security_groups(
                filters: [
                  { name: 'vpc-id', values: [vpc_id] },
                  { name: 'group-name', values: [group_name] }
                ]
              ).security_groups

              raise(
                OverseerError,
                'More than one security group with requested name'
              ) if groups.size > 1

              raise(
                OverseerError,
                "Security group doesn't exist: vpc_id=#{vpc_id} group_name=#{group_name}"
              ) if groups.empty?

              groups.first.group_id
            end

            def find_security_group_ids_by_instance(instance)
              groups = instance.security_groups
              groups.collect(&:group_id)
            end

            def delete_security_groups(security_groups)
              security_groups.each do |sg|
                @ec2_client.delete_security_group(
                  group_id: sg.group_id
                )
              end
            end

            def print_security_groups(security_groups)
              puts format(BASE_RESOURCE_FORMAT, 'Security Group Name', 'Security Group Id', '')

              security_groups.each do |sg|
                puts format(
                  BASE_RESOURCE_FORMAT,
                  sg.group_name,
                  sg.group_id,
                  ''
                )
              end
            end
          end
        end
      end
    end
  end
end
