require_relative "./generate_file.rb"

@abbreviations = Hash.new(0)
@pos_and_neg_words = Hash.new(0)

def load_data_to_hash
    #SlangLookupTable.txt
    f = File.open('./lexicons/lexicons/SlangLookupTable.txt','rb')
    content = f.read

    content.split(/[\r\n]/).each do |line|
        next if line.empty?
        words = line.force_encoding("BINARY").gsub(0xA0.chr,"")
                    .split("\t",2)
        @abbreviations[words[0].to_sym] = words[1]
    end
    f.close
    
    #Hu and Bing Liu_positiveAndNegative-words.txt
    f = File.open('./lexicons/lexicons/Hu and Bing Liu_positiveAndNegative-words.txt','rb')
    content = f.read

    content.split(/[\r\n]/).each do |line|
        next if line.empty?
        words = line.force_encoding("BINARY").gsub(0xA0.chr,"")
                    .split(",")
        @pos_and_neg_words[words[0].to_sym] = words[1].to_i
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
	    pipeline =  StanfordCoreNLP.load(:tokenize, :ssplit, :parse,:pos, :lemma) # :tokenize, :ssplit, , :ner, :dcoref
		
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

                # create only @max_rows from each neg and pos 
                next if ((ground_truth >= 1 and ground_truth <= 2 and neg == @max_rows ) or
                        (ground_truth >= 4 and ground_truth <= 5 and pos == @max_rows ))

                ground_truth > 3 ? pos+=1 : neg+=1
                puts "N-#{neg} P-#{pos}"
                if pos == @max_rows and neg == @max_rows
                    break
                end

			else
				puts "error - on line format:\n#{document_text}"
				exit(0)
			end
			cnt_docs+=1
			document_text_only_ascii=""
			document_text.each_byte { |c|
				# only the ascii characters are allowed
				document_text_only_ascii+=c.chr if c==9 || c==10 || c==13 || (c > 31 && c < 127)
			}
			
			print "\n annotating document: #{cnt_docs}"
			document_text_only_ascii = StanfordCoreNLP::Annotation.new(document_text_only_ascii)
			pipeline.annotate(document_text_only_ascii)
			@docs[cnt_docs] = document_text_only_ascii
               full_stem_sen = "" 
               full_abbreviation_sen = "" 
               cnt_negations = 0
               cnt_exclamation = document_text.count("!").to_s

        ################
            document_text_only_ascii.get(:sentences).each do |sentence|

                sentence.get(:tokens).each do |word|
                    word_s = word.get(:original_text).to_s

                    #count number of exclamation marks
                    cnt_negations = @pos_and_neg_words[word_s.to_sym]==1 ?
                        cnt_negations +=1 : cnt_negations -=1

                    #Abbreviation replacement
                    full_abbreviation_sen += 
                    ((replace =  @abbreviations[word_s.to_sym]) != 0 ?
                        replace.to_s : word_s) + " " 
                    #Stanford Stem
                    full_stem_sen += word.get(:lemma).to_s + " "
                end
            end

            cnt_negations = cnt_negations >= 0 ? "1" : "0"

            @stem_docs[id.to_sym] = { gt: ground_truth, 
                                    wang: wang, 
                                    stanford_stem_sen: full_stem_sen,
                                    abbr_replace_sen: full_abbreviation_sen,
                                    cnt_negations: cnt_negations,
                                    cnt_exclamation: cnt_exclamation,
                                    }
        ################
			puts "\.\.\.done!"	
		end
		@numofdocs = cnt_docs
		pipeline = nil
		text = nil
	end# 

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


if __FILE__ == $0
	# every feature will be an option
	start_options=Trollop::options do
		opt :file, "input file. each line is a document", :default => './dataset/TA_wang_benchmark.tsv' # string
		#opt :Count_sentiment, "count the number of positive and negative words",  :default => 1
		#opt :min_occurrences_to_include, "min_occurrences_to_include to include in top n" ,:short => "-o",:default => 2
		opt :max_rows, "max_occurrences_to_include to include in top n" ,:short => "-O",:default => 50
		#opt :Top_n, "top n" , :short => "-n", :default => 3
		#opt :dictionary_train_file, "the file used to calc word proportions", :short => "-t", :default => './example.txt'
		#opt :dictionary_words, "the file containing phrases to calculate proportions on", :short => "-d", :default => './example.txt'
        opt :output, "output learning .arff file", :short => "-f", :default => './dataset/learn.arff'
	end

    p start_options
	
	@max_rows       = start_options[:max_rows]
	input_filename  = start_options[:file]
	@output_filename= start_options[:output]
	
	Trollop::die :file, "must exist" unless File.exist?(start_options[:file]) if start_options[:file]
	
	input   = File.open(start_options[:file],"rb")
	content = input.read
    load_data_to_hash()
    readfile(content)
	#at = readstanfordoutput()
    create_file()
	puts"finish"
	
end
