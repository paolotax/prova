class Prezzo 
  attr_reader :cents 
  
  def initialize(dollars) 
    @cents =  if dollars 
                (BigDecimal(dollars) * 100).to_i
              end
  end
end