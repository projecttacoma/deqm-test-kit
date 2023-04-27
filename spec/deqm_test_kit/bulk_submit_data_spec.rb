# frozen_string_literal: true

RSpec.describe DEQMTestKit::BulkSubmitData do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_test_suite') }
  let(:group) { suite.groups[7] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe 'The server is able to perform bulk data tasks' do
    let(:test) { group.tests.first }
    let(:measure_name) { 'EXM130' }
    let(:measure_version) { '7.3.000' }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    it 'passes on successful $bulkImport' do
      test_measure = FHIR::Measure.new(id: measure_id, name: measure_name, version: measure_version)
      resource = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: 'test_id' } }])

      polling_url = "#{url}/location"

      stub_request(:get, "#{url}/Measure/#{measure_id}")
        .to_return(status: 200, body: test_measure.to_json)

      stub_request(:post, "#{url}/Measure/#{measure_id}/$bulk-submit-data")
        .to_return(status: 200, body: resource.to_json, headers: { 'content-location': polling_url })

      stub_request(:get, polling_url)
        .to_return(status: 202, body: resource.to_json).times(3)

      stub_request(:get, polling_url)
        .to_return(status: 200, body: resource.to_json)
      result = run(test, url:, measure_id:)
      # check that we get a 202 off a bulk data request
      expect(result.result).to eq('pass')
    end
  end
end
