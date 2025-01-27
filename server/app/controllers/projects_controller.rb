# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class ProjectsController < ApplicationController
  # GET /projects
  # GET /projects.json
  def index
    @projects = Project.all

    logger.debug(@projects.to_json(include: :analyses))

    respond_to do |format|
      format.html # index.html.erb
      # format.json { render json: @projects.to_json(:) }
      # => { :status => @analysis.status}, data_points: dps.map{ |k| {:_id => k.id, :status => k.status } } } }
      format.json { render json: @projects.to_json(include: :analyses) }
    end
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    @project = Project.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb

      format.json { render json: @project.to_json(include: :analyses) }
    end
  end

  # GET /projects/new
  # GET /projects/new.json
  def new
    @project = Project.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @project }
    end
  end

  # GET /projects/1/edit
  def edit
    @project = Project.find(params[:id])
  end

  # POST /projects
  # POST /projects.json
  def create
    @project = Project.new(project_params)

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.json { render json: @project, status: :created, location: @project }
      else
        format.html { render action: 'new' }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /projects/1
  # PUT /projects/1.json
  def update
    @project = Project.find(params[:id])

    respond_to do |format|
      if @project.update_attributes(params[:project])
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @project = Project.find(params[:id])
    @project.destroy

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path) }
      format.json { head :no_content }
    end
  end

  def status
    @project = Project.find(params[:id])

    # get the list of all the statuses
    q = nil
    if params[:jobs].nil?
      q = @project.analyses.all
    else
      q = @project.analyses.where(status: params[:jobs])
    end

    respond_to do |format|
      #  format.html # new.html.erb
      format.json { render json: { analyses: q } }
    end
  end

  private

  def project_params
    params.require(:project).permit!
  end
end
