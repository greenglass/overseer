require 'aws-sdk'
require 'stealth_marketplace/aws_wrappers'

module StealthMarketplace
  module AwsWrappers
    # wrapper for amazon ec2 client
    class Ec2Client
      attr_accessor :ec2_client

      EC2_PRINT_FORMAT = "#{BASE_RESOURCE_FORMAT}    %-13s".freeze
      SUPPORTED_REGIONS = ['us-east-1', 'us-west-2'].freeze

      # read the local credentials to create the client
      def initialize
        @ec2_client = Aws::EC2::Client.new(region: AWS_REGION)
      end

      def region_endpoints
        @ec2_client.describe_regions.regions.map(&:endpoint)
      end

      def deregister_ami(ami_id)
        snap_id = get_ami_snapshot0(ami_id)

        # AMI should be deregistered first before attempt to
        # delete the associated snapshot.
        @ec2_client.deregister_image(image_id: ami_id)

        if wait_snapshot_state(snap_id) == 'completed'
          delete_snapshot(snap_id)
        else
          puts "Unable to delete snapshot #{snap_id}"
        end
      end

      def cleanup_matching(resource_regex)
        cleanup_images_matching(resource_regex)
      end

      def our_images
        @ec2_client.describe_images(owners: ['self']).data.images
      end

      def images_matching(image_regex)
        our_images.select do |image|
          image.name.match(image_regex)
        end
      end

      def get_ami_snapshot0(ami_id)
        resp = @ec2_client.describe_images(image_ids: [ami_id])

        return unless resp.images.first

        mappings = resp.images.first.block_device_mappings.first

        mappings.ebs.snapshot_id if mappings
      end

      def get_snapshot_state(snapshot_id)
        return if snapshot_id.nil?

        resp = @ec2_client.describe_snapshots(snapshot_ids: [snapshot_id])

        resp.snapshots.first.state if resp.snapshots.first
      rescue Aws::EC2::Errors::InvalidSnapshotNotFound
        nil
      end

      def wait_snapshot_state(snapshot_id)
        return unless get_snapshot_state(snapshot_id)

        ec2_snapshot = Aws::EC2::Snapshot.new(
          snapshot_id, client: @ec2_client
        )

        resp = ec2_snapshot.wait_until_completed(
          snapshot_ids: [snapshot_id]
        )

        get_snapshot_state(resp.id)
      end

      def delete_snapshot(snapshot_id)
        @ec2_client.delete_snapshot(snapshot_id: snapshot_id)
        true
      rescue Aws::EC2::Errors::InvalidSnapshotNotFound => e
        LOGGER.warn 'unable to delete snapshot:  ' + e.message
        false
      rescue Aws::EC2::Errors::InvalidSnapshotInUse => e
        LOGGER.warn 'unable to delete snapshot:  ' + e.message
        false
      end

      def get_istance_info(instance_id)
        @ec2_client.describe_instances(instance_ids: [instance_id])
      rescue Aws::EC2::Errors::InvalidInstanceIDNotFound
        LOGGER.warn "get_istance_info: instance #{instance_id} does not exist"
        nil
      end

      def cleanup_images_matching(image_regex)
        images_tc = images_to_cleanup_matching(image_regex)
        puts "Images to deregister:\n" \
          "  #{images_tc.map(&:image_id).join("\n  ")}"

        images_tc.each { |image| deregister_ami(image.image_id) }

        puts 'Done cleaning up images!'
      end

      def images_to_cleanup_matching(image_name_regex)
        images_matching(image_name_regex).select do |image|
          image.state = 'available'
        end
      end

      def create_name_filter(image_name)
        { filters: [name: 'name', values: [image_name]] }
      end

      def find_image_id(image_name)
        resp = @ec2_client.describe_images(create_name_filter(image_name))

        if resp.images.size > 0
          resp.images.first.image_id
        else
          fail(StealthMarketplaceError,
               "Unable to find ami_id for: #{image_name}")
        end
      end

      def find_windows_password(instance_id, key_pair_path)
        instance = Aws::EC2::Resource.new(client: @ec2_client).instance(instance_id)

        instance.decrypt_windows_password(key_pair_path)
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

      def print_ec2s(ec2_instances)
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
          puts make_ec2_string(inst)
        end
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

      def get_instance_name(instance)
        name_tag = instance.tags.find { |tag| tag.key == 'Name' }

        (name_tag && !name_tag.value.strip.empty? && name_tag.value) ||
          ''
      end

      def make_ec2_string(instance)
        format(
          EC2_PRINT_FORMAT,
          get_instance_name(instance),
          AwsWrappers.age_string_from_time(instance.launch_time),
          instance.state.name,
          instance.instance_id
        )
      end

      def instance_private_ip(instance_id)
        find_instance(instance_id).private_ip_address
      end

      def all_security_groups
        @ec2_client.describe_security_groups.security_groups
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

      def find_security_group_id(vpc_id, group_name)
        groups = @ec2_client.describe_security_groups(
          filters: [
            { name: 'vpc-id', values: [vpc_id] },
            { name: 'group-name', values: [group_name] }
          ]
        ).security_groups

        fail(
          StealthMarketplaceError,
          'More than one security group with requested name'
        ) if groups.size > 1

        fail(
          StealthMarketplaceError,
          "Security group doesn't exist: vpc_id=#{vpc_id} group_name=#{group_name}"
        ) if groups.size == 0

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

      def find_vpc_id(vpc_name)
        vpcs = @ec2_client.describe_vpcs.vpcs

        vpc = vpcs.find { |v| v.tags.find { |t| t.key == 'Name' && t.value == vpc_name } }

        fail StealthMarketplaceError, "VPC doesn't exist - VPC name: #{vpc_name}" unless vpc

        vpc.vpc_id
      end

      def find_subnet_id(vpc_id, subnet_name)
        subnets = @ec2_client.describe_subnets(
          filters: [
            { name: 'vpc-id', values: [vpc_id] },
            { name: 'tag:Name', values: [subnet_name] }
          ]
        ).subnets

        fail(
          StealthMarketplaceError,
          'More than one with subnet with requested name'
        ) if subnets.size > 1

        fail(
          StealthMarketplaceError,
          "No subnet found: vpc_id=#{vpc_id} subnet_name=#{subnet_name}"
        ) if subnets.size == 0

        subnets.first.subnet_id
      end

      def copy_ami_to_regions(ami_id, ami_name)
        regions_to_copy = SUPPORTED_REGIONS - [AWS_REGION]

        regions_to_copy.each do |dest_region|
          Aws::EC2::Client.new(region: dest_region).copy_image(
            source_region: AWS_REGION,
            source_image_id: ami_id,
            name: ami_name
          )
        end
      end

      def change_launch_permissions(ami_id)
        @ec2_client.modify_image_attribute(
          image_id: ami_id
        )
      end
    end
  end
end
