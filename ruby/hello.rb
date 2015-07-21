class Hello
    def main() # n0
        abc=1
        something_else=false
        what=nil
        
        if true # n3
           #return
           #puts 'abc'
        end # n2
        #ok="ok" unless abc==1
        if abc=='true' # n5
            puts 123
        elsif something_else # n6
            1234
        elsif what.nil? # n7
            "hmm"
        else
            ok
        end # n4
    end # n1
end

puts Hello.new.main()
