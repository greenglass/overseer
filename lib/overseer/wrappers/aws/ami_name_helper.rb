module StealthMarketplace
  module AwsWrappers
    # mixin with some helpers for dealing with ami names
    module AmiNameHelper
      def build_ami_name(machine_type, version)
        "#{machine_type}-#{version}"
      end

      def ami_name_regex(machine_type)
        /#{machine_type}-#{modded_version_regex}/i
      end

      def modded_version_regex
        StealthMarketplace.build_version_regex.to_s.gsub(/[$\^]/, '')
      end

      def compare_ami_versions(name1, name2)
        name1_version = name1.match(modded_version_regex).to_s
        name2_version = name2.match(modded_version_regex).to_s

        Gem::Version.new(name1_version) <=> Gem::Version.new(name2_version)
      end
    end
  end
end
