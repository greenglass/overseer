require_relative 'spec_helper'
require 'stealth_marketplace/aws_wrappers/s3_client'

describe StealthMarketplace::AwsWrappers::S3Client do
  let(:bucket_name) { ResourceName.rspec_name }
  let(:cookbook_path) { StealthMarketplace::Helpers::DirHelper.cookbooks }
  let(:local_cookbook_path) do
    File.join(
      StealthMarketplace::Helpers::DirHelper.tmp,
      ResourceName.rspec_name
    )
  end

  # it 'copies a folder to s3 bucket, then gets the folder back' do
  #   pending 'Find a more reliable verification method'
  #   subject.create_bucket(bucket_name)
  #   subject.copy_to_bucket(cookbook_path, bucket_name)
  #   subject.copy_from_bucket(local_cookbook_path, bucket_name)
  #   subject.delete_bucket(bucket_name)

  #   expect(
  #     system "diff -q -r -x .svn #{local_cookbook_path} #{cookbook_path}"
  #   ).to be true
  # end
end
