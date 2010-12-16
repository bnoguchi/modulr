require 'modulr/error'
module Modulr
  class JSModule
    include Comparable
    
    JS_ESCAPE_MAP = {
      '\\'    => '\\\\',
      '</'    => '<\/',
      "\r\n"  => '\n',
      "\n"    => '\n',
      "\r"    => '\n',
      '"'     => '\\"',
      "'"     => "\\'"
    }

    def self.paths=(paths)
      @paths = paths
    end
    
    def self.parser
      @dependency_finder ||= Parser.new
    end
    
    def self.find_dependencies(js_module)
      begin
        expressions = parser.get_require_expressions(js_module.src)
      rescue ParserError
        raise JavaScriptSyntaxError, js_module
      end
      expressions.map do |exp|
        if exp[:identifier]
          opts = {}
          if exp[:identifier] =~ /^./
            next_identifier = File.basename(exp[:identifier])
            opts[js_module._type] = js_module.root
            opts[:relative] = File.join(js_module.relative, File.dirname(exp[:identifier]))
          else
            raise "You must specify a PATH" unless @paths
            path = nil
            @paths.split(':').each do |p|
              poss1 = File.join(p, exp[:identifier] + '.js')
              poss2 = File.join(p, exp[:identifier], 'index.js')
              if File.exist?(poss1)
                path = File.dirname(exp[:identifier])
                next_identifier = File.basename(exp[:identifier])
              elsif File.exist?(poss2)
                path = exp[:identifier]
                next_identifier = 'index'
              end
            end
            raise LoadModuleError.new(self) unless path
            opts[:path] = path
            opts[:relative] = '.'
          end
          opts[:line] = exp[:line] 
          new(next_identifier, opts)
        else
          raise DynamicModuleIdentifierError.new(exp[:src_code], js_module.path, exp[:line])
        end
      end
    end
    
    attr_reader :identifier, :root, :relative, :terms, :file, :line, :_type
    
    def initialize(identifier, opts = {})
      @identifier = identifier
      @_type = if opts[:root]
                :root
              elsif opts[:path]
                :path
              else
                raise "Must provide :root or :path"
              end
      @root = opts[:root] || opts[:path]
      @relative = opts[:relative]
      @line = opts[:line]

      @terms = identifier.split('/').reject { |term| term == '' }
      @file = File.join(@root, @relative, @identifier + '.js')
      raise ModuleIdentifierError.new(self) unless identifier_valid?
    end

    def <=> (other_module)
      id <=> other_module.id
    end

    def inspect
      "#<#{self.class.name} \"#{identifier}\">"
    end

    def identifier_valid?
      @valid ||= terms.all? { |t| t =~ /^([a-zA-Z\-\d]+|\.\.?)$/ }
    end
   
    def id
      return @id if @id
      
      parts = case @_type
              when :root
                ['.']
              when :path
                ['PATH']
              end
      parts << @relative.split('/') << @identifier
      parts.flatten!
      path = []
      parts.each do |part|
        case part
        when '.'
          path << part if path.size == 0 && parts[0] == '.'
        when '..'
          if path.last == '..' || path.last == '.' || parts[0] == 'PATH' && path.size == 2    
            path << part
          else
            path.pop
          end
        else
          path << part
        end
      end
      @id = path * '/'
    end

    # TODO Remove directory and "def directory"
    def path
      @path ||= File.expand_path(partial_path, directory) + '.js'
    end
    
    def src
      return @src if @src
      path = File.expand_path(File.join(@root, @relative, @identifier + '.js'))
      if File.exist?(path)
        @src = File.read(path)
      else
        raise LoadModuleError.new(self)
      end
      @src.gsub!(/^#!.*/, '') # Remove shebangs to avoid JS error
      return @src
    end
    
    def escaped_src
      @escaped_src ||= src.gsub(/(\\|<\/|\r\n|[\n\r"'])/) {
        JS_ESCAPE_MAP[$1]
      }
    end
    
    def factory
      "function(require, exports, module) {\n#{src}\n}"
    end
    
    def dependencies
      @dependencies ||= self.class.find_dependencies(self)
    end
    
    def dependency_array
      '[' << dependencies.map { |d| "'#{d.id}'" }.join(', ') << ']'
    end
    
    def ensure(buffer = '')
      fn = "function() {\n#{src}\n}"
      buffer << "\nrequire.ensure(#{fn});\n"
#      buffer << "\nrequire.ensure(#{dependency_array}, #{fn});\n"
    end

    protected
      def partial_path
        File.join(*terms)
      end
      
      def directory
        relative? ? File.dirname(file) : root
      end
  end
  
  class ModuleIdentifierError < ModulrError
    attr_reader :js_module
    def initialize(js_module)
      @js_module = js_module
      super("Invalid module identifier '#{js_module.identifier}' in #{js_module.file} at line #{js_module.line}.")
    end
  end

  class LoadModuleError < ModulrError
    attr_reader :js_module
    def initialize(js_module)
      @js_module = js_module
      super("Cannot load module '#{js_module.identifier}' in #{js_module.file} at line #{js_module.line}.\nMissing file #{js_module.path}.")
    end
  end
  
  class DynamicModuleIdentifierError < ModulrError
    attr_reader :src, :file, :line
    def initialize(src, file, line)
      @src = src
      @file = file
      @line = line
      super("Cannot do a static analysis of dynamic module identifier '#{src}' in #{file} at line #{line}.")
    end
  end
  
  class JavaScriptSyntaxError < ModulrError
    attr_reader :js_module
    def initialize(js_module)
      @js_module = js_module
      super("JavaScript Syntax Error in #{js_module.file}.")
    end
  end
end
