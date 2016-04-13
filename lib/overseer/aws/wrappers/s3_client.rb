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

        def create_bucket(name)
          @s3_client.create_bucket(
            bucket: name,
            acl: 'public-read-write'
          )
        end

        def copy_to_bucket(path_in, bucket_name)
          unless File.exist? path_in
            fail OverseerError, "#{path_in} does not exist"
          end

          if File.file? path_in
            bucket_path = File.basename path_in
          else
            bucket_path = ''
          end
          bucket_copy_recursive(path_in, bucket_path, bucket_name)
        end

        def bucket_object_exists?(object_name, bucket_name)
          bucket = @s3_resource.bucket(bucket_name)
          bucket.object(object_name).exists?
        end

        def bucket_copy_recursive(path_in, bucket_path, bucket_name)
          if File.file? path_in
            bucket_object = @s3_resource.bucket(bucket_name).object(bucket_path)
            bucket_object.upload_file(path_in, acl: 'public-read')
          elsif Dir.exist? path_in
            Dir.entries(path_in).each do |child|
              next if ['.', '..', '.svn'].include? child
              path_child = File.join(path_in, child)

              bucket_path_child = if bucket_path.empty?
                                    File.basename(path_child)
                                  else
                                    "#{bucket_path}/#{File.basename(path_child)}"
                                  end

              bucket_copy_recursive(
                path_child,
                bucket_path_child,
                bucket_name
              )
            end
          else
            fail OverseerError, "#{path_in} does not exist"
          end
        end

        def copy_from_bucket(path_in, bucket_name)
          @s3_resource.bucket(bucket_name).objects.each do |object|
            file_dest = Pathname.new "#{path_in}/#{object.key}"

            FileUtils.mkdir_p file_dest.parent unless Dir.exist? file_dest.parent

            object.get(response_target: file_dest)
          end
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

        def list_files(bucket_name, prefix)
          bucket = @s3_resource.bucket(bucket_name)
          bucket.objects(prefix: prefix).collect(&:key)
        end

        def delete_files(bucket_name, prefix)
          bucket = @s3_resource.bucket(bucket_name)
          bucket.objects(prefix: prefix).batch_delete!
        end

        def file_public_url(object_key, bucket_name)
          @s3_resource.bucket(bucket_name).object(object_key).public_url
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
              AwsWrappers.age_string_from_time(s3.creation_date),
              ''
            )
          end
        end
      end
    end
  end
end
