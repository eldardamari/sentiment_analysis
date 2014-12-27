require_relative "./generate_file.rb"

@abbreviations      = Hash.new(0)
@pos_and_neg_words  = Hash.new(-1)
@strongsubj_weaksubj= Hash.new(0) #strong-pos = 2 , strong-neg = -2 , weak-pos = 1 , weak-neg = -1
@question_words     = Hash.new(0)

def load_data_to_hash
    #SlangLookupTable.txt
    f = File.open(@slang_file,'rb')
    content = f.read

    content.split(/[\r\n]/).each do |line|
        next if line.empty?
        words = line.force_encoding("BINARY").gsub(0xA0.chr,"")
                    .split("\t",2)
        @abbreviations[words[0].to_sym] = words[1]
    end
    f.close
    
    #Hu and Bing Liu_positiveAndNegative-words.txt
    f = File.open(@pos_neg_file,'rb')
    content = f.read

    content.split(/[\r\n]/).each do |line|
        next if line.empty?
        words = line.force_encoding("BINARY").gsub(0xA0.chr,"")
                    .split(",")
        @pos_and_neg_words[words[0].to_sym] = words[1].to_i
    end
    f.close
    
    #strongsubj-positive/negtive weakesubj-positive/negative
    f = File.open(@strongsubj_weaksubj_file,'rb')
    content = f.read

    content.split(/[\r\n]/).each do |line|
        next if line.empty?
        line.force_encoding("BINARY").gsub(0xA0.chr,"") =~ /(\w+-\w+) (\w+)/
        sen = $1
        word = $2
        value = 0

        case sen
            when "strongsubj-positive" then value = 2
            when "strongsubj-negative" then value = -2
            when "weaksubj-positive" then value = 1
            when "weaksubj-negative" then value = -1
        else value = 0
        end
        @strongsubj_weaksubj[word.to_sym] = value
    end
    f.close
    
    #lexicons/QuestionWords
    f = File.open(@question_words_file,'rb')
    content = f.read

    content.split(/[\r\n]/).each do |line| # word in a line
        next if line.empty?
        line.force_encoding("BINARY").gsub(0xA0.chr,"")
        @question_words[line.to_sym] = 1
    end
    f.close
end

