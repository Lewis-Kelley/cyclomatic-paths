# Generates test cases required to satisfy so-called "02" linearly independent path testing
class CyclomaticComplexity
    # mode can be two things: "path" or "count"
    def initialize(root, _end, mode="path")
        @root=root
        @end=_end
        @mode=mode
        @paths=[]
    end
    def to_s
        @root.to_s
    end
    def dump_stack
        @condition_changed=false
        @paths << @stack.dup
        @testcase=@testcase+1
    end
    def cyclomatic_visit(graph_node)
        raise "crash me" if caller.length > 500
        if graph_node==nil then return end
        #STDERR.puts "  Exploring: #{graph_node}"
        if not graph_node.dummy then @stack.push(graph_node) end
        #@stack.push(graph_node)
        #puts graph_node.class
        begin
        if graph_node==@end then dump_stack
        elsif graph_node.class==IfNode
            #STDERR.puts "Exploring if node: #{graph_node}"
            if not @negated[graph_node]
                # visit true node once, then flip condition
                @condition_changed= (not graph_node.dummy)
                @negated[graph_node]=true
                cyclomatic_visit(graph_node.true_node)
                @condition_changed= (not graph_node.dummy)
                #STDERR.puts "  changed"
            end
            #STDERR.puts "  false case"
            cyclomatic_visit(graph_node.false_node)

        elsif graph_node.next_node==nil && @condition_changed
            # look up stack for a next node
            parent=@stack.reverse.find do |n|
                n.next_node!=nil and n.next_node != graph_node and not @stack.include?(n.next_node)
            end
            #STDERR.puts parent
            if parent and parent.next_node!=@end
                #puts parent.inspect
                #puts next_node
                cyclomatic_visit(parent.next_node)
            else
                dump_stack
            end


        else
            #STDERR.puts "  Exploring children of #{graph_node}: #{graph_node.next_node}, condition_changed: #{@condition_changed}"
            cyclomatic_visit(graph_node.next_node) unless graph_node.next_node==graph_node
        end
        rescue NoMethodError => e
            STDERR.puts @stack.inspect
            STDERR.puts e
            STDERR.puts e.backtrace
            raise "Error while generating testpaths. Function was: #{@root.inspect}. Node was : #{graph_node.inspect}. Cause was: #{e}"
        end
        if not graph_node.dummy then @stack.pop end
        #@stack.pop
    end

    def dump_tests
        # DFS traversal of graph
        @stack=[]
        @condition_changed=true
        # track negation of conditions
        @negated=Hash.new
        @testcase=0
        cyclomatic_visit(@root)
        if @mode=="count"
            puts "#{@root} #{@paths.length}"
        end
        @paths
    end
end
