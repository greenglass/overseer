require 'aws-sdk'
require 'overseer/aws/wrappers'
require 'overseer/aws/wrappers/ec2'

module Overseer
  module AWS
    module Wrappers
      module Ec2
        module Keypairs
          # wrapper for key pairs in ec2
          class KeypairClient
            def initialize
            end

            def print_key_pairs(key_pairs)
              puts format(BASE_RESOURCE_FORMAT, 'Keypair Name', '', '')

              key_pairs.each do |key_pair|
                puts format(
                  BASE_RESOURCE_FORMAT,
                  key_pair.key_name,
                  '',
                  ''
                )
              end
            end

            def all_key_pairs
              @ec2_client.describe_key_pairs.key_pairs
            end

            def find_key_pair_by_instance(instance)
              instance.key_name
            end

            def delete_key_pairs(key_pairs)
              key_pairs.each do |keypair|
                @ec2_client.delete_key_pair(key_name: keypair.key_name)
              end
            end
          end
        end
      end
    end
  end
end
