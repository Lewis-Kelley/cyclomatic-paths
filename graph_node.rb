class GraphNode
    @@uid=0
    attr_reader :id
    attr_reader :ast_node
    attr_accessor :next_node
    attr_accessor :parent
    attr_accessor :source
    attr_reader :negatable
    attr_reader :dummy
    def self.uid
        @@uid
    end
    @@nodes=Hash.new
    @@nodes_by_keyword=Hash.new
    @@nodes_by_expression=Hash.new
    def self.nodes
        @@nodes
    end
    def self.nodes=(new_nodes)
        @@nodes=new_nodes
    end
    def self.nodes_by_keyword
        @@nodes_by_keyword
    end
    def self.nodes_by_expression
        @@nodes_by_expression
    end
    def initialize(node,dummy=false)
        @dummy=dummy
        @ast_node=node
        @next_node=nil
        @id=@@uid
        @@uid=@@uid+1
        @@nodes[@id]=self
        if node.respond_to?(:loc)
            @@nodes_by_keyword[node.loc.to_hash[:keyword]]||=self
            @@nodes_by_expression[node.loc.to_hash[:expression]]||=self
            #puts @@nodes_by_keyword[node.loc.to_hash[:keyword]]
        end
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
        unless @next_node.nil?
            [@next_node].each do |e|
               begin
               node = @@nodes[e.id]
               defs.concat(node.to_def())
               rescue NoMethodError => e
                raise "Error browsing children of #{self.source}: #{e}"
               end
            end
        end
        defs.uniq()
    end

    def to_graph()
        edges=[]
        unless @next_node.nil?
            [@next_node].each do |e|
                node = @@nodes[e.id]
                edges << "n#{@id} -> n#{e.id}  [style=\"dashed\"]"
                edges.concat(node.to_graph())
            end
        end
        edges.uniq()
    end

    def to_dot()
        # define nodes
        self.to_def.sort.uniq.concat(self.to_graph.sort.uniq).join(";\n")
    end
end

class IfNode < GraphNode

    attr_accessor :false_node
    attr_accessor :true_node

    def initialize(node,dummy=false)
        super
        @child = ast_node.children[0]
        if @child.class!=Symbol
            @child=ast_node.children[0].loc.expression.source
        end
        @source="#{@ast_node.loc.expression.line}\: if #{@child}"
        @negatable=true
    end
    def to_graph()
        edges=super
        unless @false_node.nil? or @true_node.nil?
            edges << "n#{@id} -> n#{@true_node.id}"
            edges << "n#{@id} -> n#{@false_node.id}"
            edges.concat(@false_node.to_graph)
            edges.concat(@true_node.to_graph)
        end
        edges.uniq
    end
    def to_def()
        defs=super
        unless @false_node.nil? or @true_node.nil?
            defs.concat(@false_node.to_def)
            defs.concat(@true_node.to_def)
        end
        defs.uniq
    end
end

class TrueNode < IfNode
    def initialize(node,dummy=false)
        super
        @source="#{@ast_node.loc.expression.line}\: #{@child}==true"
    end
end

class FalseNode < IfNode
    def initialize(node,dummy=false)
        super
        @source="#{@ast_node.loc.expression.line}\: #{@child}==false"
    end
end

# class BinaryCondition < GraphNode

#     attr_accessor :possiblities
#     def initialize(node)
#         super
#     end

# class AndCondition < GraphNode
#     def initialize(node)
#         a=node.children[0].loc.expression.source
#         b=node.children[1].loc.expression.source
#         @possibilities=[{a:"#{a}",b:"#{b}"},
#             {a:"#{a}",b:"not #{b}"},
#             {a:"not #{a}",b:"#{b}"}
#         ]
#     end
# end

# class OrCondition < GraphNode
#     def initialize(node)
#         a=node.children[0].loc.expression.source
#         b=node.children[1].loc.expression.source
#         @possibilities=[{a:"not #{a}","not #{b}"},
#             {a:"#{a}",b:"not #{b}"},
#             {a:"not #{a}",b:"#{b}"}
#         ]
#     end
# end

class DefNode < GraphNode

    def initialize(node)
        super
        @source="#{@ast_node.children[0]}"
    end

end

# static def: "self." ...
class DefsNode < GraphNode
    # static stuff
    def initialize(node)
        super
        #@source="self.#{@ast_node.children[1]}"
        # rubocop output does not clearly indicate whether the function comes from self.
        @source="#{@ast_node.children[1]}"
    end

end

class EndNode < GraphNode
    def initialize(ast_node)
        super(ast_node)
        @source="#{@ast_node.line}\: end"
    end

end

class ReturnNode < GraphNode
    def initialize(node)
        super(node)
        @source="#{@ast_node.loc.line}\: #{@ast_node.loc.expression.source}"
    end
end
 
