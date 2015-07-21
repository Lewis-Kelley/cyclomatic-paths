
require_relative("cyclomatic_complexity.rb")
# plan:
# dump CFG statically, do NOT instrument here
# dot format
# node labels are the conditions
# write separate tool to parse CFG from standard format

class GraphNode
    @@uid=0
    attr_reader :id
    attr_reader :ast_node
    attr_reader :children
    attr_accessor :parent
    attr_accessor :source
    attr_reader :negatable
    def self.uid
        @@uid
    end
    @@nodes=Hash.new
    def self.nodes
        @@nodes
    end
    def initialize(node)
        @ast_node=node
        @children=[]
        @id=@@uid
        @@uid=@@uid+1
        @@nodes[@id]=self
        @parent=nil
        @source=nil
        @negatable=false
    end

    def inspect
        @source
    end

    def to_s
        @source
    end

    def to_def()
        defs=["n#{@id}[label=\"#{source}\"]"]
        @children.each do |e|
           begin
           node = @@nodes[e.id]
           defs.concat(node.to_def())
           rescue NoMethodError => e
            raise "Error browsing children of #{self.source}"
           end
        end
        defs.uniq()
    end

    def to_graph()
        edges=[]
        @children.each do |e|
           node = @@nodes[e.id]
           edges << "n#{@id} -> n#{e.id}"
           edges.concat(node.to_graph())
        end
        edges.uniq()
    end

    def to_dot()
        # define nodes
        self.to_def.concat(self.to_graph).join(";\n")
    end
end

class IfNode < GraphNode

    def initialize(node)
        super
        @source="#{@ast_node.loc.expression.line}\: #{@ast_node.children[0].loc.expression.source}"
        @negatable=true
    end

    def negate()
        @source="#{@ast_node.loc.expression.line}\: not #{@ast_node.children[0].loc.expression.source}"
    end
end

class DefNode < GraphNode

    def initialize(node)
        super
        @source="<entrypoint:#{@ast_node.children[0]}>"
    end

end

class EndNode < GraphNode
    def initialize(ast_node)
        super(ast_node)
        @source="#{@ast_node.line}\: end"
    end
end

class CyclomaticTests < Parser::Rewriter
    def dump_cfg()
        puts "digraph #{@root.ast_node.children[0]}{"
        puts @root.to_dot
        puts "}"
    end

    def on_def(node)
        # new graph
        #puts "NEW GRAPH"
        hash= node.loc.to_hash
        @root=DefNode.new(node)
        @parents = [@root]
        # @ends[0] is always the exit point
        @ends=[EndNode.new(hash[:end])]
        super
        # link exit point
        @parents[-1].children.push(@ends[0])
        dump_cfg
        CyclomaticComplexity.new(@root).dump_tests        
    end

    def on_return(node)
        # prematurely exit

        # remove link to end
        @parents[-1].children.pop

        # add link to VERY end
        @parents[-1].children.push(@ends[0])
    end

    def on_if(node)
        # each of this node's child ifs get graph links


        #puts "IF STATEMENT"
        #puts node.loc.to_hash

        hash=node.loc.to_hash
        if hash[:end]
            # this if is the start of a series of if-elsif
            # link all future ifs in the chain to this one
            end_node=EndNode.new(hash[:end])
            @ends.push(end_node)
            # false case
            @parents[-1].children.push(end_node)
        end

        graph_node=IfNode.new(node)

        # regular control flow from parent to if
        @parents[-1].children.push(graph_node)

        # true case: execute code and go to end
        graph_node.children.push(@ends[-1])
        
        # recursively descend
        @parents.push(graph_node)
        super(node)
        @parents.pop
        if hash[:end]
            # control flow will start from the "end" token from here on in
            @parents.push(@ends.pop)

        end
    end

end
