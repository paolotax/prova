class ItalianDateParser
  GIORNI_SETTIMANA = {
    'lunedì' => 1,
    'martedì' => 2,
    'mercoledì' => 3,
    'giovedì' => 4,
    'venerdì' => 5,
    'sabato' => 6,
    'domenica' => 0
  }.freeze

  MESI = {
    'gennaio' => 1,
    'febbraio' => 2,
    'marzo' => 3,
    'aprile' => 4,
    'maggio' => 5,
    'giugno' => 6,
    'luglio' => 7,
    'agosto' => 8,
    'settembre' => 9,
    'ottobre' => 10,
    'novembre' => 11,
    'dicembre' => 12
  }.freeze

  def self.parse(testo, base_time = Time.zone.now)
    parser = new(testo, base_time)
    parser.parse
  end

  def initialize(testo, base_time = Time.zone.now)
    @testo = testo.downcase.strip
    @base_time = base_time
  end

  def parse
    return @base_time if @testo.blank?

    case @testo
    when /^oggi$/
      @base_time
    when /^domani$/
      @base_time + 1.day
    when /^dopodomani$/
      @base_time + 2.days
    when /^ieri$/
      @base_time - 1.day
    when /^tra (\d+) (giorn[oi]|settiman[ae]|mes[ei]|ann[oi])/
      numero = $1.to_i
      unita = case $2
        when /giorn/    then :days
        when /settiman/ then :weeks
        when /mes/      then :months
        when /ann/      then :years
      end
      @base_time + numero.send(unita)
    when /(lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica) prossimo/
      next_weekday(GIORNI_SETTIMANA[$1])
    when /il (\d{1,2})(?: del)? (mese prossimo)/
      giorno = $1.to_i
      next_month_date(giorno)
    when /il (\d{1,2}) ([a-z]+)/
      giorno = $1.to_i
      mese = MESI[$2]
      return nil unless mese
      date_in_future(giorno, mese)
    when /^entro (?:il )?(\d{1,2})(?: del?)? ([a-z]+)$/
      giorno = $1.to_i
      mese = MESI[$2]
      return nil unless mese
      date_in_future(giorno, mese)
    when /^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?$/
      giorno = $1.to_i
      mese = $2.to_i
      anno = if $3
        anno_str = $3
        anno_str.length == 2 ? "20#{anno_str}".to_i : anno_str.to_i
      else
        @base_time.year
      end
      begin
        data = Date.new(anno, mese, giorno)
        data = Date.new(anno + 1, mese, giorno) if data < @base_time.to_date
        data
      rescue
        nil
      end
    when /^(\d{1,2})-(\d{1,2})-(\d{2,4})$/
      giorno = $1.to_i
      mese = $2.to_i
      anno = if $3.length == 2
        "20#{$3}".to_i
      else
        $3.to_i
      end
      begin
        Date.new(anno, mese, giorno)
      rescue
        nil
      end
    else
      nil
    end
  rescue
    nil
  end

  private

  def next_weekday(target_wday)
    current_wday = @base_time.wday
    days_ahead = if target_wday <= current_wday
      7 - (current_wday - target_wday)
    else
      target_wday - current_wday
    end
    @base_time + days_ahead.days
  end

  def next_month_date(giorno)
    next_month = @base_time.beginning_of_month + 1.month
    Date.new(next_month.year, next_month.month, giorno)
  end

  def date_in_future(giorno, mese)
    year = @base_time.year
    candidate = Date.new(year, mese, giorno)
    candidate = Date.new(year + 1, mese, giorno) if candidate < @base_time.to_date
    candidate
  end
end 