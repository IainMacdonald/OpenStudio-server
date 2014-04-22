require 'spec_helper'

if File.exists?("/data/worker-nodes/analysis_chauffeur.rb")
  require "/data/worker-nodes/analysis_chauffeur"
else
  require_relative "../../../../worker-nodes/analysis_chauffeur"
end

describe AnalysisChauffeur do

  before :all do
    @library_path = "/data/worker-nodes"
    FileUtils.cp("#{@library_path}/rails-models/mongoid-vagrant.yml", "#{@library_path}/rails-models/mongoid.yml")
  end

  # need to remove dependency on openstudio to actually test analysischauffeur
  it "should create a chauffeur" do
    #def initialize(uuid_or_path, library_path="/mnt/openstudio", rails_model_path="/mnt/openstudio/rails-models", communicate_method="communicate_mongo")

    @ros = AnalysisChauffeur.new("a_uuid_value", @library_path, "#{@library_path}/rails-models")
    expect(@ros).to_not be_nil
  end

  after :all do
    FileUtils.rm("#{@library_path}/rails-models/mongoid.yml")
  end
end