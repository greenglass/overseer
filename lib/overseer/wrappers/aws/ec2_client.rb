module Overseer
  module Wrappers
    module Aws
      class Ec2_client
        attr_reader :compute_client
        def initialize(client)
          @compute_client = client
        end

        def create_instance(ami_id, instance_type, sg)
          response = compute_client.run_instances(
            ami_id,
            2,
            1,
            "InstanceType"  => instance_type,
            "SecurityGroup" => sg
          )
        end

        def get_server_instance(instance_id)
          compute_client.servers.get(instance_id)
        end

        def get_all_instances()
          compute_client.servers.all
        end
      end
    end
  end
end
