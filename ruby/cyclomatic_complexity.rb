# Generates test cases required to satisfy so-called "02" linearly independent path testing
class CyclomaticComplexity
    def initialize(root)
        @root=root
    end
    def cyclomatic_visit(graph_node)
        @stack.push(graph_node)
        if graph_node.children.length==0 && @condition_changed
            # dump stack
            @condition_changed=false
            puts "Test #{@testcase}: #{@stack.select{|e| e.class!=EndNode}.join("\n ")}"
            @testcase=@testcase+1
        elsif graph_node.class
            graph_node.children.reverse.each do |child|
                # visit child
                cyclomatic_visit(child)
                # negate condition and visit again, if not already done
                if not @negated[child.id] and child.negatable
                    @negated[child.id]=true
                    @condition_changed=true
                    child.negate
                    cyclomatic_visit(child)
                end
            end
        end
        @stack.pop
    end

    def dump_tests
        # DFS traversal of graph
        @stack=[]
        @condition_changed=true
        # track negation of conditions
        @negated=Hash.new
        @testcase=1
        cyclomatic_visit(@root)
    end
end
