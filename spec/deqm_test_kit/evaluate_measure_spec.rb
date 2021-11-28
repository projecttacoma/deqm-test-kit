frozen_string_literal: true

RSpec.describe DEQMTestKit::EvaluateMeasure do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_test_suite') }
  let(:group) { suite.groups[5] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'deqm_test_suite') }
  url = 'http://example.com/fhir'
  # ensure this url matches url in embedded_client in data_requirements.rb
  let(:embedded_client) do
    'http://cqf_ruler:8080/cqf-ruler-r4/fhir'
  end
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name: name, value: value)
    end
    Inferno::TestRunner.new(test_session: test_session, test_run: test_run).run(runnable)
  end

  describe '$evaluate-measure matches embedded results test' do
    let(:test) { group.tests.first }
    let(:measure_name) { 'EXM130' }
    let(:measure_version) { '7.3.000' }
    let(:measure_id) { 'measure-EXM130-7.3.000' }

    it 'ADD TEST' do
    
    end

    it 'ADD TEST' do
      
    end

    it 'ADD TEST' do
      
    end

    it 'ADD TEST' do
      
    end

    it 'ADD TEST' do
      
    end
  end

  describe '$evaluate-measure with missing parameters' do
    let(:test) { group.tests[1] }
    let(:measure_name) { 'EXM130' }
    let(:measure_version) { '7.3.000' }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    # EDIT THIS DATA REQUIREMENTS CODE TO MATCH EVALUATE-MEASURE
    it 'passes with correct OperationOutcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      )
        .to_return(status: 400, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id)
      expect(result.result).to eq('pass')
    end
    it 'fails with incorrect status code returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      )
        .to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id)
      expect(result.result).to eq('fail')
    end
    it 'fails when resource returned is not of type OperationOutcome' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      )
        .to_return(status: 400, body: test_library_response.to_json)
      result = run(test, url: url, measure_id: measure_id)
      expect(result.result).to eq('fail')
    end
    it 'fails when severity of OperationOutcome returned is not of type error' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      )
        .to_return(status: 400, body: incorrect_severity.to_json)
      result = run(test, url: url, measure_id: measure_id)
      expect(result.result).to eq('fail')
    end
  end
  describe '$data-requirements with invalid id' do
    let(:test) { group.tests[2] }
    let(:measure_name) { 'EXM130' }
    let(:measure_version) { '7.3.000' }
    let(:measure_id) { 'measure-EXM130-7.3.000' }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/INVALID_ID/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01"
      )
        .to_return(status: 404, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id)
      expect(result.result).to eq('pass')
    end

    it 'fails when 400 is not returned' do
      stub_request(
        :post,
        "#{url}/Measure/INVALID_ID/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01"
      )
        .to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id)
      expect(result.result).to eq('fail')
    end

    it 'fails when returned resource type is not of type OperationOutcome' do
      stub_request(
        :post,
        "#{url}/Measure/INVALID_ID/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01"
      )
        .to_return(status: 404, body: test_library_response.to_json)
      result = run(test, url: url, measure_id: measure_id)
      expect(result.result).to eq('fail')
    end

    it 'fails when severity returned is not equal to error' do
      stub_request(
        :post,
        "#{url}/Measure/INVALID_ID/$data-requirements?periodEnd=2019-12-31&periodStart=2019-01-01"
      )
        .to_return(status: 404, body: incorrect_severity.to_json)
      result = run(test, url: url, measure_id: measure_id)
      expect(result.result).to eq('fail')
    end
  end
end
