class Hello
    #def if_in_if()
    #    if (if 1==1 then (if not 2 then true else false end) else false end) then (if 'a' then true else false end) else false end
    #    [1,2,3].each do |e|
    #        if e %2==1 then puts e end
    #    end
    #
    #end
    # def main() # n0
    #     abc=1
    #     something_else=false
    #     what=nil
        
    #     if true # n3
    #        return
    #        #puts 'abc'
    #     end # n2
    #     ok="ok" unless abc==1
    #     if abc=='true' # n5
    #         puts 123
    #     elsif something_else # n6
    #         1234
    #     elsif what.nil? # n7
    #         "hmm"
    #     else
    #         ok
    #     end # n4
    # end # n1

    # def crazyloop(abc)
    #     until abc==1000
    #         abc+=1
    #         if abc%4==0
    #             abc+=2
    #         end
    #         if abc%3==0
    #             abc+=5
    #         end
    #     end
    # end

    # def short_circuit(w,x,y,z)
    #     a=w||x||y
    #     c=x
    #     d=if y||z then w else x end
    # end

    def block_test(abc)
        if abc==1
            abc=2
        end
        [abc,1,2,3].each do |n|
            puts n
            if n==3 then abc=n end
            puts abc
        end
        if abc==3
            puts "abc changed"
        end
    end

    # def block_test_2(hash, field_schemas)
    #     field_schemas && field_schemas.each do |field_schema|
    #       name = field_schema[0]
    #       options = field_schema[2] || {}
    #       if hash[name] and options and options[@option_of_interest] and (not IGNORED_FIELDS.include? name)
    #         send(@breaker_function, hash, field_schemas, name, options)
    #       end
    #     end
    #     hash
    # end

    # def rescue_test
    #     puts uhoh
    #     puts reallyrubouhoh
    #     rescue Exception,Exception2 => e
    #         puts e
    # end
end

puts Hello.new.main()
