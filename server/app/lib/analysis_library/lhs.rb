# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class AnalysisLibrary::Lhs < AnalysisLibrary::Base
  include AnalysisLibrary::R::Core

  def initialize(analysis_id, analysis_job_id, options = {})
    # Setup the defaults for the Analysis.  Items in the root are typically used to control the running of
    #   the script below and are not necessarily persisted to the database.
    #   Options under problem will be merged together and persisted into the database.  The order of
    #   preference is objects in the database, objects passed via options, then the defaults below.
    #   Parameters posted in the API become the options hash that is passed into this initializer.
    defaults = ActiveSupport::HashWithIndifferentAccess.new(
      skip_init: false,
      run_data_point_filename: 'run_openstudio_workflow.rb',
      problem: {
        algorithm: {
          number_of_samples: 5,
          sample_method: 'individual_variables',
          failed_f_value: 1e18,
          debug_messages: 0,
          seed: nil
        }
      }
    )
    @options = defaults.deep_merge(options)

    @analysis_id = analysis_id
    @analysis_job_id = analysis_job_id
  end

  # Perform is the main method that is run in the background.  At the moment if this method crashes
  # it will be logged as a failed delayed_job and will fail after max_attempts.
  def perform
    @analysis = Analysis.find(@analysis_id)

    # get the analysis and report that it is running
    @analysis_job = AnalysisLibrary::Core.initialize_analysis_job(@analysis, @analysis_job_id, @options)

    # reload the object (which is required) because the subdocuments (jobs) may have changed
    @analysis.reload

    # Create an instance for R
    @r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'],
                                                 APP_CONFIG['rserve_port'])

    begin
      logger.info "Initializing analysis for #{@analysis.name} with UUID of #{@analysis.uuid}"
      logger.info "Setting up R for #{self.class.name}"
      # TODO: can we move the mkdir_p to the initialize task
      FileUtils.mkdir_p APP_CONFIG['sim_root_path'] unless Dir.exist? APP_CONFIG['sim_root_path']
      @r.converse("setwd('#{APP_CONFIG['sim_root_path']}')")

      # make this a core method
      if !@analysis.problem['algorithm']['seed'].nil? && (@analysis.problem['algorithm']['seed'].is_a? Numeric)
        logger.info "Setting R base random seed to #{@analysis.problem['algorithm']['seed']}"
        @r.converse("set.seed(#{@analysis.problem['algorithm']['seed']})")
      end

      pivot_array = Variable.pivot_array(@analysis.id, @r)
      logger.debug "pivot_array: #{pivot_array}"

      selected_variables = Variable.variables(@analysis.id)
      logger.info "Found #{selected_variables.count} variables to perturb"

      # generate the probabilities for all variables as column vectors
      @r.converse("print('starting lhs')")
      samples = nil
      var_types = nil
      logger.info 'Starting sampling'
      lhs = AnalysisLibrary::R::Lhs.new(@r)
      if @analysis.problem['algorithm']['sample_method'] == 'all_variables' ||
         @analysis.problem['algorithm']['sample_method'] == 'individual_variables'
        samples, var_types = lhs.sample_all_variables(selected_variables, @analysis.problem['algorithm']['number_of_samples'])
        if @analysis.problem['algorithm']['sample_method'] == 'all_variables'
          # Do the work to mash up the samples and pivot variables before creating the datapoints
          logger.debug "Samples are #{samples}"
          samples = hash_of_array_to_array_of_hash(samples)
          logger.debug "Flipping samples around yields #{samples}"
        elsif @analysis.problem['algorithm']['sample_method'] == 'individual_variables'
          # Do the work to mash up the samples and pivot variables before creating the datapoints
          logger.debug "Samples are #{samples}"
          samples = hash_of_array_to_array_of_hash_non_combined(samples, selected_variables)
          logger.debug "Non-combined samples yields #{samples}"
        end
      else
        raise 'no sampling method defined (all_variables or individual_variables)'
      end

      logger.info 'Fixing Pivot dimension'
      samples = add_pivots(samples, pivot_array)
      logger.debug "Finished adding the pivots resulting in #{samples}"

      # Add the datapoints to the database
      isample = 0
      samples.uniq.each do |sample| # do this in parallel
        isample += 1
        dp_name = "LHS Autogenerated #{isample}"
        dp = @analysis.data_points.new(name: dp_name)
        dp.set_variable_values = sample
        dp.save!

        logger.info("Generated datapoint #{dp.name} for analysis #{@analysis.name}")
      end
    rescue StandardError => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      puts log_message
      @analysis.status_message = log_message
      @analysis.save!
    ensure
      # Only set this data if the analysis was NOT called from another analysis
      unless @options[:skip_init]
        @analysis_job.end_time = Time.now
        @analysis_job.status = 'completed'
        @analysis_job.save!
        @analysis.reload
      end
      @analysis.save!

      logger.info "Finished running analysis '#{self.class.name}'"
    end
  end
end
