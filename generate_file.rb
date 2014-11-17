def gt(num)
    case num
    when 1..2 
        return 'negative'
    when 3..5
        return 'positive'
    end
end

def create_file()
    i = 0
    new_file = File.new(@output_filename, "w+")

    new_file.puts('
@RELATION   review_learn

@ATTRIBUTE text     string
@ATTRIBUTE cnt_negations    {0,1}
@ATTRIBUTE class-att    {positive,negative}

@data')

   @stem_docs.each { |line| 

        line[1][:abbr_replace_sen] = line[1][:abbr_replace_sen].gsub(/'/,"\\\\'").gsub(/"/,'\\\\"')

        new_file.puts("'"+ line[1][:abbr_replace_sen] + "'," + line[1][:cnt_negations] + "," + gt(line[1][:gt]))
    }
    File.chmod(0777,@output_filename)
    new_file.close
end
