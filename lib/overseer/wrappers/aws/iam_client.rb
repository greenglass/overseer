require 'stealth_marketplace/helpers/dir_helper'
require 'stealth_marketplace/stealth_marketplace_error'
require 'aws-sdk'

module StealthMarketplace
  module AwsWrappers
    # wrapper for aim client in amazon.
    class IamClient
      include Helpers

      # read the local credentials
      def initialize
        @iam_client = Aws::IAM::Client.new(region: AWS_REGION)
      end

      def all_instance_profiles
        profiles = []
        marker = nil
        loop do
          options = marker ? { marker: marker } : {}
          resp = @iam_client.list_instance_profiles(options)
          marker = resp.marker
          profiles += resp.instance_profiles
          break unless resp.is_truncated
        end
        profiles
      end

      def all_roles
        roles = []
        marker = nil
        loop do
          options = marker ? { marker: marker } : {}
          resp = @iam_client.list_roles(options)
          marker = resp.marker
          roles += resp.roles
          break unless resp.is_truncated
        end
        roles
      end

      def delete_instance_profiles(instance_profiles_to_delete)
        instance_profiles_to_delete.each do |profile|
          @iam_client.delete_instance_profile(
            instance_profile_name: profile.instance_profile_name)
        end
      end

      def delete_roles(roles_to_delete)
        roles_to_delete.each do |role|
          @iam_client.delete_role(
            role_name: role.role_name)
        end
      end

      def print_instance_profiles(instance_profiles)
        puts format(BASE_RESOURCE_FORMAT, 'Instance Profile Name', 'Age', 'Roles')

        instance_profiles.each do |profile|
          puts format(
            BASE_RESOURCE_FORMAT,
            profile.instance_profile_name,
            AwsWrappers.age_string_from_time(profile.create_date),
            profile.roles.map(&:role_name)
          )
        end
      end

      def print_roles(roles)
        puts format(BASE_RESOURCE_FORMAT, 'Role Name', 'Age', '')

        roles.each do |role|
          puts format(
            BASE_RESOURCE_FORMAT,
            role.role_name,
            AwsWrappers.age_string_from_time(role.create_date),
            ''
          )
        end
      end
    end
  end
end
