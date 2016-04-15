require 'aws-sdk'
require 'overseer/aws/wrappers'

module Overseer
  module AWS
    module Wrappers
      # wrapper for amazon ec2 client
      module Ec2
        attr_accessor :ec2_client

        EC2_PRINT_FORMAT = "#{BASE_RESOURCE_FORMAT}    %-13s".freeze
        SUPPORTED_REGIONS = ['us-east-1', 'us-west-2'].freeze

        @ec2_client = Aws::EC2::Client.new(region: AWS_REGION)

        def region_endpoints
          @ec2_client.describe_regions.regions.map(&:endpoint)
        end

        def find_vpc_id(vpc_name)
          vpcs = @ec2_client.describe_vpcs.vpcs

          vpc = vpcs.find { |v| v.tags.find { |t| t.key == 'Name' && t.value == vpc_name } }

          raise OverseerError, "VPC doesn't exist - VPC name: #{vpc_name}" unless vpc

          vpc.vpc_id
        end

        def find_subnet_id(vpc_id, subnet_name)
          subnets = @ec2_client.describe_subnets(
            filters: [
              { name: 'vpc-id', values: [vpc_id] },
              { name: 'tag:Name', values: [subnet_name] }
            ]
          ).subnets

          raise(
            OverseerError,
            'More than one with subnet with requested name'
          ) if subnets.size > 1

          raise(
            OverseerError,
            "No subnet found: vpc_id=#{vpc_id} subnet_name=#{subnet_name}"
          ) if subnets.empty?

          subnets.first.subnet_id
        end
      end
    end
  end
end
