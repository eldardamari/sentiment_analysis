@new_file = nil

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
@ATTRIBUTE is_positive_dominant    {0,1}
@ATTRIBUTE cnt_exclamation  numeric
@ATTRIBUTE has_repeated_characters  {0,1}
@ATTRIBUTE has_more_positive_aspects  {0,1}
@ATTRIBUTE document_length numeric 
@ATTRIBUTE strongsubj_weaksubj numeric 
@ATTRIBUTE class-att    {positive,negative}

@data')

   @stem_docs.each { |line| 

        line[1][:abbr_replace_sen] = line[1][:abbr_replace_sen].gsub(/'/,"\\\\'").gsub(/"/,'\\\\"')

        new_file.puts("'"+ line[1][:abbr_replace_sen] + "'," + \
                      line[1][:is_positive_dominant] + "," + \
                      line[1][:cnt_exclamation] + "," + \
                      line[1][:has_repeated_characters] + "," + \
                      line[1][:document_length] + "," + \
                      gt(line[1][:gt]))
    }
    File.chmod(0777,@output_filename)
    new_file.close
end

def create_arff_file(output_filename)

    @new_file = File.new(@output_filename, "w+")

    File.chmod(0777,@output_filename)
    @new_file.close
end

def write_to_file(line)
    line[:abbr_replace_sen] = line[:abbr_replace_sen].gsub(/'/,"\\\\'").gsub(/"/,'\\\\"')

    @new_file.puts(line[:is_positive_dominant] + "," + \
                  line[:cnt_exclamation] + "," + \
                  line[:has_repeated_characters] + "," + \
                  line[:has_more_positive_aspects] + "," + \
                  line[:document_length] + "," + \
                  line[:strongsubj_weaksubj] + "," + \
                  gt(line[:gt]))
end
    
def open_file()
    @new_file = File.open(@output_filename, "ab")
end

def close_file()
    @new_file.close
end

require 'yaml'
PATH = './dataset/system_results_no_backoffs/'
@system_hash = Hash.new(0)

def parse_and_save_txt_to_yaml
i = 0

    Dir.foreach(PATH) do |file|
        next if file == '.' or file == '..'
        p i
        i+=1

        if file=~ /^hotel_(\d+)_(\w+)_(\w+)_(\d+).txt$/
            review_id = $1 + '_' + $4
            @system_hash[review_id.to_sym] = {positive: Array.new,
                                              negative: Array.new}

            File.readlines(PATH + file).each do |line|

                if line.scrub=~ /^([\w]+)\t(\w+)\,(\w+)\,((?:\d*\.)?\d+)\,(.*)$/
                    if $4.to_f > 0.5
                        @system_hash[review_id.to_sym][:positive].push($1)
                        #@system_hash[review_id.to_sym][:positive].push($1) unless 
                            #@system_hash[review_id.to_sym][:positive].include?($1)

                    elsif $4.to_f < 0.5
                        @system_hash[review_id.to_sym][:negative].push($1)
                        #@system_hash[review_id.to_sym][:negative].push($1) unless 
                            #@system_hash[review_id.to_sym][:negative].include?($1)
                    end
                end
            end
        end
    end
    f = File.new("system_results.yaml","w+")
    f.puts(@system_hash.to_yaml)
    f.close
end

#parse_and_save_txt_to_yaml
p "Loading system_results.yaml file to hash.."
@hash_system_results =  YAML::load_file "./dataset/system_results_aspect/system_results.yaml"

