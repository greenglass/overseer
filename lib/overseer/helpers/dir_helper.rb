# TODO: remove all other references to directories in the project
# currently and put them in here which should simplify things
# and leave less unique path strings hanging around

module Overseer
  module Helpers
    # Intended to help people navigate the project without
    # hardcoding relative paths from every file
    module DirHelper
      def self.root
        File.expand_path(File.join(__dir__, '..', '..', '..'))
      end

      def self.chef_repo
        File.join(root, 'sc-chef-repo')
      end

      def self.packer_scripts
        File.join(root, 'packer_scripts')
      end

      def self.packer_windows_scripts
        File.join(packer_scripts, 'windows')
      end

      def self.template_dir
        File.join(root, 'cfn_templates')
      end

      def self.lambda_dir
        File.join(template_dir, 'lambda_functions')
      end

      def self.erb_dir
        File.join(chef_repo, 'templates')
      end

      def self.spec
        File.join(root, 'spec')
      end

      def self.lib
        File.join(root, 'lib')
      end

      # not source controlled
      def self.tmp
        FileUtils.mkdir_p(File.join(root, 'tmp')).last
      end

      # not source controlled
      def self.builds
        FileUtils.mkdir_p(File.join(tmp, 'builds')).last
      end
    end
  end
end
