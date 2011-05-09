class Hit
  include Mongoid::Document
  include Mongoid::Timestamps
  
  referenced_in :connection
  field :path
  field :raw_data,  :type => Hash
  field :step,      :type => Integer
  
  def data
    YAML.load(raw_data)
  end
end