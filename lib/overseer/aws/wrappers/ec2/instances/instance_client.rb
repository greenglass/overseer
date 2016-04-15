require 'aws-sdk'
require 'overseer/aws/wrappers'
require 'overseer/aws/wrappers/ec2'

module Overseer
  module AWS
    module Wrappers
      module Ec2
        module Instances
          # class to handle instances of the ec2 service
          class InstanceClient
            def initialize
            end

            def get_instance_info(instance_id)
              @ec2_client.describe_instances(instance_ids: [instance_id])
            rescue Aws::EC2::Errors::InvalidInstanceIDNotFound
              LOGGER.warn "get_instance_info: instance #{instance_id} does not exist"
              nil
            end

            def terminate_instance(instance)
              @ec2_client.terminate_instances(instance_ids: [instance.instance_id])
            end

            def find_instance(instance_id)
              Aws::EC2::Resource.new(client: @ec2_client).instance(instance_id)
            end

            def all_instances
              @ec2_client.describe_instances(
                max_results: 100_000
              ).reservations.flat_map(&:instances)
            end

            def print_instances(ec2_instances)
              puts format(
                EC2_PRINT_FORMAT,
                'EC2 Name',
                'Age',
                'Status',
                'Instance ID'
              )

              sorted_instances = ec2_instances.sort do |a, b|
                a.launch_time <=> b.launch_time
              end.reverse

              sorted_instances.each do |inst|
                puts make_instance_string(inst)
              end
            end

            def make_instance_string(instance)
              format(
                EC2_PRINT_FORMAT,
                get_instance_name(instance),
                AwsWrappers.age_string_from_time(instance.launch_time),
                instance.state.name,
                instance.instance_id
              )
            end

            def get_instance_name(instance)
              name_tag = instance.tags.find { |tag| tag.key == 'Name' }

              (name_tag && !name_tag.value.strip.empty? && name_tag.value) ||
                ''
            end
          end
        end
      end
    end
  end
end
