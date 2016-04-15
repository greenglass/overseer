require 'aws-sdk'
require 'overseer/aws/wrappers'
require 'overseer/aws/wrappers/ec2'

module Overseer
  module AWS
    module Wrappers
      module Ec2
        module Snapshots
          # wrapper for amazon ec2 snapshots
          class SnapshotClient
            def initialize
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
          end
        end
      end
    end
  end
end
