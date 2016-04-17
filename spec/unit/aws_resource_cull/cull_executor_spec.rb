require_relative 'spec_helper'
require 'overseer/aws/cullers/cull_executor'
require 'overseer/aws/cullers/stackless_ec2_herder'

module Overseer
  module AWS
    module Cullers
      describe CullExecutor do
        let(:invald_resource) { :invalid_resource }

        subject do
          executor = CullExecutor.new
          executor.parse_config(METACODE)
          executor
        end

        it 'test valid resource types' do
          CullExecutor::SUPPORTED_RESOURCES.each do |resource|
            expect { subject.gather_the_herd(resource) }.not_to raise_error
          end
        end

        it 'test invalid resource type' do
          expect { subject.gather_the_herd(:invalid_resource) }.to raise_error(RuntimeError)
        end

        context 'metadata programming rules' do
          it 'resource delete rules' do
            CullExecutor::SUPPORTED_RESOURCES.each do |resource|
              expect(subject).to respond_to "#{resource}_delete_rule"
            end
          end

          it 'resource protect rules' do
            CullExecutor::SUPPORTED_RESOURCES.each do |resource|
              expect(subject).to respond_to "#{resource}_protect_rule"
            end
          end

        end
      end
    end
  end
end
