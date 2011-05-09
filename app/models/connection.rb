class Connection
  include Mongoid::Document
  include Mongoid::Timestamps
  
  references_many :hits
  references_many :questions
  
  field :tropo_id
  field :from
  field :network
  
  validates_presence_of :tropo_id
  
  def current_question
    Question.desc(:created_at).first
  end
end