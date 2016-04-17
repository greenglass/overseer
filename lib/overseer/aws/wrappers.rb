require 'active_support/all'

module Overseer
  module AWS
    # encapsulate helper logic based around the aws clients
    module Wrappers
      AWS_REGION = ENV['AWS_REGION'] || 'us-west-2'

      ALL_REGIONS = %w(
        us-east-1
        us-west-1
        us-west-2
        eu-west-1
        eu-central-1
        ap-northeast-1
        ap-northeast-2
        ap-southeast-1
        ap-southeast-2
        sa-east-1
      ).freeze

      BASE_RESOURCE_FORMAT = '%-35.35s     %-25s     %-10s'.freeze

      def self.age_string_from_time(time_in)
        age = (Time.now - time_in).round

        age_days = age / 1.days
        age_hours = (age - 1.days * age_days) / 1.hours
        age_minutes = (age - 1.days * age_days - 1.hours * age_hours) / 1.minutes

        format('%-3sdays, %2shours, %2smins', age_days, age_hours, age_minutes)
      end
    end
  end
end
