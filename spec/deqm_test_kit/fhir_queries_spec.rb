# frozen_string_literal: true

RSpec.describe DEQMTestKit::FHIRQueries do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_test_suite') }
  let(:group) { suite.groups[3] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
  let(:test_condition_response) { FHIR::Bundle.new(total: 1, entry: [{ resource: { id: 'test-condition' } }]) }

  let(:test_library_response) do
    FHIR::Library.new(dataRequirement: [{ type: 'Condition' }])
  end

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name: name, value: value, type: 'text')
    end
    Inferno::TestRunner.new(test_session: test_session, test_run: test_run).run(runnable)
  end

  describe 'data requirements matches embedded results test' do
    let(:test) { group.tests.first }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:condition_id) { 'test-condition' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes if the FHIR queries return 200 and valid JSON' do
      test_patient_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: 'test-patient' } }])

      stub_request(:get, "#{url}/Condition")
        .to_return(status: 200, body: test_condition_response.to_json)

      stub_request(:get, "#{url}/Patient")
        .to_return(status: 200, body: test_patient_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements?periodEnd=#{period_end}&periodStart=#{period_start}"
      )
        .to_return(status: 200, body: test_library_response.to_json)

      result = run(test, url: url, measure_id: measure_id, data_requirements_server_url: url)
      expect(result.result).to eq('pass')
    end
    it 'fails if a single FHIR query returns 500' do
      stub_request(:get, "#{url}/Condition")
        .to_return(status: 200, body: test_condition_response.to_json)

      stub_request(:get, "#{url}/Patient")
        .to_return(status: 500, body: error_outcome.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements?periodEnd=#{period_end}&periodStart=#{period_start}"
      )
        .to_return(status: 200, body: test_library_response.to_json)

      result = run(test, url: url, measure_id: measure_id, data_requirements_server_url: url)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Expected response code 200, received: 500 for query: /Patient')
    end
  end
end
