require 'aws-sdk'
require 'overseer/aws/wrappers'
require 'overseer/aws/wrappers/ec2'

module Overseer
  module AWS
    module Wrappers
      module Ec2
        module Images
          # wrapper for amazon ec2 client interaction with amis
          class AmiClient
            def initialize
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

            def find_image_id(image_name)
              resp = @ec2_client.describe_images(create_name_filter(image_name))

              if resp.images.empty?
                resp.images.first.image_id
              else
                raise(OverseerError,
                      "Unable to find ami_id for: #{image_name}")
              end
            end

            def create_name_filter(image_name)
              { filters: [name: 'name', values: [image_name]] }
            end
          end
        end
      end
    end
  end
end
