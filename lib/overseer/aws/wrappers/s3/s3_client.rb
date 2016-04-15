require 'overseer/helpers/dir_helper'
require 'overseer/overseer_error'
require 'aws-sdk'

module Overseer
  module AWS
    module Wrappers
      # wrapper for s3 client in amazon. Treats a bucket as a distinct folder.
      class S3Client
        include Helpers

        # read the local credentials
        def initialize
          @s3_client = Aws::S3::Client.new(region: AWS_REGION)
          @s3_resource = Aws::S3::Resource.new(
            @s3_client,
            region: @s3_client.config.region
          )
        end

        def bucket_object_exists?(object_name, bucket_name)
          bucket = @s3_resource.bucket(bucket_name)
          bucket.object(object_name).exists?
        end

        def delete_bucket(name, options = {})
          @s3_resource.bucket(name).delete!
          @s3_resource.bucket(name).wait_until_not_exists unless options[:async]
        end

        def delete_buckets(buckets, options = {})
          buckets.each do |bucket|
            puts "  #{bucket.name}"
            begin
              delete_bucket(bucket.name, options)
            rescue Aws::S3::Errors::NoSuchBucket
              puts "    bucket doesn't exist, but it was originally listed?"
            end
          end
        end

        def cleanup_matching(bucket_regex)
          puts 'Deleting buckets:'
          resp = @s3_client.list_buckets

          buckets_tc = resp.buckets.select do |bucket|
            bucket.name =~ bucket_regex
          end

          delete_buckets(buckets_tc)
        end

        def delete_files(bucket_name, prefix)
          bucket = @s3_resource.bucket(bucket_name)
          bucket.objects(prefix: prefix).batch_delete!
        end

        def all_buckets
          @s3_client.list_buckets.buckets
        end

        def print_s3s(s3_instances)
          puts format(BASE_RESOURCE_FORMAT, 'S3 Name', 'Age', '')

          s3_instances.each do |s3|
            puts format(
              BASE_RESOURCE_FORMAT,
              s3.name,
              Wrappers.age_string_from_time(s3.creation_date),
              ''
            )
          end
        end
      end
    end
  end
end
