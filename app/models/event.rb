class Event
  include Mongoid::Document
  include Mongoid::Timestamps
  include Padrino::Helpers::FormatHelpers
  
  field :event_id # festivals2010_3075
  field :event_token # THE LIST
  field :src_code # EAF
  field :area_code # EAF
  field :event_code # "Joan Mitchell: Portrait of an Abstract Painter"
  field :venue_code#  Inverleith House
  field :area_desc # Edinburgh Art Festival
  field :event_desc # "Joan Mitchell: Portrait of an Abstract Painter"
  field :venue_desc # Inverleith House
  field :postcode # EH3 5LR
  field :event_latitude # "0.000000000000"
  field :event_longitude # "0.000000000000"
  field :main_class # Exhibition
  field :event_info # A film about the artist, directed by Marion Cajori, 1992 (58 mins), will be screened continuously throughout the Mitchell exhibition.
  field :venue_info # ""
  field :venue_addr # Royal Botanic Garden
  field :extra_event_texts # TEXTTEXT
  field :min_seat_price # "0.00"
  field :event_url # www.rbge.org.uk/inverleith-house
  field :using_perf_list # # TEXTTEXT
  field :start_time, :type => DateTime # "1280223000"
  field :end_time, :type => DateTime # "1283679000"
  field :festival #art
    
  # we pretend
  def voice_description
    "#{event_desc} starts #{time_ago_in_words(start_time)} from now at the #{venue_desc}, seats from #{min_seat_price} pounds. description follows: #{event_info}"
  end
  
  def start_timestamp=(unixtime)
    write_attribute(:start_time, Time.at(unixtime.to_i))
  end
  
  def end_timestamp=(unixtime)
    write_attribute(:end_time, Time.at(unixtime.to_i))
  end
  
  def self.import(filename = Padrino.root('db/listings.json'))
    JSON.parse(File.read(filename)).each do |json_record|
      #puts listing.inspect
      json_record['event_id'] = json_record.delete('id') # convert field
      
      event = where(:event_id => json_record['event_id']).exists? || create(json_record)
      #puts event.inspect
    end
  end
end