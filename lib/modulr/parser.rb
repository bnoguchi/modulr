require 'rkelly'
require 'modulr/error'

module Modulr
  class Parser

    def initialize
      @parser = RKelly::Parser.new
    end
    
    def parse(src)
      raise ParserError unless ast = @parser.parse(src)
      ast
    rescue RKelly::SyntaxError => e
      raise ParserError
    end
    
    def get_require_expressions(src)
      @nodes = parse(src)
      nodes = @nodes.select { |node| is_a_require_expression?(node) }
      nodes.map { |node| normalize(node) }
    end
    
    private 
      
      def is_a_require_expression?(node)
        (node.is_a?(RKelly::Nodes::FunctionCallNode) ||
        node.is_a?(RKelly::Nodes::NewExprNode)) &&
        node.value.is_a?(RKelly::Nodes::ResolveNode) &&
        node.value.value == 'require'
      end
      
      def normalize(node)
        arg = node.arguments.value.first
        valid = arg.is_a?(RKelly::Nodes::StringNode)

        # Handle e.g., require(from) where var from = "etc"
        # i.e., dynamic requires
        if !valid
          a = @nodes.detect { |node| (node.is_a? RKelly::Nodes::VarDeclNode) && node.name === arg.value}
          a = a.value.value.value if a
        end
        {
          :identifier => a || (valid ? arg.value[1...-1] : nil),
          :src_code => arg.to_ecma,
          :line => arg.line.to_i
        }
      end
  end
  
  class ParserError < ModulrError
  end
end
