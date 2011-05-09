class CulturePhone < Padrino::Application
  register Padrino::Mailer
  register Padrino::Helpers
  
  enable :sessions
  
  before do
    steps = {
      '/ask.json'     => 1,
      '/answer.json'  => 2,
      '/event.json'  => 3,
    }
    req_path  = request.env['PATH_INFO']
    step      = steps[req_path]
    raise "invalid: #{request.inspect}" unless step
    
    @tropo = begin
      json = request.env["rack.input"].read
      puts "about to parse for #{req_path}/#{step}: #{json}"
      
      next if json.blank?
      tropo     = Tropo::Generator.parse(json)
      puts "wtf: #{tropo.inspect}"
    
      # live event, log it
      if tropo
        @call = if ts = tropo.session
          tropo_id = ts.call_id
          
          call = Connection.where(:tropo_id => tropo_id).first || Connection.create!(:tropo_id => tropo_id)
          call.update_attributes!(:from => (ts.from.name || ts.from.id), :network => ts.from.network)
          call
        elsif tr = tropo.result
          tropo_id = tr.actions.call_id || tr.call_id
          Connection.where(:tropo_id => tropo_id).first || Connection.create!(:tropo_id => tropo_id)
        else
          raise "dunno what to do with: #{tropo.inspect}"
        end
                
        @call.hits.create(:raw_data => tropo.to_yaml, :path => req_path, :step => step)
        @actions  = tropo.result.do_or_do_not(:actions)
        puts "got stuffs: #{@call.inspect} | #{@actions.inspect}"
      end
      
      tropo
    end
  end
  
  post '/ask.json' do
    if @actions
      step_2
    else
      step_1
    end
  end
  
  post '/answer.json' do
    # <#Hashie::Mash result=
    #   <#Hashie::Mash actions=<#Hashie::Mash 
    #     event_category=<#Hashie::Mash attempts=1 concept="comedy" confidence=33 disposition="SUCCESS" interpretation="comedy" utterance="comedy" value="comedy" 
    #       xml="<?xml version=\"1.0\"?>\r\n
    #         <result grammar=\"0@d34676db.vxmlgrammar\">\r\n    
    #           <interpretation grammar=\"0@d34676db.vxmlgrammar\" confidence=\"33\">\r\n        \r\n      
    #             <input mode=\"speech\">comedy</input>\r\n   
    #           </interpretation>\r\n
    #         </result>\r\n"
    #     >
    #     call_id="9df093d5fbf774e46c01a2fd3177b901" complete=true error=nil sequence=1 session_duration=16 session_id="339e99e88b3b7487b2a3a8a3a1438baa" state="ANSWERED"
    #   >
    # >
    
    step_2
  end
  
  post 'event.json' do
    step_3
  end

  post '/hangup.json' do
    p @tropo
  end
  
  
  def step_1(start_text = "Edinburgh Festival Info. ")
    categories = %w(music comedy events childrens exhibition discussion theatre)
    choice_values = []
    
    categories.each_with_index do |category, i|
      choice_values << " #{category}(#{i.succ}, #{category})"
    end
    
    tropo = Tropo::Generator.new do
              on :event => 'hangup',    :next => '/hangup.json'
              on :event => 'continue',  :next => '/answer.json'
              ask({ :name    => 'event_category',
                    :bargein => true,
                    :timeout => 10,
                    :require => 'true' }) do
                      say     :value => "#{start_text} Say your event category: #{categories.join(', ')}"
                      choices :value => choice_values.join(', ')
                    end
              end
    tropo.response
  end
  
  def step_2(redo_text = nil)
    @actions = @call.hits.where(:step => 2).last.data.result.actions if redo_text.present? # reset to this step
    fetch_num = 3
    search = @actions.event_category.value
    return step_1("Sooo sorry, I couldn't hear that.") unless search.present?
    
    # just grab a few arbitrarily for now
    event_scope = Event.where(:main_class => /#{search}/i)
    
    random = rand(event_scope.count - fetch_num)
    event_scope = event_scope.skip(random).limit(fetch_num)
    
    question = @call.questions.where(:step => 2).first || @call.questions.create!(:step => 2, :choices => event_scope.map(&:id))
    
    event_choices = []
    question.choice_objects.each_with_index do |event, i|
      event_choices << "for #{event.event_desc} at #{event.venue_desc}, press or say #{i.succ}"
    end
    
    tropo = Tropo::Generator.new do
              on :event => 'hangup',    :next => '/hangup.json'
              on :event => 'continue',  :next => '/event.json'
              ask({ :name    => 'event_id',
                    :bargein => true,
                    :timeout => 10,
                    :require => 'true' }) do
                      say     :value => "#{redo_text} Matching events for #{search}, more info available: #{event_choices.join('. ')}"
                      choices :value => (1 .. event_choices.size).to_a.join(',')
                    end
              end
    tropo.response
  end
  
  def step_3
    search = @actions.event_id.value
    return step_2("What number was that?") unless search.present?
    
    q = @call.current_question
    q.update_attributes(:answer_id => search.to_i)
    return step_2("I heard #{search} and got nothing") unless q.answer.present?
    
    Tropo::Generator.say q.answer.voice_description
  end
  
  ##
  # Caching support
  #
  # register Padrino::Cache
  # enable :caching
  #
  # You can customize caching store engines:
  #
  #   set :cache, Padrino::Cache::Store::Memcache.new(::Memcached.new('127.0.0.1:11211', :exception_retry_limit => 1))
  #   set :cache, Padrino::Cache::Store::Memcache.new(::Dalli::Client.new('127.0.0.1:11211', :exception_retry_limit => 1))
  #   set :cache, Padrino::Cache::Store::Redis.new(::Redis.new(:host => '127.0.0.1', :port => 6379, :db => 0))
  #   set :cache, Padrino::Cache::Store::Memory.new(50)
  #   set :cache, Padrino::Cache::Store::File.new(Padrino.root('tmp', app_name.to_s, 'cache')) # default choice
  #

  ##
  # Application configuration options
  #
  # set :raise_errors, true     # Raise exceptions (will stop application) (default for test)
  # set :dump_errors, true      # Exception backtraces are written to STDERR (default for production/development)
  # set :show_exceptions, true  # Shows a stack trace in browser (default for development)
  # set :logging, true          # Logging in STDOUT for development and file for production (default only for development)
  # set :public, "foo/bar"      # Location for static assets (default root/public)
  # set :reload, false          # Reload application files (default in development)
  # set :default_builder, "foo" # Set a custom form builder (default 'StandardFormBuilder')
  # set :locale_path, "bar"     # Set path for I18n translations (default your_app/locales)
  # disable :sessions           # Disabled sessions by default (enable if needed)
  # disable :flash              # Disables rack-flash (enabled by default if Rack::Flash is defined)
  # layout  :my_layout          # Layout can be in views/layouts/foo.ext or views/foo.ext (default :application)
  #

  ##
  # You can configure for a specified environment like:
  #
  #   configure :development do
  #     set :foo, :bar
  #     disable :asset_stamp # no asset timestamping for dev
  #   end
  #

  ##
  # You can manage errors like:
  #
  #   error 404 do
  #     render 'errors/404'
  #   end
  #
  #   error 505 do
  #     render 'errors/505'
  #   end
  #
end