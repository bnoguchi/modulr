require 'rkelly'

module Modulr
  class Collector
    attr_reader :modules, :aliases, :main
    
    def initialize(root = nil)
      @root = root
      @modules = {}
      @aliases = {}
    end
    
    def parse_file(path)
      @src = File.read(path)
      @root ||= File.dirname(path)
      @main = JSModule.new(File.basename(path, '.js'), @root, path)
      modules[main.id] = main
      find_dependencies(@src, path)
    end
    
    def parser
      @parser ||= RKelly::Parser.new
    end
    
    def parse(src)
      parser.parse(src)
    end
    
    def find_dependencies(src, path)
      parse(src).each do |exp|
        if is_a_require_expression?(exp) || is_a_modulr_require_expression?(exp)
          js_module = JSModule.from_expression(exp, @root, path)
          if cached_module = modules[js_module.id]
            if cached_module.identifier != js_module.identifier
              aliases[js_module.identifier] = js_module.id
            end
          else
            modules[js_module.id] = js_module
            find_dependencies(js_module.src, js_module.path)
          end
        end
      end
    end
    
    def is_a_require_expression?(node)
      node.is_a?(RKelly::Nodes::FunctionCallNode) &&
      node.value.is_a?(RKelly::Nodes::ResolveNode) &&
      node.value.value == 'require'
    end

    def is_a_modulr_require_expression?(node)
      node.is_a?(RKelly::Nodes::FunctionCallNode) &&
      node.value.is_a?(RKelly::Nodes::DotAccessorNode) &&
      node.value.accessor == 'require' &&
      node.value.value.is_a?(RKelly::Nodes::ResolveNode) &&
      node.value.value.value == 'modulr'
    end
    
    def to_js(buffer = '')
      buffer << File.read(PATH_TO_MODULR_JS);
      modules.each { |id, js_module| js_module.to_js(buffer) }
      aliases.each do |identifier, id|
        buffer << "modulr.alias('#{identifier}', '#{id}');\n"
      end
      buffer << "\nmodulr.require('#{main.identifier}');\n"
    end
  end
end