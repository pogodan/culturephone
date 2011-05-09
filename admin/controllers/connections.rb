Admin.controllers :connections do

  get :index do
    @connections = Connection.desc(:created_at)
    render 'connections/index'
  end

  get :new do
    @connection = Connection.new
    render 'connections/new'
  end

  post :create do
    @connection = Connection.new(params[:connection])
    if @connection.save
      flash[:notice] = 'Connection was successfully created.'
      redirect url(:connections, :show, :id => @connection.id)
    else
      render 'connections/new'
    end
  end

  get :show, :with => :id do
    @connection = Connection.find(params[:id])
    render 'connections/show'
  end

  put :update, :with => :id do
    @connection = Connection.find(params[:id])
    if @connection.update_attributes(params[:connection])
      flash[:notice] = 'Connection was successfully updated.'
      redirect url(:connections, :show, :id => @connection.id)
    else
      render 'connections/show'
    end
  end

  delete :destroy, :with => :id do
    connection = Connection.find(params[:id])
    if connection.destroy
      flash[:notice] = 'Connection was successfully destroyed.'
    else
      flash[:error] = 'Impossible destroy Connection!'
    end
    redirect url(:connections, :index)
  end
end