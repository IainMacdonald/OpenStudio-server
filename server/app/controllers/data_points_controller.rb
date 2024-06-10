# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class DataPointsController < ApplicationController
  # GET /data_points
  # GET /data_points.json
  def index
    Rails.logger.debug "data_points_controller.index enter"
    @data_points = DataPoint.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @data_points }
    end
    Rails.logger.debug "data_points_controller.index leave"
  end

  # GET /data_points/1
  # GET /data_points/1.json
  def show
    Rails.logger.debug "data_points_controller.show enter"
    @data_point = DataPoint.find(params[:id])
    respond_to do |format|
      if @data_point
        format.html do
          exclude_fields = [:_id, :output, :password, :values]
          @table_data = @data_point.as_json(except: exclude_fields)

          Rails.logger.debug('Cleaning up the log files')
          if @table_data['sdp_log_file']
            @table_data['sdp_log_file'] = @table_data['sdp_log_file'].join('</br>').html_safe
          end

          @data_point.set_variable_values ? @set_variable_values = @data_point.set_variable_values : @set_variable_values = []
        end

        format.json do
          @data_point = @data_point.as_json
          @data_point['set_variable_values_names'] = {}
          @data_point['set_variable_values_display_names'] = {}
          @data_point['set_variable_values'].each do |k, v|
            var = Variable.find(k)
            if var
              new_key = var ? var.name : k
              new_display_key = var ? var.display_name : k
              @data_point['set_variable_values_names'][new_key] = v
              @data_point['set_variable_values_display_names'][new_display_key] = v
            end
          end

          # look up the objective functions and report
          # @data_point['objective_function_results'] = {}

          render json: { data_point: @data_point }
        end
      else
        format.html { redirect_to projects_path, notice: 'Could not find datapoint' }
        format.json { render json: { error: 'No Datapoint' }, status: :unprocessable_entity }
      end
    end
    Rails.logger.debug "data_points_controller.show leave"
  end

  def status
    Rails.logger.debug "data_points_controller.status enter"
    # The name :jobs is legacy based on how PAT queries the datapoints. Should we alias this to status?
    only_fields = [:status, :status_message, :analysis_id]
    dps = params[:status] ? DataPoint.where(status: params[:jobs]).only(only_fields) : DataPoint.all.only(only_fields)

    respond_to do |format|
      #  format.html # new.html.erb
      format.json do
        render json: {
          data_points: dps.map do |dp|
            {
              _id: dp.id,
              id: dp.id,
              analysis_id: dp.analysis_id,
              status: dp.status,
              status_message: dp.status_message
            }
          end
        }
      end
    end
    Rails.logger.debug "data_points_controller.status leave"
  end

  # GET /data_points/new
  # GET /data_points/new.json
  def new
    Rails.logger.debug "data_points_controller.new enter"
    @data_point = DataPoint.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @data_point }
    end
    Rails.logger.debug "data_points_controller.new leave"
  end

  # GET /data_points/1/edit
  def edit
    @data_point = DataPoint.find(params[:id])
  end

  # POST /data_points
  # POST /data_points.json
  def create
    Rails.logger.debug "data_points_controller.create enter"
    error_message = nil

    dp_params = data_point_params
    dp_params[:analysis_id] = params[:analysis_id]
    
    # If the create method receives a list of ordered variable values, then
    # look up the variables by the r_index, and assign the set_variable_values
    if dp_params[:ordered_variable_values]
      Rails.logger.debug 'Mapping ordered variables to actual variables'

      # grab the selected variables
      selected_variables = Variable.variables(dp_params[:analysis_id])

      selected_variables.each do |v|
        Rails.logger.debug "variable: #{v.to_json}"
      end

      variable_values = {} # {variable_uuid_1: value1, variable_uuid_2: value2}
      # make sure the length of the selected variables and the variables array
      # are equal
      if selected_variables.size == dp_params[:ordered_variable_values].size
        dp_params[:ordered_variable_values].each_with_index do |value, index|
          Rails.logger.debug "Adding new variable value for #{selected_variables[index].name} of value #{value}"
          if selected_variables[index]
            uuid = selected_variables[index].uuid

            # Type cast the values as they are probably strings
            if selected_variables[index].value_type  #non-OS variables might not have this set
              case selected_variables[index].value_type.downcase
                when 'double'
                  variable_values[uuid] = value.to_f
                when 'string'
                  variable_values[uuid] = value.to_s
                when 'integer', 'int'
                  variable_values[uuid] = value.to_i
                when 'bool', 'boolean'
                  variable_values[uuid] = value.casecmp('true').zero? ? true : false
                else
                  raise "Unknown DataType for variable #{selected_variables[index].name} of #{selected_variables[index].value_type}"
              end
            else
              raise "Unknown value_type for variable #{selected_variables[index].name} with uuid: #{selected_variables[index].uuid}"
            end
          else
            raise 'Could not find variable in database'
          end
        end

        dp_params.delete(:ordered_variable_values)
        dp_params[:set_variable_values] = variable_values
      else
        error_message = 'Variable array and analysis variable size differ'
        Rails.logger.error error_message

        dp_params.delete(:ordered_variable_values)
        dp_params[:set_variable_values] = {}
      end
    end

    if error_message.nil?
      Rails.logger.debug "Creating datapoint with params: #{dp_params}"
      @data_point = DataPoint.new(dp_params)
    end

    respond_to do |format|
      if error_message.nil? && @data_point.save!
        format.html { redirect_to @data_point, notice: 'Datapoint was successfully created.' }
        format.json { render json: @data_point, status: :created, location: @data_point }
      else
        format.html { render action: 'new' }
        format.json do
          render json: {
            message: error_message,
            data_point_errors: @data_point.nil? ? '' : @data_point.errors
          }, status: :unprocessable_entity
        end
      end
    end
    Rails.logger.debug "data_points_controller.create leave"
  end

  # POST batch_upload.json
  def batch_upload
    analysis_id = params[:analysis_id]
    Rails.logger.info('parsing in a batched file upload')

    uploaded_dps = 0
    saved_dps = 0
    error = false
    error_message = ''
    if params[:data_points]
      uploaded_dps = params[:data_points].count
      Rails.logger.debug "received #{uploaded_dps} points"
      params[:data_points].each do |dp|
        # This is the old format that can be deprecated when OpenStudio V1.1.3 is released
        dp[:analysis_id] = analysis_id # need to add in the analysis id to each datapoint

        @data_point = DataPoint.new(dp)
        if @data_point.save!
          saved_dps += 1
        else
          error = true
          error_message += "could not proccess #{@data_point.errors}"
        end
      end
    end

    respond_to do |format|
      Rails.logger.debug("error flag was set to #{error}")
      if !error
        format.json { render json: "Created #{saved_dps} datapoints from #{uploaded_dps} uploaded.", status: :created, location: @data_point }
      else
        format.json { render json: error_message, status: :unprocessable_entity }
      end
    end
  end

  # PUT /data_points/1.json
  def run
    Rails.logger.debug "data_points_controller.run enter"
    error = false
    error_message = nil
    @data_point = DataPoint.find(params[:id])

    # only run simulations that are in the na state
    if @data_point.status = 'na'
      @data_point.submit_simulation
    end

    respond_to do |format|
      Rails.logger.debug("error flag was set to #{error}")
      if !error
        format.json { render json: @data_point }
      else
        format.json { render json: error_message, status: :unprocessable_entity }
      end
    end
    Rails.logger.debug "data_points_controller.run leave"
  end

  # PUT /data_points/1
  # PUT /data_points/1.json
  def update
    Rails.logger.debug "data_points_controller.update enter"
    @data_point = DataPoint.find(params[:id])

    respond_to do |format|
      if @data_point.update(data_point_params)
        format.html { redirect_to @data_point, notice: 'Datapoint was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @data_point.errors, status: :unprocessable_entity }
      end
    end
    Rails.logger.debug "data_points_controller.update leave"
  end

  # DELETE /data_points/1
  # DELETE /data_points/1.json
  def destroy
    @data_point = DataPoint.find(params[:id])
    analysis_id = @data_point.analysis
    @data_point.destroy

    respond_to do |format|
      format.html { redirect_to analysis_path(analysis_id) }
      format.json { head :no_content }
    end
  end

  # Delete all the result files from the datapoint
  # API only method
  # DELETE /data_points/1/result_files
  def result_files
    Rails.logger.debug "data_points_controller.results_files enter"
    dp = DataPoint.find(params[:id])
    dp.result_files.destroy
    dp.save

    # Check if we want to delete anything else here (e.g. the results hash?)

    respond_to do |format|
      format.json { head :no_content }
    end
    Rails.logger.debug "data_points_controller.results_files leave"
  end

  def requeue
    Rails.logger.warn "data_points_controller.REQUEUE"
    @data_point = DataPoint.find(params[:id])
    analysis_id = @data_point.analysis
    Rails.logger.debug "data_points_controller.id: #{@data_point.id}"
    Rails.logger.debug "data_points_controller.job_id: #{@data_point.job_id}"
    # Destroy the existing job in Resque queue; this is tied to a worker_host:PID:uuid
    Resque::Job.destroy(:simulations, 'ResqueJobs::RunSimulateDataPoint', @data_point.job_id)

    # Enqueue a new job
    Resque.enqueue(ResqueJobs::RunSimulateDataPoint, @data_point.job_id)

    # Attempt to find the worker processing this job
    #worker = find_resque_worker_by_job_id(@data_point.job_id)

    #worker_id = nil
    #if worker
    #  worker_id = worker.to_s # worker_id in "hostname:pid:queues" format
    #  Rails.logger.warn "Worker processing the job: #{worker_id}"
    #  # Optional: Perform actions like signaling the worker if needed
    #else
    #  Rails.logger.warn "No worker found processing the job."
    #end
    
    #try to dequeue
    #Rails.logger.warn "DEQUEUEING #{@data_point.job_id}"
    #jobs_dequeued = Resque.dequeue(ResqueJobs::RunSimulateDataPoint, @data_point.job_id)
    #Rails.logger.warn "DEQUEUED #{jobs_dequeued} jobs"
    #this marks the job as failed
    #Resque.remove_worker(worker_id) if worker_id

    respond_to do |format|
      format.html { redirect_to analysis_path(analysis_id), notice: 'DataPoint was successfully requeued.' }
      format.json { head :no_content }
    end
  end

  def find_resque_worker_by_job_id(job_id)
    Rails.logger.debug "data_points_controller.find_resque_worker_by_job_id"
    Resque.workers.each do |worker|
      # Get the job information that the worker is currently processing
      worker_job = worker.job

      # The job payload is a hash with keys like :queue, :run_at, and :payload
      # The :payload key contains the job details, including the class and args
      job_payload = worker_job['payload'] if worker_job

      # Check if this worker's current job matches the job_id you're looking for
      if job_payload && job_payload['args'].include?(job_id)
        return worker
      end
    end
    nil # Return nil if no worker is found processing the job_id
  end

  
  # upload results file
  # POST /data_points/1/upload_file.json
  def upload_file
    Rails.logger.debug "data_points_controller.upload_file enter"
    # expected params: datapoint_id, file: {display_name, type, data, attachment}
    error = false
    error_messages = []
    datapoint_id = params[:id]
    Rails.logger.debug('Attaching results file to datapoint')

    @data_point = DataPoint.find(datapoint_id)
    if params[:file] && params[:file][:attachment]
      @rf = ResultFile.new(
        display_name: params[:file][:display_name],
        type: params[:file][:type]
      )
      @rf.attachment = params[:file][:attachment]

      @data_point.result_files << @rf

      unless @data_point.save!
        error = true
        error_messages << 'Result File could not be saved: ' + @data_point.errors
      end
    else
      error = true
      error_messages << 'Missing attachment parameter'
    end

    respond_to do |format|
      if error
        format.json { render json: { error: error_messages, result_file: params[:file] }, status: :unprocessable_entity }
      else
        format.json { render 'result_file', status: :created, location: data_point_url(@data_point) }
      end
    end
    Rails.logger.debug "data_points_controller.upload_file leave"
  end

  # download a datapoint report of filename
  def download_report
    Rails.logger.debug "data_points_controller.download_report enter"
    @data_point = DataPoint.find(params[:id])

    h = nil
    dp_params = data_point_params
    if dp_params[:filename]
      h = @data_point.result_files.where(display_name: dp_params[:filename]).first
    end

    if h&.attachment && File.exist?(h.attachment.path)
      if /darwin/.match(RUBY_PLATFORM) || /linux/.match(RUBY_PLATFORM)
        file_data = File.read(h.attachment.path)
      else
        file_data = File.binread(h.attachment.path)
      end
      send_data file_data
    else
      respond_to do |format|
        format.json { render json: { status: 'error', error_message: 'could not find report' }, status: :unprocessable_entity }
      end
    end
    Rails.logger.debug "data_points_controller.download_report leave"
  end

  # GET /data_points/1/download_result_file
  def download_result_file
    Rails.logger.debug "data_points_controller.download_result_file enter"
    @data_point = DataPoint.find(params[:id])

    file = @data_point.result_files.where(attachment_file_name: params[:filename]).first
    if file&.attachment && File.exist?(file.attachment.path)
      if /darwin/.match(RUBY_PLATFORM) || /linux/.match(RUBY_PLATFORM)
        file_data = File.read(file.attachment.path)
      else
        file_data = File.binread(file.attachment.path)
      end
      disposition = ['application/json', 'text/plain', 'text/html'].include?(file.attachment.content_type) ? 'inline' : 'attachment'
      send_data file_data, filename: File.basename(file.attachment.original_filename), type: file.attachment.content_type, disposition: disposition
    else
      respond_to do |format|
        format.json { render json: { status: 'error', error_message: 'could not find result file' }, status: :unprocessable_entity }
        format.html { redirect_to @data_point, notice: "Result file '#{params[:filename]}' does not exist. It probably was deleted from the file system." }
      end
    end
    Rails.logger.debug "data_points_controller.download_result_file leave"
  end

  def dencity
    @data_point = DataPoint.find(params[:id])

    dencity = nil
    if @data_point
      # reformat the data slightly to get a concise view of the data
      dencity = {}

      # instructions for building the inputs
      measure_instances = []
      if @data_point.analysis['problem']
        @data_point.analysis['problem']['workflow']&.each_with_index do |wf, _index|
          m_instance = {}
          m_instance['uri'] = 'https://bcl.nrel.gov or file:///local'
          m_instance['id'] = wf['measure_definition_uuid']
          m_instance['version_id'] = wf['measure_definition_version_uuid']

          if wf['arguments']
            m_instance['arguments'] = {}
            wf['variables']&.each do |var|
              m_instance['arguments'][var['argument']['name']] = @data_point.set_variable_values[var['uuid']]
            end

            wf['arguments'].each do |arg|
              m_instance['arguments'][arg['name']] = arg['value']
            end
          end

          measure_instances << m_instance
        end
      end

      dencity[:measure_instances] = measure_instances

      # Don't use this old method.  Instead get the dencity reporting variables from the metadata_id flag
      # dencity[:structure] = @data_point[:results]['dencity_reports']

      # Grab all the variables that have defined a measure ID and pull out the results
      vars = @data_point.analysis.variables.where(:metadata_id.exists => true, :metadata_id.ne => '')
                        .order_by(:name.asc).as_json(only: [:name, :metadata_id])

      dencity[:structure] = {}
      vars.each do |v|
        a, b = v['name'].split('.')
        logger.debug "#{v[:metadata_id]} had #{a} and #{b}"

        if dencity[:structure][v['metadata_id']].present?
          logger.error "DEnCity variable '#{v['metadata_id']} is already defined in output as #{a}:#{b}"
        end

        if @data_point[:results][a].present? && @data_point[:results][a][b].present?
          dencity[:structure][v['metadata_id']] = @data_point[:results][a][b]
        else
          logger.warn 'could not find result'
          dencity[:structure][v['metadata_id']] = nil
        end
      end
    end

    respond_to do |format|
      if dencity
        format.json { render json: dencity.to_json }
      else
        format.json { render json: { error: 'Could not format datapoint into DEnCity view' }, status: :unprocessable_entity }
      end
    end
  end

  private

  def data_point_params
    Rails.logger.debug "data_points_controller.data_point_params enter"
    params.require(:data_point).permit!.to_h
  end
end
