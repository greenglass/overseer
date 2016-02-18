require "overseer/version"
require 'fog'
require 'overseer/wrappers/aws/ec2_client'

module Overseer
  # Your code goes here...
  class Overseer
    def initialize(incoming)
      client = Wrappers::Aws::Ec2_client.new(incoming)
      instance = client.create_instance("id", "type", "sg")
      instance_id = instance.body["instancesSet"].first["instanceId"]
      puts instance_id

      server_instance = client.get_server_instance(instance_id)
      puts server_instance.public_ip_address unless server_instance.nil?

      instances = client.get_all_instances
      instances.each do |inst|
        puts inst.id
      end
    end
  end
end
