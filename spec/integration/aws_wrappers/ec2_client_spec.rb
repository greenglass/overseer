require_relative 'spec_helper'
require 'stealth_marketplace/aws_wrappers/ec2_client'

describe StealthMarketplace::AwsWrappers::Ec2Client do
  let(:bad_snapshot_id) { 'snap-12345678' }
  let(:completed_snapshot_id) { 'snap-44a59e3e' }
  let(:well_known_security_group) { 'StealthSecurityGroup-Dev-DO-NOT-DELETE' }
  let(:well_known_vpc_name) { 'DEV VPC' }
  let(:well_known_subnet_name) { 'DEV-SUBNET-DONOTDELETE' }

  it 'get ami snapshot0' do
    ami_id = 'ami-cb7135ae'
    snap_id = subject.get_ami_snapshot0(ami_id)

    expect(snap_id).to eq('snap-44a59e3e')
  end

  describe '#get_snapshot_state' do
    it 'finds a completed snapshot' do
      expect(
        subject.get_snapshot_state(completed_snapshot_id)
      ).to eq('completed')
    end

    it 'returns nil for a bad snapshot' do
      expect(
        subject.get_snapshot_state(bad_snapshot_id)
      ).to be_nil
    end

    it 'returns nil for a nil snapshot' do
      expect(
        subject.get_snapshot_state(nil)
      ).to be_nil
    end
  end
  it 'wait snapshot completed' do
    expect(
      subject.wait_snapshot_state(completed_snapshot_id)
    ).to eq('completed')
  end

  it 'wait snapshot completed fail' do
    expect(
      subject.wait_snapshot_state(bad_snapshot_id)
    ).to be_nil
  end

  it 'get instance info' do
    inst_id = 'i-eb3acd3f'
    resp = subject.get_istance_info(inst_id)

    expect(resp).not_to eq(nil)
  end

  it 'get instance info fail' do
    inst_id = 'i-12345678'
    resp = subject.get_istance_info(inst_id)

    expect(resp).to eq(nil)
  end

  it 'delete snapshot in use' do
    snap_id = 'snap-44a59e3e'
    deleted = subject.delete_snapshot(snap_id)

    # This is a snapshot associated with an AMI/in use,
    # expects false to be returned
    expect(deleted).to eq(false)
  end

  it 'delete snapshot not exist' do
    expect(
      subject.delete_snapshot(bad_snapshot_id)
    ).to eq(false)
  end

  describe '#find_security_group' do
    it 'finds well known security group' do
      vpc_id = subject.find_vpc_id(well_known_vpc_name)
      sg_group_id = subject.find_security_group_id(vpc_id, well_known_security_group)

      expect(sg_group_id).to match(/sg-\S+/)
    end
  end

  describe '#find_vpc_id' do
    it 'finds well known vpc' do
      vpc_id = subject.find_vpc_id(well_known_vpc_name)

      expect(vpc_id).to match(/vpc-\S+/)
    end
  end

  describe '#find_subnet_id' do
    it 'finds well known subnet' do
      vpc_id = subject.find_vpc_id(well_known_vpc_name)
      subnet_id = subject.find_subnet_id(vpc_id, well_known_subnet_name)

      expect(subnet_id).to match(/subnet-\S+/)
    end
  end
end