def readfile(filecontent)

        neg = 0
        pos = 0
        # constractor
        @docs = Hash.new(0)
        @stem_docs = Hash.new(0)
		
		@numofdocs = 0
		text = filecontent
		cnt_docs = 0
	    #pipeline =  StanfordCoreNLP.load(:tokenize,:ssplit,:parse ,:lemma) # :tokenize, :ssplit, , :ner, :dcoref
	    #pipeline =  StanfordCoreNLP.load(:tokenize, :ssplit, :parse,:pos, :lemma) # :tokenize, :ssplit, , :ner, :dcoref
		
		# ssplit - Splits a sequence of tokens into sentences.
		#pos - part of speech
		#ner - named entity recognizer
		
		text.split(/[\n\r]/).each do |document_text|
		
		next if document_text=~/^ *$/
			
		
        if document_text=~/^([^\t]+)\t([1-5]+)\t(\d+)\t(.*)$/
            id = $1
            ground_truth = $2.to_i
            next if ground_truth == 3
            wang = ( $3.to_i > 5 ? 5 : $3.to_i)
            document_text = $4

            if @even_rows > 0
                # create only @even_rows from each neg and pos 
                next if ((ground_truth >= 1 and ground_truth <= 2 and neg == @even_rows ) or
                         (ground_truth >= 4 and ground_truth <= 5 and pos == @even_rows ))

                ground_truth > 3 ? pos+=1 : neg+=1
                puts "N-#{neg} P-#{pos}"
                if pos == @even_rows and neg == @even_rows
                    break
                end
            end

        else
            puts "error - on line format:\n#{document_text}"
            exit(0)
        end
        cnt_docs+=1
        document_text_only_ascii=nil
        document_text_only_ascii=""
        document_text.each_byte { |c|
            # only the ascii characters are allowed
            document_text_only_ascii+=c.chr if c==9 || c==10 || c==13 || (c > 31 && c < 127)
        }

        print "annotating document: #{cnt_docs}"
        #break if cnt_docs == 1000
        #document_text_only_ascii = StanfordCoreNLP::Annotation.new(document_text_only_ascii)
        #pipeline.annotate(document_text_only_ascii)
        #//FIXME@docs[cnt_docs] = document_text_only_ascii
        full_stem_sen = "" 
        full_abbreviation_sen = "" 
        is_positive_dominant = 0
        cnt_exclamation = document_text.count("!").to_s
        has_repeated_characters = (document_text =~ /([a-z])\1\1+/i)  ?  "1" : "0"
        replace = ""
        strongsubj_weaksubj = 0
        first_letter_upper_case = 0
        number_of_upper_case = 0
        has_question_words = 0

        # iterate each word in review
        document_text.split(" ").each do |word|

            #Abbreviation replacement
            full_abbreviation_sen += 
                ((replace =  @abbreviations[word.to_sym]) != 0 ?
                 replace.to_s : word) + " " 

            #count number of good words
            if (@pos_and_neg_words[word.to_sym]==1 or 
                @pos_and_neg_words[replace == 0 ? word.to_sym : replace.to_sym]==1)
                is_positive_dominant +=1
            elsif (@pos_and_neg_words[word.to_sym]==0 or 
                   @pos_and_neg_words[replace == 0 ? word.to_sym : replace.to_sym]==0)
                is_positive_dominant -=1 
            end
            
            #count strongsubj_weaksubj pos/neg
            strongsubj_weaksubj += @strongsubj_weaksubj[word.to_sym]

            #number of words with first capital letter
            if (word =~ /^[A-Z].*$/) == 0 then first_letter_upper_case +=1 end

            #number of words all capitilize
            if (word =~ /^[A-Z'"`]+$/) == 0 then number_of_upper_case +=1 end

            #has question words
            if @question_words[word.to_sym] == 1 and has_question_words == 0
                has_question_words = 1
            end

        end

        ###############
        if false
            document_text_only_ascii.get(:sentences).each do |sentence|

                sentence.get(:tokens).each do |word|
                    word_s = word.get(:original_text).to_s

                    #count number of good words
                    is_positive_dominant = @pos_and_neg_words[word_s.to_sym]==1 ?
                        is_positive_dominant +=1 : is_positive_dominant -=1

                    #Abbreviation replacement
                    full_abbreviation_sen += 
                        ((replace =  @abbreviations[word_s.to_sym]) != 0 ?
                         replace.to_s : word_s) + " " 
                    #Stanford Stem
                    full_stem_sen += word.get(:lemma).to_s + " "
                end
            end
        end

        is_positive_dominant = is_positive_dominant >= 0 ? "1" : "0"
        has_more_positive_aspects = (@hash_system_results[id.to_sym][:positive].size >
                                     @hash_system_results[id.to_sym][:negative].size) ? 
                                    "1" : "0"
        document_length = document_text.length.to_s
        has_question_words = (has_question_words == 1) ? "1" : "0"

        line = { gt: ground_truth, 
                                  wang: wang, 
                                  stanford_stem_sen: document_text_only_ascii,
                                  abbr_replace_sen: full_abbreviation_sen,
                                  is_positive_dominant: is_positive_dominant,
                                  cnt_exclamation: cnt_exclamation,
                                  has_repeated_characters: has_repeated_characters,
                                  has_more_positive_aspects: has_more_positive_aspects,
                                  document_length: document_length,
                                  strongsubj_weaksubj: strongsubj_weaksubj.to_s,
                                  first_letter_upper_case: first_letter_upper_case.to_s,
                                  number_of_upper_case: number_of_upper_case.to_s,
                                  has_question_words: has_question_words,
        }
        open_file()
        write_to_file(line)
        close_file()
        ################
        puts "\.\.\.done!"	
        end
        @numofdocs = cnt_docs
        pipeline = nil
        text = nil
end 

def readstanfordoutput()

    #cnt_docs=1

    @stem_docs.each do |steem_sentence|
        #puts steem_sentence.inspect [:"id", {gt: 1-5, wang: 0-5, tex: review}]
    end

    #@docs.each do |doc|
    #	
    #	doc[1].get(:sentences).each do |sentence|
    #		puts"#{sentence}"	
    #	end # sentence

    #	cnt_docs+=1	
    #end

    #return cnt_docs
end #add_feature_count_words


################# main - args #################
require 'trollop'
require 'stanford-core-nlp'
require 'yaml'


if __FILE__ == $0
    # every feature will be an option
    start_options=Trollop::options do
        opt :file,          "Input file (dataset) to learn from.", :default => './dataset/TA_wang_benchmark.tsv' # string
        opt :slang_file,    "Input feature file - frequent abbreviations, (i.e lol=laugh out loud, btw=by the way)", :default => './lexicons/SlangLookupTable.txt' # string
        opt :pos_neg_file, "Input feature file - positive and negative words, (i.e wow = 1, bad = 0)", :default => './lexicons/Hu and Bing Liu_positiveAndNegative-words.txt' # string
        opt :strongsubj_weaksubj_file, "Input feature file - strongsubj pos/neg - weaksubj pos/neg", :default => './lexicons/strongsubj_weaksubj.train' # string
        opt :question_words_file, "Input feature file - list of question words", :default => './lexicons/QuestionWords.txt' # string
        opt :even_rows, "equal numbers of rows from positive and negative" ,:short => "-O",:default => 0
        opt :output, "output learning .arff file", :default => './dataset/learn.arff'
        #opt :Top_n, "top n" , :short => "-n", :default => 3
        #opt :dictionary_train_file, "the file used to calc word proportions", :short => "-t", :default => './example.txt'
        #opt :dictionary_words, "the file containing phrases to calculate proportions on", :short => "-d", :default => './example.txt'
    end

    p start_options

    @even_rows       = start_options[:even_rows]
    input_filename  = start_options[:file]
    @output_filename= start_options[:output]

    @slang_file = start_options[:slang_file]
    @pos_neg_file = start_options[:pos_neg_file]
    @strongsubj_weaksubj_file = start_options[:strongsubj_weaksubj_file]
    @question_words_file = start_options[:question_words_file]

    Trollop::die :file, "must exist" unless File.exist?(start_options[:file]) if start_options[:file]


    input   = File.open(start_options[:file],"rb")
    content = input.read
    load_data_to_hash()
    create_arff_file(@output_filename)
    readfile(content)
    #at = readstanfordoutput()
    #create_file()
    puts "finish"
end
