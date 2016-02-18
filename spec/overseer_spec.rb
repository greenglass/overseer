require 'spec_helper'

describe Overseer do
  before do
    Fog.mock!
    Fog::Mock.delay = 0
  end

  it 'run overseer' do
    client = Fog::Compute.new({
      :aws_access_key_id => "asdf",
      :aws_secret_access_key => "asdf",
      :provider => "AWS"
    })

    overseer = Overseer::Overseer.new(client) 

  end

  it 'has a version number' do
    expect(Overseer::VERSION).not_to be nil
  end
end
