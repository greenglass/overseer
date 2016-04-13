require_relative 'spec_helper'
require 'stealth_marketplace/aws_wrappers/published_ami_finder'

module StealthMarketplace
  module AwsWrappers
    describe PublishedAMIFinder do
      describe '#last_published_ami' do
        MachineTypes.valid_machine_types.each do |type|
          it "finds an AMI for type: #{type}" do
            expect(subject.last_published_ami(type).name).to match subject.ami_name_regex(type)
          end
        end
      end
    end
  end
end
