module Overseer
  module AWS
    module Cullers
      # Class manages resource culling logic
      class CullExecutor
        attr_accessor :herder
        def initialize
          SUPPORTED_RESOURCES.each do |resource|
            instance_variable_set("@#{resource}_delete_rules", [])
            instance_variable_set("@#{resource}_protect_rules", [])
          end
        end

        SUPPORTED_RESOURCES = [
          :stackless_ec2
        ].freeze

        SUPPORTED_RESOURCES.each do |resource|
          define_method("#{resource}_delete_rule") do |&rule_block|
          instance_variable_get("@#{__callee__}s") << rule_block
          end

          define_method("#{resource}_protect_rule") do |&rule_block|
          instance_variable_get("@#{__callee__}s") << rule_block
          end
        end

        def cull(type, options = {})
          @herder = gather_the_herd(type) if SUPPORTED_RESOURCES.include? type

          resources = herder.find_resources

          resources_to_delete = filter_resources(type, resources)

          herder.print_resources(resources_to_delete)
          puts "\nResources to Delete/Total: #{resources_to_delete.size}/#{resources.size}"

          return if options[:dry_run] || resources_to_delete.empty?

          should_delete = !options[:confirm] || ask_delete(type)

          herder.delete_resources(resources_to_delete) if should_delete
        end

        def gather_the_herd(type)
          herder_hash = {
            stackless_ec2: StacklessEc2Herder.new
          }

          return herder_hash[type] if SUPPORTED_RESOURCES.include? type
          fail "#{type} is not being gathered to an object."
        end

        def parse_config(config_text = nil)
          config_text = IO.read(File.join(Dir.pwd, 'Cullfile')) if config_text.nil?

          begin
            instance_eval config_text
          rescue StandardError => e
            raise 'Failed to parse your culling config', e
          end
        end

        def filter_resources(type, resources)
          resources_to_delete = resources.select do |resource|
            instance_variable_get("@#{type}_delete_rules").any? do |rule|
              rule.call resource
            end
          end

          resources_to_delete.reject do |resource|
            instance_variable_get("@#{type}_protect_rules").any? do |rule|
              rule.call resource
            end
          end
        end

        def ask_delete(type)
          ask("Delete #{type}(s)?(yes/no):") == 'yes'
        end
      end
    end
  end
end
