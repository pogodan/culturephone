class Question
  include Mongoid::Document
  include Mongoid::Timestamps
  
  referenced_in :connection
  
  field :step, :type => Integer
  field :choices, :type => Hash
  field :answer_id,  :type => Integer
  
  # FIXME: reference/serialize objects properly
  def choice_objects
    choices.map{|event_id| Event.find(event_id) }
  end
  
  def answer
    choice_objects[answer_id] if answer_id.present?
  end
end