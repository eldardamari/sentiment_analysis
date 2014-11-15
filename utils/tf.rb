module Tf
private 
    @@model = Hash.new(1)

public

    def learn(text="")
        return text.empty? ? model : train(words(text))
    end

    def words(text)
        return text.downcase.split(/\W+/)
    end

    def train(features)
        features.each { |word| @@model[word.to_sym] +=1 }
        return @@model
    end

    def model
        Hash[@@model.sort_by{|a,b| b}]
    end

end
