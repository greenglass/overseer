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
    end
  end
end
