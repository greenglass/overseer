require 'overseer/aws/wrappers/ec2_client'
require 'overseer/aws/cullers/herder_definition'

module Overseer
  module AWS
    module Cullers
      # Class manages culling logic for ec2
      class KeypairHerder < HerderDefinition
        def initialize
          @ec2_wrapper = AwsWrappers::Ec2Client.new
          @cfn_wrapper = AwsWrappers::CfnClient.new
          super
        end

        def find_resources
          find_instanceless_resources
        end

        def print_resources(resources_to_delete)
          @ec2_wrapper.print_key_pairs(resources_to_delete)
        end

        def delete_resources(resources_to_delete)
          @ec2_wrapper.delete_key_pairs(resources_to_delete)
        end

        def find_instanceless_resources
          all_resources = @ec2_wrapper.all_key_pairs
          all_instances = @ec2_wrapper.all_instances

          key_pairs_in_use = all_instances.map do |instance|
            sleep(0.2)
            @ec2_wrapper.find_key_pair_by_instance(instance)
          end

          instanceless_key_pairs = all_resources.reject do |keypair|
            key_pairs_in_use.any? { |instance_keypair| instance_keypair == keypair.key_name }
          end

          instanceless_key_pairs
        end
      end
    end
  end
end
