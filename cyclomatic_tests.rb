require_relative("cyclomatic_complexity.rb")
require_relative("graph_node.rb")
# plan:
# dump CFG statically, do NOT instrument here
# dot format
# node labels are the conditions
# write separate tool to parse CFG from standard format


class CyclomaticTests < Parser::Rewriter
    attr_accessor :child_process

    def initialize()
        @final_process=true
        GraphNode.reset
        @ends=[]
        @parents=[GraphNode.new("toplevel")]
        @parents[0].source="<toplevel>"
        @LOGGING=ENV['LOGGING']
        @MODE=ENV['MODE']||"paths"
        @BLOCKS=ENV['BLOCKS']
        if @BLOCKS=="false"
            @BLOCKS=false
        end
        if @BLOCKS.nil? || @BLOCKS==""
            @BLOCKS=true
        end
        @DUMP_CFG=ENV['DUMP_CFG']=="true"
        @cyclomatic_complexities=[]
        super
    end
    def rewrite(buffer, ast)
        result=super(buffer,ast)
        if @final_process
            visit_count=Hash.new
            function_association=Hash.new
            @cyclomatic_complexities.each do |cc|
                paths = cc.dump_tests
                dump_cfg(paths[0][0])
                _max=0
                paths.each do |path|
                    function=path[0]
                    path.each do |graph_node|
                        function_association[graph_node]=function
                        unless visit_count[graph_node]
                            visit_count[graph_node]=0.0
                        end
                        visit_count[graph_node]+=1.0
                        #_max=[_max, visit_count[graph_node]].max
                    end
                end
                if @MODE=="paths"
                    testpath=0
                    paths.each do |path|
                        puts "Testpath #{testpath+=1}: #{path.join("\n ")}"
                    end
                end
            end
            if @MODE=="path_analysis"
                visit_count.each do |graph_node, count|
                    relative_cost = Rational(count,visit_count[function_association[graph_node]])
                    puts "#{function_association[graph_node]}:#{graph_node} #{relative_cost}"
                end
            end
        end
        result
    end

    def log(msg)
        if @LOGGING
            STDERR.puts( msg)
        end
    end

    def dump_cfg(root)
        if @DUMP_CFG
            File.open("#{root.ast_node.children[0].to_s}.dot", "w") do |f|
                f.write "digraph #{root.ast_node.children[0].to_s.gsub(/[^a-zA-Z0-9]/,'')}{"
                f.write root.to_dot
                f.write "}"
            end
        end
    end

    def on_def(node)
        # new graph
        #puts "NEW GRAPH"
        unless @final_process then return end
        log node.loc.expression.source
        hash= node.loc.to_hash
        root=DefNode.new(node)
        @parents << root
        exitnode=EndNode.new(hash[:end])
        @ends << exitnode
        super
        # link exit point
        @parents[-1].next_node=exitnode
        #raise "Too many remaining parents (#{@parents.length}) on stack: #{@parents}" unless @parents.length==1
        #raise "Too many remaining ends (#{@ends.length}) on stack: #{@ends}" unless @ends.length==1
        log("End of on_def: #{self} #{@parents} #{@ends} #{@final_process}")
        if @final_process
            @cyclomatic_complexities << CyclomaticComplexity.new(root,exitnode, @MODE)
        end
        until @parents[-1]==root
            @parents.pop
        end
        @parents.pop
        until @ends[-1]==exitnode
            @ends.pop
        end
        @ends.pop
    end

    def on_defs(node)
        # new graph
        #puts "NEW GRAPH"
        unless @final_process then return end
        hash=node.loc.to_hash
        # static method
        if Symbol==node.children[1].class
            #log( node.inspect)
            #log( "---")
            root=DefsNode.new(node)
            @parents << root
            exitnode=EndNode.new(hash[:end])
            @ends << exitnode
            super
            # link exit point
            @parents[-1].next_node=exitnode
            log("End of on_defs: #{@parents} #{@ends} #{@final_process}")
            if @final_process
                @cyclomatic_complexities << CyclomaticComplexity.new(root,exitnode, @MODE)
            end
            until @parents[-1]==root
                @parents.pop
            end
            @parents.pop
            until @ends[-1]==exitnode
                @ends.pop
            end
            @ends.pop
        end
    end

    def on_return(node)
        # prematurely exit
        super
        graph_node=ReturnNode.new(node)
        graph_node.next_node=@ends[0]
        @parents[-1].next_node=graph_node

        # add link to VERY end
        #@parents[-1].children.push(graph_node)
        # FIXME: what it the return is in the else?
        # if @parents[-1].class==IfNode
        #     @parents[-1].true_node=TrueNode.new(@parents[-1].ast_node)
        #     @parents[-1].true_node.next_node=graph_node
        # else
        #     @parents[-1].next_node=graph_node
        # end
    end

    def on_if(node)
        # each of this node's child ifs get graph links


        log( "IF STATEMENT")
        log( node.children)
        log( node.loc.to_hash)
        log( node.loc.expression.source)

        hash=node.loc.to_hash

        if hash[:end].nil? and not hash[:else] or hash[:question]
            log( "one-liner: #{node.loc.expression.source}")
            #@ends.push(EndNode.new(node.loc.expression))
            #@ends[-1].source="<implicit end>"
            children=[node.children[0], node.children[1], node.children[2]]
            children=children.map do |e|
                unless e.nil?
                    e=e.loc.expression.source
                end
                e
            end
            newif="#{if hash[:keyword] then hash[:keyword].source else 'if' end} #{children[0]} then #{children[1]} else #{children[2]} end"
            log("Replaced with: #{newif}")
            restart(replace(node.loc.expression, newif))
        end

        if hash[:end]
            # this if is the start of a series of if-elsif
            # link all future ifs in the chain to this one
            end_node=EndNode.new(hash[:end])
            end_node.next_node=@ends[-1]
            @ends.push(end_node)

            # false case
            #@parents[-1].children.push(end_node)
        end

        dummy=false
        _node=node.children[0]
        until(not _node.respond_to?(:children) or _node.children[0].nil?)
            if _node.type==:begin and _node.children[0].type==:if
                # The condition is itself an if statement!
                # This typically arises from and/or rewriting below.
                # Even if a human wrote this, we are really interested
                # in the interior conditions as this if must ultimately
                # return true/false.
                log("Dummy if node")
                dummy=true
                break
            end
            _node=_node.children[0]
        end


        if_node=IfNode.new(node,dummy)
        @parents[-1].next_node=(if_node)
        if_node_end=@ends[-1]
        if_node.next_node=if_node_end
        # recursively descend
        @parents.push(if_node)
        process(node.children[0])
        if_condition_node=nil
        if if_node.next_node != if_node_end
            # complex condition
            if_condition_node = if_node.next_node
            if_node.next_node =  if_node_end
        end

        if if_node.true_node.nil?
            if_node.true_node=TrueNode.new(node,if_node,dummy)
            @parents.push(if_node.true_node)
            process(node.children[1])
            pop_until(@parents,if_node)
            pop_until(@ends,if_node_end)
            #if_node.true_node.next_node=if_node.next_node
            #if_node.next_node=if_node_end
        end
        true_node=if_node.true_node

        if if_node.false_node.nil?
            false_node=FalseNode.new(node,if_node,dummy)
            if_node.false_node=false_node

            log "ELSE? #{hash[:else]}"
            unless node.children[2].nil?
                @parents.push(if_node.false_node)
                process(node.children[2])
                pop_until(@parents,if_node)
                pop_until(@ends,if_node_end)
                if node.children[2].type==:if
                    log "ELSIF: #{GraphNode.nodes_by_keyword[node.children[2].loc.keyword]}"
                    if_node.next_node=GraphNode.nodes_by_keyword[node.children[2].loc.keyword]
                end
            end
        end
        if if_condition_node
            # connect dead ends to true/false nodes
            dead_nodes=if_condition_node.find_dead_nodes
            log "   Dead nodes? #{dead_nodes}"
            dead_nodes.each do |dead_node|
                if dead_node.kind_of?(TrueNode)
                    dead_node.next_node=true_node.next_node
                    log "   Connecting true #{dead_node} to #{dead_node.next_node}"
                else
                    dead_node.next_node=false_node.next_node
                    log "   Connecting false #{dead_node} to #{dead_node.next_node}"
                end
            end
            # blow away the dummy if
            log "   REPLACING #{if_node} with #{if_condition_node}"
            pop_until(@parents,if_node)
            @parents.pop
            @parents[-1].next_node=if_condition_node
            if_condition_node.next_node=if_node_end
        else
            pop_until(@parents,if_node)
            @parents.pop
        end
        if hash[:end]
            # control flow will start from the "end" token from here on in
            pop_until(@ends,if_node_end)
            @parents.push(@ends.pop)
        end
    end

    def pop_until(stack, graph_node)
        popped=stack[-1]
        until popped==graph_node
            stack.pop
            popped=stack[-1]
        end
        popped
    end

    def on_and(node)
        super
        # really two ifs:
        # a && b == (if a then if b then true else false end else false end)
        a = node.children[0]
        b = node.children[1]
        a_source=a.loc.expression.source
        b_source=b.loc.expression.source
        # the __PLACEHOLDER__ substitution ensures the intended control flow
        # see batch_review_helpers.rb:when_read_only
        if not is_if_condition? or a_source.include? "__ASSGNPLACEHOLDER__"
            # if this is a var assignment, then the a/b values might not even be boolean!
            log "Short circuit assignment found: #{node.loc.expression.source}"
            if a_source.include? "__ASSGNPLACEHOLDER__"
                # this is a series of boolean operators
                new_source=a_source.gsub(/else (.*); __ASSGNPLACEHOLDER__/) do |value| "elsif #{$1} then #{$1} else #{b_source}; __ASSGNPLACEHOLDER__" end
            else
                new_source="if #{a_source} then #{b_source} else #{a_source}; __ASSGNPLACEHOLDER__ end"
            end
        else
            # if a_source.include? "__PLACEHOLDER__"
            #     # this is a series of boolean operators
            #     new_source=a_source.gsub("__PLACEHOLDER__","(if #{b_source} then __PLACEHOLDER__ else false end)")
            # else
            #     new_source="(if #{a_source} then if #{b_source} then __PLACEHOLDER__ else false end else false end)"
            # end
            new_source="(if #{a_source} then if #{b_source} then true else false end else false end)"
        end
        source_rewriter=replace(node.loc.expression, new_source)
        restart(source_rewriter)
    end

    def on_or(node)
        super
        a = node.children[0]
        b = node.children[1]
        a_source=a.loc.expression.source
        b_source=b.loc.expression.source
        log "OR: #{@parents.map do |e| e.class end}" 
        if not is_if_condition? or a_source.include? "__ASSGNPLACEHOLDER__"
            # if this is a var assignment, then the a/b values might not even be boolean!
            log "Short circuit assignment found: #{node.loc.expression.source}"
            if a_source.include? "__ASSGNPLACEHOLDER__"
                # this is a series of boolean operators
                new_source=a_source.gsub(/else (.*); __ASSGNPLACEHOLDER__/) do |value| "elsif #{$1} then #{$1} else #{b_source}; __ASSGNPLACEHOLDER__" end
            else
                new_source="if #{a_source} then #{a_source} else #{b_source}; __ASSGNPLACEHOLDER__ end"
            end
        else
            # if a_source.include? "__PLACEHOLDER__"
            #     # this is a series of boolean operators
            #     new_source=a_source.gsub("__PLACEHOLDER__","(if #{b_source} then true else __PLACEHOLDER__ end)")
            # else
            #     new_source="(if #{a_source} then true else (if #{b_source} then true else __PLACEHOLDER__ end) end)"
            # end
            new_source="(if #{a_source} then true else (if #{b_source} then true else false end) end)"
        end
        source_rewriter=replace(node.loc.expression, new_source)
        restart(source_rewriter)
    end



    # Treat iterators as decisions (rubocop does NOT do this)
    # Needed for ./test/test_helpers/assay_configuration/assay_schema_breaker.rb:break_fields in particular
    # FIXME: does not handle nested blocks, like arr.sort!{|x,y| x.name <=> y.name}.each do |arr|
    def on_block(node)
        if @BLOCKS
            #STDERR.puts "BLOCK: #{node.children}"
            _send=node.children[0]
            # TODO: we could inspect the _send's message above and see if it is an iterator.
            # If so, we could rewrite the code using a loop and restart parsing.
            obj, msg = *_send
            arrmethods=[].public_methods(false)
            _args=node.children[1]
            _begin=node.children[2]
            if arrmethods.include?(msg)
                # iterator method - treat as loop
                # FIXME: this code does not actually replicate the iterator.
                log "BLOCK ITERATOR rewritten:"
                log "(if #{obj.loc.expression.source}.any? then #{_begin.loc.expression.source} end)"
                source_rewriter=replace(node.loc.expression, "(if #{obj.loc.expression.source}.any? then #{_begin.loc.expression.source} end)")
                restart(source_rewriter)
            else
                super
            end
        else
            super
        end
    end

    # FIXME: rescue is generally not represented in control flow graphs, so this is hard to figure out
    def on_rescue(node)
        # either thrown or not
        code, resbody=*(node.children)
        exceptions, e, res = *resbody
        log "RESCUE: code=#{code} exceptions=#{exceptions} e=#{e} res=#{res}"
        # handle "rescue e" case
        exception_string = if exceptions then exceptions.loc.expression.source else "Exception" end
        res_string = if res then res.loc.expression.source else "nil" end
        code_string = if code then code.loc.expression.source else "nil" end
        log("Rewriting rescue as fake if statement")
        source_rewriter=replace(node.loc.expression, "if [#{exception_string}].thrown?\n #{res_string}\n else\n #{code_string}\n end")
        restart(source_rewriter)
    end

    def restart(source_rewriter)
        @final_process=false
        new_source=source_rewriter.process
        buffer = Parser::Source::Buffer.new("mytest.rb")#source_rewriter.source_buffer
        buffer.source=new_source
        parser = Parser::CurrentRuby.new
        ast = parser.parse(buffer)
        rewriter= CyclomaticTests.new
        # stack overflow
        thr = Thread.new { rewriter.rewrite(buffer, ast)}
        thr.join
        #puts rewrite
        exit
    end

    def on_case(node)
        # really if-elif-...else
        log("CASE")
        log(node.loc.expression.source)
        variable=nil
        rhs=[]
        bodies=[]
        _else=nil
        node.children.each do |child|
            if child==nil
                # just "case"
                variable=nil
            elsif child.type!=:when
                # "case var"
                variable=child.loc.expression.source
            elsif child.type==:when
                # when cond1, cond2, ...
                # really an if in disjunctive normal form
                prefix=if variable.nil? then "" else "#{variable} ==" end

                condition="#{prefix} #{child.children[0].loc.expression.source}"
                for i in 1...(child.children.length-1)
                    condition= "#{condition} || #{prefix} #{child.children[i].loc.expression.source}"
                end
                rhs << condition

                bodies << child.children[-1].loc.expression.source
            else
                # some other type: presumably default value, at the end
                _else=child.loc.expression.source
            end
        end
        _if="if #{rhs[0]} \n#{bodies[0]} "
        rhs.each_with_index do |condition, i|
            log(i)
            unless i==0
                _if="#{_if} \nelsif #{condition} \n#{bodies[i]} "
            end
        end
        _if="#{_if} \nelse \n#{_else}"
        _if="#{_if} \nend"
        log(_if)
        restart(replace(node.loc.expression, _if))
    end

    def on_loop(node, &_super)
        hash=node.loc.to_hash

        graph_node=IfNode.new(node)
        @parents[-1].next_node=(graph_node)

        end_node=EndNode.new(hash[:end])
        graph_node.next_node=end_node
        @ends.push(end_node)

        # recursively descend
        @parents.push(graph_node)
        _super.call(node)
        @parents.pop

        if graph_node.true_node.nil?
            graph_node.true_node=TrueNode.new(node,graph_node)
            graph_node.true_node.next_node=graph_node.next_node
            graph_node.next_node=@ends[-2]
        end

        false_node=FalseNode.new(node,graph_node)
        graph_node.false_node=false_node

        # false node goes to end
        false_node.next_node=(@ends[-1])

        @parents.push(@ends.pop)
    end

    def on_until(node)
        # true case will execute the loop once, then go to the condition again
        # false case will go to the explicit end
        #log( node.loc.to_hash)
        block=Proc.new{|| super}
        on_loop(node, &block)


    end
    def on_while(node)
        # true case will execute the loop once, then go to the condition again
        # false case will go to the explicit end
        #log( node.loc.to_hash)
        block=Proc.new{|| super}
        on_loop(node, &block)
    end

    def on_for(node)
        # true case will execute the loop once, then go to the condition again
        # false case will go to the explicit end
        #log( node.loc.to_hash)
        block=Proc.new{|| super}
        on_loop(node, &block)
    end

    def is_if_condition?
        # return true if there is an if on the stack and there is not a true/false node in between
        #(0..(@parents.length-1)).to_a.reverse.each do |i|
        @parents.reverse.each do |i|
            log "   #{i}"
            if i.kind_of?(TrueNode) || i.kind_of?(FalseNode)
                return false
            elsif i.kind_of?(IfNode)
                return true
            end
        end
        false
    end

end
